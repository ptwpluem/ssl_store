# Tests

Run everything with `flutter test`. The suite has zero external dependencies —
no Firebase emulator, no network — so it runs fast and is CI-friendly.

## Layout

```
test/
├── unit/         Pure logic, no Firebase. Money math & model (de)serialization.
│   ├── price_calculation_service_test.dart   Labor-fee tiers per category
│   ├── gold_asset_test.dart                  Pawn interest accrual (1.25%/mo)
│   └── models_test.dart                      Wallet / WalletTransaction round-trips
├── services/     Service logic against an in-memory Firestore.
│   └── wallet_service_test.dart              Deposit/withdraw/sale/purchase, ledger
└── widget_test.dart                          App boots without throwing
```

## Approach

- **Business-logic correctness** is tested with `fake_cloud_firestore` (an
  in-memory Firestore) and `firebase_auth_mocks`. These run in plain
  `flutter test` and support transactions, `FieldValue.increment`, and
  `serverTimestamp`.
- **Security rules** are NOT covered here — rule enforcement needs the real
  Firebase emulator and is tracked under Milestone C in `ROADMAP.md`.

## Making a service testable

Services take their Firebase dependencies via an optional constructor that
defaults to the live instance, so production code is unchanged while tests
inject a fake:

```dart
final firestore = FakeFirebaseFirestore();
final service = WalletService(
  firestore: firestore,
  ids: IdGeneratorService(firestore: firestore),
);
```

`TradingService` and `SavingsService` still inline `FirebaseFirestore.instance`
and are not yet injectable — that refactor (and their integration tests) is the
next step in Milestone B, using `WalletService` as the template.
