# Database Design — Academic Review & Enhancement Proposal
**Project:** SSL Store — Local Goldsmith Mobile App (Thailand)  
**Technology:** Firebase Firestore (NoSQL Document Database)  
**Reviewer:** Data Warehouse Team Lead  
**Date:** 2026-04-26  

---

## Part 1 — Current Schema Map

Before addressing challenges, here is the full picture of what currently exists in the database.

### 1.1 Collection Hierarchy

```
ROOT COLLECTIONS
├── users/{customId}                     Human-friendly key (e.g. CST-vH9kL…)
│   ├── uid: string                      ← Firebase Auth UID stored as a field
│   ├── email, firstName, lastName, phoneNumber, location, role
│   ├── createdAt, lastSeen: Timestamp
│   │
│   ├── assets/{assetId}                 User's gold portfolio items
│   │   ├── name, weight, category, purity, acquisitionPrice
│   │   ├── status: 'owned'|'pawned'|'pickup_scheduled'|'collected'
│   │   └── loanAmount?, pawnDate?, dueDate?, interestRate?
│   │
│   ├── notifications/{notifId}          In-app notifications
│   │   └── title, message, type, timestamp (ISO string!), isRead
│   │
│   └── savings/account                  Gold savings summary doc
│       ├── totalWeightSaved, totalAmountInvested, lastUpdated
│       └── transactions/{stx_id}        Savings movement log
│           ├── amountInvested, weightGained, buyPriceAtTransaction
│           └── timestamp
│
├── wallets/{autoId}                     Keyed by auto-ID (not userId)
│   ├── userId: string                   ← Auth UID stored as a field
│   ├── balance, updatedAt
│   └── transactions/{autoId}            Wallet ledger
│       ├── amount, type, resultingBalance
│       └── description, referenceId, timestamp
│
├── transactions/{txId}                  Global transaction log (all users, all types)
│   ├── type: 'buy'|'sell'|'pawn'|'redeem'|'savings_deposit'|...
│   ├── userId, userEmail, userDisplayName  ← Denormalized user info
│   ├── assetId, amount, weight, category, purity, laborFee
│   ├── cost, profit, timestamp
│   └── details (Thai-language description string)
│
├── products/{productId}                 Store catalog
│   ├── name, description, price, weight, laborFee, costBasis
│   ├── stock, imageUrl, category
│   └── (No inventory movement log)
│
├── appointments/{aptId}                 Customer appointments
│   ├── userId, assetId, assetName
│   ├── date: string (ISO 8601!)         ← Inconsistent format
│   └── status: 'scheduled'|'completed'|'cancelled'
│
├── market/gold_rate                     Single live gold rate document (overwritten)
│   └── buyPrice, sellPrice, timestamp, trend
│
├── roles/{authUID}                      Role mirror for Firestore security rules
│   └── role: 'user'|'owner', updatedAt
│
├── news/{newsId}                        News articles
└── promotions/{promoId}                 Marketing banners
```

### 1.2 Entity-Relationship Summary

```
User  1──N  Asset  (subcollection under user)
User  1──1  Wallet (queried by userId field)
User  1──N  Notification (subcollection)
User  1──1  SavingsAccount (subcollection, singleton doc)
User  1──N  SavingsTransaction (under savings/account)
User  1──N  Appointment (global collection, filtered by userId)
User  1──N  Transaction (global collection, filtered by userId)
Wallet 1──N WalletTransaction (subcollection)
Transaction →  Asset (loose reference via assetId — NO enforcement)
Transaction →  Product (loose reference via productId — optional)
```

---

## Part 2 — Professor Challenge Points & Academic Analysis

The following are the most likely challenges a professor will raise, with full explanations of why they are problems and how to defend or fix them.

---

### Challenge 1: "Assets Are Stored in Multiple Places — This Is Redundant"

**What the professor sees:**
- An asset's name appears in `/users/{uid}/assets/{id}` (the live record)
- The same asset's name appears in `/transactions/{txId}` (the `details` string)
- The asset's state (`owned`, `pawned`) is spread across both the asset document and the pawn-related transaction

**Why this is a valid challenge:**
In relational databases, this violates **First Normal Form (1NF)** and **Second Normal Form (2NF)** — every non-key fact should appear in exactly one place. If the asset name or weight changed, you would need to update multiple documents.

**The correct answer to the professor:**
Firestore is a **NoSQL document database** designed around *read patterns, not write patterns*. Denormalization is intentional and expected. The `details` field in a transaction is a **snapshot** — it captures what was true at the moment the transaction occurred, not a live reference. This is a standard practice in event-driven and financial systems.

However, the current design has a real problem: when an asset is **sold**, the code calls `tx.delete(assetRef)`. This means:
1. The transaction record's `assetId` now points to a non-existent document (dangling reference)
2. There is no historical record of what the asset looked like
3. The owner cannot audit the complete lifecycle of any sold item

**Fix:** Never hard-delete financial assets. Set `status: 'sold'` with a `soldAt` timestamp. This is standard in all financial systems.

---

### Challenge 2: "There Is No Referential Integrity — Any assetId Could Be Garbage"

**What the professor sees:**
The `transactions` collection stores `assetId` as a plain string field. There is no foreign key, no constraint, and no guarantee that document exists.

**The correct answer:**
Firestore does not support foreign key constraints — this is a known and accepted limitation of document databases. The mitigation strategy is:
1. **Always write inside `runTransaction()`** so that asset creation and transaction creation are atomic — they both succeed or both fail
2. **Soft-delete assets** so references are never broken by deletion
3. **Use structured IDs** (e.g. `BUY-xyz`) so orphaned references are visually detectable

The current code already uses `runTransaction()` for every write, which is good. The gap is the hard-delete on sell.

---

### Challenge 3: "You Have Three Different Transaction Collections — Why?"

**What the professor sees:**
- `/transactions/{txId}` — global log
- `/wallets/{id}/transactions/{txId}` — wallet ledger
- `/users/{uid}/savings/account/transactions/{txId}` — savings ledger

These are three overlapping records of the same financial event, with no enforced relationship between them. A wallet transaction's `referenceId` loosely points to the global transaction, but there is no guarantee of consistency.

**The academic problem:**
This violates **data consistency** principles. If the wallet write succeeds but the global transaction write fails (or vice versa), the two records diverge with no way to detect it. This is especially dangerous for a financial application.

**The correct answer:**
All three writes happen inside a single `runTransaction()`, so they are atomic — either all succeed or all fail. The duplication is intentional: each collection serves a different query pattern:
- `/transactions` → owner dashboard (all users' activity)
- `/wallets/transactions` → user's wallet statement
- `/savings/transactions` → user's savings history

**However, the design should be improved** by adding cross-reference fields so any record can navigate to its related records.

---

### Challenge 4: "Gold Price History Is Destroyed — You Overwrite the Same Document"

**What the professor sees:**
`/market/gold_rate` is a single Firestore document. When the owner updates the gold price, the old price is gone forever.

**The academic problem:**
This is a **loss of temporal data**. In database theory, this is called losing **historical state**. You cannot answer:
- "What was the buy price on March 15?"
- "Did the price at the time of this transaction match the market price?"
- "Show me the price trend over the last 6 months?"

This is particularly serious for a financial auditing context.

**Fix:** Create a `/markethistory` collection where each update creates a new immutable document. The live `/market/gold_rate` document remains for real-time reads.

---

### Challenge 5: "The Pawn Loan Is Not a First-Class Entity — Its Data Is Scattered"

**What the professor sees:**
A pawn loan is a financial instrument with its own lifecycle: it is created, accrues interest, may go overdue, and is either redeemed or forfeited. Currently, the pawn loan data is:
- Stored as fields inside the `assets` document (`loanAmount`, `pawnDate`, `dueDate`, `interestRate`)
- Documented in two transaction records (type `pawn` and type `redeem`)
- Never aggregated for monitoring

**The academic problem:**
From an **Entity-Relationship modeling** perspective, a pawn loan is a distinct entity with its own attributes and lifecycle, not just a set of fields on an asset. The current design makes it impossible to:
- Query "all active pawn loans overdue by more than 30 days"
- Aggregate total outstanding loan value
- Track the penalty interest separately from standard interest

**Fix:** Introduce a `/pawn_loans/{loanId}` collection as a dedicated entity.

---

### Challenge 6: "The Customer Model Is Disconnected — Walk-In Customers Cannot Be Served"

**What the professor sees:**
There is a `Customer` class defined in `lib/models/customer.dart` with fields `id, name, phone, preferences`. This class has no Firestore serialization methods (`fromFirestore`, `toMap`) and is never used in any service. Every transaction is tied to a Firebase Auth UID, meaning only registered app users can conduct transactions.

**The academic problem:**
A real goldsmith shop serves walk-in customers, phone orders, and repeat customers who never download the app. The current design has a **data completeness gap** — a significant portion of real business activity cannot be recorded.

**Fix:** Introduce a `walkInCustomers` concept: either a subcollection under the owner user, or a dedicated collection with `type: 'registered'|'walkin'`.

---

### Challenge 7: "Inventory Has No Movement Log — You Cannot Audit Stock Changes"

**What the professor sees:**
Products have a `stock` integer field that is incremented/decremented atomically. The restocking operation writes to `/transactions/{id}` with type `restock`, but there is no dedicated inventory movement history linked to the product itself.

**The academic problem:**
**Audit trail completeness** — you cannot answer: "How many times was product X restocked in the last year?" or "Which transactions reduced the stock of this product?" without scanning the entire global transactions collection.

**Fix:** Add a `/products/{id}/inventory_log/{logId}` subcollection for every stock movement.

---

### Challenge 8: "The Appointment Is Not Linked to a Transaction — You Cannot Close the Loop"

**What the professor sees:**
An appointment is created when a customer schedules a pickup for a physical gold bar. When the owner marks the appointment `completed`, the asset status becomes `collected`. But there is no link from the appointment to the original `savings_physical_withdraw` transaction.

**The academic problem:**
**Traceability** — the chain of events from "customer deposited savings" → "customer requested physical bar" → "appointment was booked" → "customer collected the bar" cannot be reconstructed from the data.

---

### Challenge 9: "The Reward Points Are Calculated by Scanning All Transactions — This Will Not Scale"

**What the professor sees:**
```dart
return getTransactionHistoryStream().map((txs) {
  double total = 0;
  for (var t in txs) {
    if (t.type == TransactionType.buy) total += t.amount;
  }
  return total ~/ 1000; // Points
});
```

Every time the home screen loads, it downloads **every buy transaction for this user** to compute a single integer.

**The academic problem:**
This is a classic **O(n) aggregation on read** problem. As the user accumulates more transactions, this gets slower and more expensive. The correct pattern is to maintain a running total (`rewardPoints`) on the user document, updated via `FieldValue.increment()` on every purchase. This turns an O(n) read into an O(1) read.

---

### Challenge 10: "There Is No Concept of Accounting Period or Daily Close"

**What the professor sees:**
The shop has no daily close, no period-end snapshot, and no P&L structure. The owner dashboard calculates everything by scanning the global transactions collection.

**The academic problem:**
For any business application, you need to be able to answer: "How much profit did the shop make in Q1 2026?" with a bounded, consistent answer — not one that changes depending on when you run the query.

---

## Part 3 — NoSQL vs. Relational Database: Defending the Choice

A professor may ask: "Why didn't you use a relational database like MySQL or PostgreSQL?"

**Valid reasons for Firestore in this application:**

| Factor | Relational DB | Firestore |
|---|---|---|
| Real-time gold price updates | Requires polling or WebSocket setup | Native real-time listeners (`snapshots()`) |
| Mobile client sync | Requires API layer | Firebase SDK handles offline, sync, and retry |
| Authentication integration | Separate auth system | Firebase Auth integrates natively |
| Scalability for Thai New Year peak load | Requires server scaling | Auto-scales serverlessly |
| Read-heavy access pattern | Works well | Optimized for reads with denormalization |
| Schema flexibility | Rigid | Accommodates evolving jewelry catalog |

**Honest limitation to acknowledge:**
Firestore does not enforce referential integrity or support JOIN queries. For a financial application with complex reporting requirements (cross-entity aggregations), a read replica or a dedicated analytics layer (e.g., BigQuery export) should complement Firestore.

---

## Part 4 — Proposed Schema Enhancements

### 4.1 The Core Design Principles Being Applied

1. **Soft-delete over hard-delete** for all financial records
2. **Append-only event logs** for asset lifecycle and inventory
3. **First-class entities** for all meaningful domain objects (pawn loans, price history)
4. **Cross-reference IDs** to make traceability possible
5. **Accumulated counters** for derived metrics (reward points, daily totals)
6. **Consistent timestamp format** — Firestore `Timestamp` everywhere

---

### 4.2 Enhanced Collection Structure

```
ROOT COLLECTIONS (proposed)
│
├── users/{authUID}                      ← RE-KEYED by Firebase Auth UID
│   ├── displayId: 'CST-001'             ← Human-friendly ID kept as a field
│   ├── email, firstName, lastName, phoneNumber, role
│   ├── rewardPoints: number             ← NEW: Running total (replaces O(n) scan)
│   ├── totalBuyAmount: number           ← NEW: Running total for reporting
│   ├── createdAt, lastSeen
│   │
│   ├── assets/{assetId}
│   │   ├── name, weight, category, purity, acquisitionPrice, acquisitionDate
│   │   ├── status: 'owned'|'pawned'|'sold'|'withdrawn'|
│   │   │          'pickup_scheduled'|'collected'
│   │   ├── soldAt?: Timestamp           ← NEW: Instead of deleting
│   │   ├── soldPrice?: number           ← NEW: Capture sell price on asset
│   │   ├── loanId?: string              ← NEW: Link to pawn_loans document
│   │   └── collectedAt?: Timestamp      ← NEW: Appointment completion time
│   │
│   │   /events/{eventId}               ← NEW: Immutable asset lifecycle log
│   │   ├── type: 'acquired'|'pawned'|'redeemed'|'sold'|
│   │   │        'withdrawn'|'pickup_scheduled'|'collected'
│   │   ├── timestamp: Timestamp
│   │   ├── transactionId: string        ← Link to global transaction
│   │   ├── actorId: string              ← Who performed the action
│   │   └── notes?: string
│   │
│   ├── notifications/{notifId}
│   │   └── (ALL timestamps: Firestore Timestamp, not ISO string)
│   │
│   └── savings/account
│       ├── totalWeightSaved, totalAmountInvested, lastUpdated
│       └── transactions/{txId}          ← Use IdGeneratorService (not epoch ms)
│           ├── type: 'deposit'|'sell'|'physical_withdrawal'  ← NEW: explicit type
│           └── amountInvested, weightGained, buyPriceAtTransaction, timestamp
│
├── wallets/{authUID}                    ← RE-KEYED by Firebase Auth UID
│   ├── balance, updatedAt
│   └── transactions/{txId}
│       ├── amount, type, resultingBalance
│       └── description, referenceId (→ global txId), timestamp
│
├── transactions/{txId}                  ← Global financial event log (keep)
│   ├── type: 'buy'|'sell'|'pawn'|'redeem'|'savings_deposit'|
│   │        'savings_withdraw'|'savings_physical_withdraw'|
│   │        'deposit'|'withdrawal'|'restock'
│   ├── userId, userEmail, userDisplayName (snapshot — intentional denorm)
│   ├── assetId, amount, weight, category, purity, laborFee
│   ├── cost, profit, timestamp
│   ├── walletTxId?: string              ← NEW: Link to wallet transaction
│   ├── savingsTxId?: string             ← NEW: Link to savings transaction
│   ├── goldRateSnapshotId?: string      ← NEW: Link to price used
│   └── appointmentId?: string           ← NEW: Link to related appointment
│
├── pawn_loans/{loanId}                  ← NEW COLLECTION
│   ├── userId, assetId, assetName, assetWeight, assetCategory
│   ├── principal: number                ← Loan amount disbursed
│   ├── interestRateMonthly: 0.0125      ← 1.25% standard
│   ├── startDate: Timestamp
│   ├── dueDate: Timestamp               ← startDate + 30 days
│   ├── gracePeriodDays: 7              ← Grace period before penalty kicks in
│   ├── status: 'active'|'redeemed'|'overdue'|'forfeited'
│   ├── openedByTxId: string            ← Link to pawn transaction
│   ├── closedByTxId?: string           ← Link to redeem transaction (when done)
│   ├── totalInterestPaid?: number      ← Populated on redemption
│   └── overdueNoticeSentAt?: Timestamp ← For automated reminder tracking
│
├── markethistory/{rateId}           ← NEW COLLECTION (append-only)
│   ├── buyPrice, sellPrice
│   ├── timestamp: Timestamp
│   ├── recordedBy: string              ← Owner UID
│   └── source: 'manual'|'api'         ← Future: auto-feed from gold API
│
├── market/gold_rate                     ← Keep for live rate (unchanged)
│
├── products/{productId}
│   ├── name, description, weight, laborFee, category, imageUrl
│   ├── price, costBasis (weighted avg)
│   ├── stock: number
│   ├── inStock: bool                   ← Computed field for easy filtering
│   ├── purity: 0.965|0.9999           ← NEW: Explicit purity
│   │
│   └── inventory_log/{logId}           ← NEW: Inventory movement history
│       ├── type: 'initial'|'restock'|'sale'|'adjustment'|'physical_withdrawal'
│       ├── quantityDelta: number       ← Signed: +5 for restock, -1 for sale
│       ├── unitCost?: number           ← For restock entries
│       ├── transactionId?: string      ← Link to global transaction
│       ├── performedBy: string
│       └── timestamp: Timestamp
│
├── appointments/{aptId}
│   ├── userId, assetId, assetName
│   ├── date: Timestamp                 ← FIXED: Use Timestamp, not ISO string
│   ├── status: 'scheduled'|'completed'|'cancelled'
│   ├── purpose: 'gold_bar_pickup'|'pawn_dropoff'|'consultation'|'purchase_pickup'  ← NEW
│   └── linkedTransactionId?: string    ← NEW: Link to originating transaction
│
├── daily_snapshots/{YYYY-MM-DD}        ← NEW COLLECTION
│   ├── date: Timestamp
│   ├── totalRevenue: number
│   ├── totalCost: number
│   ├── grossProfit: number
│   ├── buyCount, sellCount, pawnCount, redeemCount
│   ├── savingsDeposits: number
│   ├── savingsWithdrawals: number
│   ├── newMembers: number
│   ├── activeMembers: number
│   ├── openingGoldRate, closingGoldRate
│   └── activePawnLoans: number         ← Snapshot at close-of-business
│
├── roles/{authUID}                      ← Keep (unchanged)
├── news/{newsId}                        ← Keep (unchanged)
└── promotions/{promoId}                 ← Keep (unchanged)
```

---

### 4.3 Asset Lifecycle — Before vs. After

**Before (current):**
```
Buy → asset created at status 'owned'
Pawn → asset fields mutated: status='pawned', loanAmount, pawnDate, dueDate added
Redeem → asset fields mutated: status='owned', loan fields deleted
Sell → asset document DELETED (no history)
```

**After (proposed):**
```
Buy → asset created at status 'owned'
     + asset event logged: type='acquired', txId=BUY-xxx
     
Pawn → asset field updated: status='pawned', loanId=PWN-xxx
     + pawn_loans/PWN-xxx CREATED as standalone entity
     + asset event logged: type='pawned'

Redeem → asset field updated: status='owned', loanId removed
        + pawn_loans/PWN-xxx updated: status='redeemed', closedByTxId
        + asset event logged: type='redeemed'

Sell → asset field updated: status='sold', soldAt, soldPrice  ← NOT DELETED
      + asset event logged: type='sold', txId=SEL-xxx
```

---

### 4.4 Gold Rate — Before vs. After

**Before:**
```
market/gold_rate  { buyPrice: 41500, sellPrice: 41600 }
← When owner updates: previous values are gone forever
```

**After:**
```
market/gold_rate  { buyPrice: 41500, sellPrice: 41600, currentRateId: 'GRT-abc' }

markethistory/GRT-abc  { buyPrice: 41500, sellPrice: 41600, timestamp: ..., recordedBy: uid }
markethistory/GRT-xyz  { buyPrice: 41200, sellPrice: 41300, timestamp: ..., recordedBy: uid }
(Each update appends a new document — the history is never lost)

transactions/BUY-xxx  { ..., goldRateSnapshotId: 'GRT-abc' }
← Now every transaction links to the exact rate that was used
```

---

### 4.5 Pawn Loan — Before vs. After

**Before:**
```
users/{uid}/assets/{id}  {
  status: 'pawned',
  loanAmount: 35000,
  pawnDate: Timestamp,
  dueDate: Timestamp,
  interestRate: 0.0125
}
← To find all overdue loans: scan EVERY asset of EVERY user
```

**After:**
```
pawn_loans/PWN-xyz {
  userId: 'auth_uid_123',
  assetId: 'BUY-abc',
  assetName: 'สร้อยคอทองคำ ลายสี่เสา',
  principal: 35000,
  interestRateMonthly: 0.0125,
  startDate: Timestamp,
  dueDate: Timestamp,
  status: 'active',
  openedByTxId: 'PWN-xyz'
}
← To find all overdue loans:
  collection('pawn_loans')
    .where('status', isEqualTo: 'active')
    .where('dueDate', isLessThan: Timestamp.now())
  → Direct O(1) indexed query, no scanning of user assets
```

---

## Part 5 — Questions the Professor Might Ask & Model Answers

**Q: "Why do you store userEmail and userDisplayName in every transaction? That's redundant."**

A: This is intentional denormalization — a deliberate snapshot pattern. In financial systems, a transaction record must be self-describing. If a user later changes their name or deletes their account, the historical transaction must still show who performed it. This is the same principle used in receipts and bank statements.

**Q: "What happens if two customers buy the last item at exactly the same time?"**

A: The `createBuyTransaction` uses a Firestore transaction (`runTransaction`) which locks the product document during the write. Firestore uses optimistic concurrency: if two transactions modify the same document simultaneously, one will succeed and the other will retry. The stock check `if stock <= 0 throw Exception` inside the transaction ensures the second buyer gets a proper error response. This is a correct and standard pattern.

**Q: "How do you handle the case where a pawn customer never comes back to redeem?"**

A: Currently the schema has no mechanism for this. With the proposed `/pawn_loans` collection and a `status: 'forfeited'` value, a Cloud Function or background job can query `where('status', isEqualTo, 'active').where('dueDate', isLessThan, overdueThreshold)` and update the status. The associated asset would move to `status: 'forfeited'`, returning to the shop's inventory.

**Q: "The savings account total could become inconsistent with the sum of savings transactions — how do you handle this?"**

A: This is a valid concern. The `totalWeightSaved` and `totalAmountInvested` on the savings account document are maintained via `FieldValue.increment()` inside the same `runTransaction()` that creates the transaction record. Since both writes are atomic, they cannot partially succeed. If a client reads during a transaction's execution, Firestore returns the pre-transaction values (snapshot isolation). A periodic reconciliation job comparing the running total against the sum of transactions provides a safety net.

**Q: "Why is there no VAT calculation or tax invoice?"**

A: The current version targets MVP functionality. Thai goldsmith shops are registered under a special gold trading regime with different VAT rules (gold ornaments are VAT-exempt but a 7% VAT applies to services including labor fee). The schema can be extended to add a `vatAmount` field to transaction records and a `/tax_invoices` collection for formal invoice management.

**Q: "What indexes are defined? How do you prevent expensive full-collection scans?"**

A: The key composite indexes needed are:
- `transactions: (userId ASC, timestamp DESC)` — user transaction history
- `pawn_loans: (status ASC, dueDate ASC)` — overdue loan monitoring
- `appointments: (status ASC, date ASC)` — daily appointment calendar
- `markethistory: (timestamp DESC)` — rate trend display

These should be declared in `firestore.indexes.json` to ensure they are provisioned before deployment.

---

## Part 6 — Summary of Proposed Additions

| Addition | What It Solves |
|---|---|
| Re-key `/users/{authUID}` | Eliminates extra query on every operation |
| Re-key `/wallets/{authUID}` | Eliminates extra query, fixes race condition |
| Soft-delete assets (`status: 'sold'`) | Preserves financial history, fixes dangling references |
| `/users/{uid}/assets/{id}/events/` | Immutable asset lifecycle audit trail |
| `/pawn_loans/{loanId}` collection | First-class pawn entity, enables overdue monitoring |
| `/markethistory/{rateId}` | Preserves price history, enables transaction audit |
| `/products/{id}/inventory_log/` | Inventory audit trail |
| `appointments.purpose` field | Disambiguates appointment types |
| `appointments.linkedTransactionId` | Closes the traceability loop |
| `users.rewardPoints` counter | Replaces O(n) aggregation |
| `/daily_snapshots/{date}` | Enables period reporting, owner analytics |
| Cross-reference IDs in transactions | Enables traceability across all three ledgers |
| Consistent Firestore Timestamps | Fixes ordering queries on appointments/notifications |
| `firestore.indexes.json` declarations | Prevents full-collection scans in production |

---

*Document prepared for academic review. All file references are relative to the Flutter project's `lib/` directory.*
