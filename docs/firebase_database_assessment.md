# Firebase / Firestore Database Design Assessment
**Project:** SSL Store — Local Goldsmith Mobile Application (Thailand)  
**Date:** 2026-04-26  
**Scope:** All Firestore collections, models, and service layer code  

---

## 1. Inferred Collection Architecture

Based on the service code, the Firestore schema is structured as follows:

```
/users/{customId}                          ← Custom ID (NOT the Auth UID)
    uid: string                            ← Auth UID stored as a field
    email, firstName, lastName, phoneNumber, location, role, createdAt, lastSeen

    /assets/{assetId}                      ← User's gold portfolio
    /notifications/{notifId}               ← In-app notifications
    /savings/account                       ← Gold savings account summary
        /transactions/{stx_id}             ← Savings transaction log

/wallets/{autoId}                          ← Wallet documents
    userId: string                         ← Auth UID stored as a field

    /transactions/{autoId}                 ← Wallet ledger entries

/transactions/{txId}                       ← Global all-user transaction log
/products/{productId}                      ← Store product catalog
/market/gold_rate                          ← Live gold rate document
/roles/{authUID}                           ← Role mirror for security rules
/appointments/{appointmentId}              ← Customer appointments
```

---

## 2. Critical Issues (Must Fix)

### 2.1 Users Not Keyed by Auth UID — Every Operation Pays an Extra Query

**File:** `lib/services/firestore_helper.dart`

The user document is stored at `/users/{customId}` where `customId` is a generated string (e.g. `CST-vH9kL...`). The real Firebase Auth UID is stored as a *field* called `uid`. This means every single service call — buy, sell, pawn, redeem, savings, notifications — must first execute:

```dart
collection('users').where('uid', isEqualTo: uid).limit(1).get()
```

before it can do anything useful. This `getUserDocRef()` call has retry logic with three attempts, meaning a slow network can triple this overhead before a transaction even begins.

**Fix:** Store the user document at `/users/{authUID}` directly. Remove `getUserDocRef()` and replace with `collection('users').doc(uid)`. The `customId` field can still be stored as a human-friendly display ID (e.g. `CST-001`) but should not be the document key.

---

### 2.2 Wallets Not Keyed by User ID — Same Pattern, Same Problem

**File:** `lib/services/wallet_service.dart`, used in every service

Wallets are stored with an auto-ID key and a `userId` field. Every transaction runs:

```dart
collection('wallets').where('userId', isEqualTo: uid).limit(1).get()
```

This query is outside the Firestore transaction scope, which is a **consistency risk** — the wallet document could theoretically be modified between the pre-transaction query and the transactional read.

**Fix:** Store the wallet document at `/wallets/{authUID}`. All reads become `collection('wallets').doc(uid)` — a direct O(1) lookup inside the transaction.

---

### 2.3 `sellAsset` Hardcodes `profit: 0.0` — Owner Reports Are Wrong

**File:** `lib/services/trading_service.dart`, `sellAsset()`

```dart
tx.set(collection('transactions').doc(id), {
  ...
  'cost': sellPrice,   // This is wrong — cost is not the sell price
  'profit': 0.0,       // Hardcoded — no profit is ever calculated on sells
  ...
});
```

The `profit` field is always zero for every sell transaction. The owner dashboard's revenue/profit reports will show incorrect figures.

**Fix:**
```dart
final cost   = asset.acquisitionPrice;
final profit = sellPrice - cost;
...
'cost':   cost,
'profit': profit,
```

---

### 2.4 Race Condition in `createWalletForUser`

**File:** `lib/services/wallet_service.dart`

```dart
final existing = await _firestore.collection('wallets').where('userId', ...).get();
if (existing.docs.isEmpty) {
  await _firestore.collection('wallets').add({...});
}
```

This check-then-create is not atomic. If two concurrent calls (e.g. registration + first login) execute simultaneously, two wallet documents can be created for the same user. Downstream logic always uses `.limit(1)`, which silently ignores the duplicate — but the second wallet accumulates no funds.

**Fix:** By keying wallets by Auth UID (Issue 2.2), this becomes `collection('wallets').doc(uid).set({...}, SetOptions(merge: true))` — idempotent and atomic.

---

### 2.5 Runtime Data Repair Scans the Entire `transactions` Collection

**File:** `lib/services/trading_service.dart`, `repairAllTransactions()`

Every time a user performs a buy transaction, `_runRepairs()` is called (once per app session). It runs two full collection scans:

```dart
collection('transactions').where('type', isEqualTo: 'buy').get()
collection('transactions').where('type', isEqualTo: 'redeem').get()
```

As the transaction log grows, these scans become increasingly expensive in Firestore read units and latency. The need for repair logic itself reveals that data is sometimes written inconsistently.

**Fix:** Address the root cause (Issues 2.1 and 2.3) so data is written correctly at creation time. Remove the repair routine entirely.

---

## 3. Data Model Issues

### 3.1 Duplicate Transaction Models with Conflicting Date Formats

Two models exist for what is conceptually the same record:

| Model | Date field | Format |
|---|---|---|
| `GoldTransaction` | `timestamp: DateTime` | Firestore `Timestamp` ✅ |
| `TransactionRecord` | `date: DateTime` | ISO 8601 string ❌ |

`TransactionRecord.toMap()` writes `date: date.toIso8601String()`. ISO strings cannot be used with Firestore's `orderBy('date')` queries — they sort lexicographically rather than chronologically for cross-year data.

**Fix:** Consolidate to one model. Store all timestamps as Firestore `Timestamp` objects. Replace `date.toIso8601String()` with `Timestamp.fromDate(date)`.

---

### 3.2 `NotificationItem` Uses ISO String for Timestamp

**File:** `lib/models/notification_item.dart`

`toMap()` stores timestamp as `timestamp.toIso8601String()`, but `fromMap()` parses it with `DateTime.parse(data['timestamp'])`. This breaks if a notification was written with `FieldValue.serverTimestamp()` elsewhere in the code (e.g. `savings_service.dart` line writing the notification directly as a map).

**Fix:** Use `Timestamp.fromDate(timestamp)` in `toMap()` and `(data['timestamp'] as Timestamp).toDate()` in `fromMap()`, consistent with `Wallet` and `WalletTransaction`.

---

### 3.3 `Appointment` Uses ISO String for Date

**File:** `lib/models/appointment.dart`

```dart
'date': date.toIso8601String()     // toMap()
date: DateTime.parse(map['date'])  // fromMap()
```

Same issue as 3.1 — this prevents server-side range queries on appointment dates and is inconsistent with all other timestamp fields.

---

### 3.4 Three Models Have No Firestore Serialization

| Model | Missing |
|---|---|
| `Customer` | No `fromFirestore` / `toMap` |
| `Product` | No `fromFirestore` / `toMap` |
| `GoldRate` | No `fromFirestore` / `toMap` |

`Customer` appears to be a local-only object with no persistence path. `Product` and `GoldRate` are read directly from Firestore using raw `doc.data()` maps in the service layer, bypassing the model entirely — meaning type safety and null handling are unguarded.

---

### 3.5 Operator Precedence Bug in `GoldSavingsAccount.fromMap`

**File:** `lib/models/gold_savings.dart`

```dart
// BUG: `as num` applies to `0.0`, not to the null-coalescing expression
totalWeightSaved: (data['totalWeightSaved'] ?? 0.0 as num).toDouble(),

// CORRECT:
totalWeightSaved: ((data['totalWeightSaved'] ?? 0.0) as num).toDouble(),
```

If Firestore returns an `int` for `totalWeightSaved` (e.g. `0`), calling `.toDouble()` directly on the int result will succeed at runtime in Dart, but the intent is wrong. More critically, if a non-num type is returned, the cast fails silently on the literal `0.0` rather than the data value.

---

### 3.6 `GoldTransaction` Enum Missing `savings_physical_withdraw` Mapping

**File:** `lib/services/user_service.dart`, `getTransactionHistoryStream()`

The `TransactionType` enum includes `savings_physical_withdraw` but the stream builder in `UserService` has no case for it:

```dart
// These cases are missing:
else if (data['type'] == 'savings_physical_withdraw') type = TransactionType.savings_physical_withdraw;
```

Physical gold bar withdrawals silently default to `TransactionType.buy` in the transaction history screen.

---

## 4. Performance & Scalability Issues

### 4.1 `getTransactionHistoryStream` — No Server-Side Ordering

**File:** `lib/services/user_service.dart`

```dart
collection('transactions').where('userId', isEqualTo: uid).snapshots()
// ... then client-side sort:
list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
```

All matching documents are downloaded to the client first, then sorted in memory. For a user with hundreds of transactions this is wasteful. A Firestore composite index on `(userId, timestamp DESC)` would allow the server to do this work.

**Fix:** Add `.orderBy('timestamp', descending: true)` to the query and add the corresponding composite index in `firestore.indexes.json`.

---

### 4.2 `getRewardPointsStream` — O(n) Client-Side Aggregation

**File:** `lib/services/user_service.dart`

```dart
return getTransactionHistoryStream().map((txs) {
  double total = 0;
  for (var t in txs) {
    if (t.type == TransactionType.buy) total += t.amount;
  }
  return total ~/ 1000;
});
```

This downloads every transaction for every UI rebuild just to compute a reward point total. This should be a dedicated accumulated field on the user document (e.g. `totalBuyAmount`) updated via `FieldValue.increment()` on each purchase.

---

### 4.3 No Pagination on Any Stream

All stream queries — assets, transactions, notifications, savings transactions — fetch the entire collection with no `.limit()`. For a long-running shop with many customers and transactions, this will cause significant data transfer costs and slow loading times.

**Fix:** Add `.limit(50)` with cursor-based pagination for historical data views. Use real-time streams only for the most recent items.

---

### 4.4 Savings Transaction IDs Use `millisecondsSinceEpoch` — Collision Risk

**File:** `lib/services/savings_service.dart`

```dart
final txId = DateTime.now().millisecondsSinceEpoch.toString();
tx.set(savingsRef.collection('transactions').doc('stx_$txId'), ...);
```

If two savings operations complete within the same millisecond (unlikely but possible under load, or in testing), one will silently overwrite the other. The `IdGeneratorService` is available and should be used here instead.

---

## 5. Security Issues

### 5.1 Owner Email Hardcoded in Source Code

**File:** `lib/services/auth_service.dart`

```dart
static const List<String> _primaryOwners = [
  'owner_account@gmail.com',
];
```

This is a security and maintenance risk. The real owner email is visible to anyone with access to the repository. If the owner changes their email, a code deployment is required.

**Fix:** Store owner role in Firestore only (which is already done via the `/roles/{uid}` mirror). Remove the hardcoded list and derive the role exclusively from the Firestore document.

---

### 5.2 `wallets` Collection Queryable by Any `userId`

Because wallets use a query pattern (`where('userId', isEqualTo: uid)`) rather than a direct path, Firestore security rules must allow the query to execute at all. A rule like `allow read: if request.auth.uid == resource.data.userId` protects individual documents, but the collection-level query permission must also be carefully scoped. If rules are not precisely written, a malicious client could query wallets for other user IDs.

**Fix:** Keying wallets by Auth UID (Issue 2.2) simplifies this to `allow read, write: if request.auth.uid == walletId`, which is unambiguous.

---

## 6. Summary and Priority Roadmap

| Priority | Issue | Impact |
|---|---|---|
| 🔴 Critical | 2.1 — Re-key `/users` by Auth UID | Performance, complexity |
| 🔴 Critical | 2.2 — Re-key `/wallets` by Auth UID | Performance, consistency, security |
| 🔴 Critical | 2.3 — Fix `sellAsset` profit calculation | Owner dashboard data is wrong |
| 🔴 Critical | 2.4 — Fix wallet creation race condition | Data integrity |
| 🟠 High | 2.5 — Remove runtime repair logic | Performance, cost |
| 🟠 High | 3.1 — Unify transaction models, use Timestamps | Query correctness |
| 🟠 High | 4.1 — Add `orderBy` + composite index | Performance |
| 🟠 High | 5.1 — Remove hardcoded owner email | Security |
| 🟡 Medium | 3.2 — Fix `NotificationItem` timestamp | Data consistency |
| 🟡 Medium | 3.3 — Fix `Appointment` date format | Query correctness |
| 🟡 Medium | 3.4 — Add serialization to Customer/Product/GoldRate | Type safety |
| 🟡 Medium | 3.5 — Fix operator precedence bug in savings model | Silent data bug |
| 🟡 Medium | 3.6 — Map `savings_physical_withdraw` in history stream | Display bug |
| 🟡 Medium | 4.2 — Replace `getRewardPointsStream` with stored counter | Performance |
| 🟢 Low | 4.3 — Add pagination to all streams | Scalability |
| 🟢 Low | 4.4 — Replace savings `millisecondsSinceEpoch` IDs | Correctness |

---

## 7. Recommended Target Schema

```
/users/{authUID}                           ← Keyed by Firebase Auth UID directly
    displayId: string                      ← Human-friendly "CST-001" kept as a field
    email, firstName, lastName, phoneNumber, location, role, createdAt, lastSeen
    totalBuyAmount: number                 ← Accumulated for reward points (no scan)

    /assets/{assetId}
    /notifications/{notifId}
    /savings/account
        /transactions/{txId}               ← Use IdGeneratorService, not epoch ms

/wallets/{authUID}                         ← Keyed by Firebase Auth UID directly
    balance: number
    updatedAt: Timestamp

    /transactions/{txId}

/transactions/{txId}                       ← Global log (keep, but add composite index)
/products/{productId}                      ← Add fromFirestore / toMap to Product model
/market/gold_rate                          ← Add fromFirestore / toMap to GoldRate model
/roles/{authUID}                           ← Keep as-is for security rules
/appointments/{appointmentId}              ← Change date field to Timestamp
```

---

*Assessment prepared by Claude — Cowork mode. All file references are relative to `lib/` in the Flutter project root.*
