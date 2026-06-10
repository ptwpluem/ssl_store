# SSL Store — Improvement Roadmap

> A gold/jewelry store app (buy / sell / pawn / gold-savings / wallet / appointments) built on Flutter + Firebase.
> Goal: evolve it steadily into something solid enough to run a real home business on.
>
> **How to use this:** Each day, pick the top unchecked `[ ]` task in the current milestone, do it, check it off, commit. Tasks are sized to fit roughly one sitting. Don't skip ahead — earlier milestones make later work safe.

**Status legend:** `[ ]` todo · `[~]` in progress · `[x]` done
**Last assessed:** 2026-06-10 (against commit `8f42523`) · `flutter analyze`: **28 issues** · largest file: `owner_overview_tab.dart` (1,508 lines)

> **Note:** A large refactor (commit `8f42523`) already completed the original security and service-split work. This roadmap reflects the *current* state, not the original assessment.

---

## ✅ Already done (was in the original plan)
- **Firestore security rules hardened** — auth required everywhere, role-based owner checks via `/roles` mirror, per-user ownership, append-only event/history logs, default-deny catch-all. (was Milestone 0)
- **God service split** — `mock_service.dart` (2,493 lines) replaced by 9 focused services: catalog, pawn, savings, trading, market, notification, appointment, user, inventory-lot. (was Milestone 3)
- **Files renamed to convention** (`member_*_page.dart`, `owner_*`) and most dead code removed. (was Milestone 1)
- `flutter analyze` down from 195 → 28 issues.

---

## 🧹 Milestone A — Tidy the repo ✅ DONE (2026-06-10)

Small loose ends from the big refactor. Low effort, removes noise.

- [x] **Remove `lib.zip` from the repo** (227 KB binary backup) and add `*.zip` to `.gitignore`. Source backups don't belong in git.
- [x] **Decide on `users.json`** — was a Firebase Auth export (test user + password hash); deleted and gitignored.
- [x] **Move design docs into a `docs/` folder** — `database_design_academic_review.md`, `firebase_database_assessment.md`, `ssl_store_firestore_er*.xml`, `UC10_appointment_management.xml`. Root is clean.
- [x] **Finish the analyzer mop-up (28 → 0).** Fixed `use_build_context_synchronously` (used `context.mounted`), `curly_braces`, `unnecessary_cast`, unused imports/fields, etc. Renaming the `TransactionType` enum was avoided (values persist as Firestore strings) — suppressed with a documented `ignore`. **`flutter analyze`: No issues found.**

---

## 🟢 Milestone B — Trust the money (testing) — ✅ DONE (2026-06-10)

**78 tests passing, `flutter test` green, `flutter analyze` clean, no network/emulator needed.**
Every money service (wallet, trading, savings, pawn) plus the pure money math
(pawn interest, labor fees) is now covered. All four services use the same
factory-injection pattern (no-arg call returns the production singleton).

**Infra decision:** using `fake_cloud_firestore` (in-memory) for business-logic
tests instead of the live emulator — faster, deterministic, CI-friendly. The
real emulator is reserved for *security-rules* testing (Milestone C). See
`test/README.md`.

- [x] ~~Set up the Firebase emulator~~ → chose `fake_cloud_firestore` + `firebase_auth_mocks` for logic tests (emulator deferred to rules testing in Milestone C).
- [x] **Unit-test pawn interest** (`gold_asset.dart`, 1.25%/month accrual) — not-pawned/zero-day/30-day/60-day/custom-rate cases.
- [x] **Unit-test labor-fee / pricing** logic — every tier & boundary across all 6 categories (Thai + English). **Found & fixed a bug:** `'earring'.contains('ring')` made earrings get ring fees.
- [x] **Unit-test wallet** (`wallet_service.dart`) — deposit/sale credit, withdrawal/purchase debit, insufficient-funds, exact-balance boundary, **atomic rollback**, cumulative running balance, streams. (Made `WalletService` + `IdGeneratorService` injectable.)
- [x] **Money-model round-trips** — `Wallet` / `WalletTransaction` toMap↔fromFirestore, int→double coercion, unknown-enum fallback.
- [x] **Replace placeholder `widget_test.dart`** — now a real `GoldRateCard` render test (full app-boot test needs Firebase Core mocks; deferred).
- [x] **Make `TradingService` injectable** — factory-injection pattern (no-arg call still returns the production singleton). Also made `InventoryLotService` and the `getUserDocRef` helper injectable.
- [x] **Integration-test the buy & sell flows** (`trading_service.dart`) — market-rate & FIFO cost basis, wallet debit, stock + lot draw-down, asset creation, ledger row, reward points; insufficient-funds & out-of-stock both reject atomically (no side effects); sell credits wallet, soft-deletes asset, records profit. **59 tests total.**
- [x] **Make `SavingsService` injectable + integration-test** — deposit (wallet debit, weight/invested credit, both ledgers), sell (wallet credit, ledger rows), **THB→weight→THB round-trip conserves money**, physical-bar withdrawal (0.25 multiple guard, premium fee, asset mint, stock −1), insufficient-funds & over-sell reject atomically. **67 tests total.** (Documented a `fake_cloud_firestore` limitation: `set(merge)+FieldValue.increment` in a tx isn't applied correctly, so the savings aggregate cache after a decrement is left to the emulator suite.)
- [x] **`pawn_service.dart` — injectable + tested.** Pure calculators (`calculatePawnLoan` 85% LTV; `calculatePawnOwed` standard interest, overdue penalty, 1-day minimum) and the full flow: pawn (loan→wallet, asset→pawned, `pawn_loans` opened, ledger row), redeem (wallet debit, loan fields cleared, `pawn_loans`→redeemed, profit=interest), pawn→redeem round-trip nets only interest; not-owned / not-pawned / insufficient-funds all reject atomically. **78 tests total.**

---

## 🟠 Milestone C — Visibility (errors & logging) — ✅ MOSTLY DONE (2026-06-10)

Make failures visible so future changes don't silently break money flows.

- [x] **Logging seam + crash-reporter hook** — added `lib/utils/app_logger.dart`: one `AppLogger` with `debug`/`warning`/`error`, where `error()` forwards to a pluggable `onError` hook. Tested (3 tests). **Native Firebase Crashlytics deferred** (needs console enablement + iOS/Android native config + a device build to verify) — it's a 2-line wire-up at the `AppLogger.onError` seam; steps documented in `app_logger.dart`.
- [x] **Audited `catch` blocks for silent failures** — routed the swallowed errors (post-sign-in sync, `getUserDocRef` self-heal, the three `_getDisplayName` fallbacks, the dashboard's background repair) through `AppLogger` so a persistent failure is now visible instead of vanishing. (One UI catch in `member_portfolio_page` already surfaces via SnackBar — left with its note.)
- [x] **Verified security rules with the Firebase emulator** — `firestore-tests/` runs `@firebase/rules-unit-testing` against `firestore.rules`: **23 assertions passing** covering member↔member wallet/asset/profile/transaction/pawn isolation, owner-only product & market-history writes, append-only (immutable) market history, public catalog read, and default-deny. Run with `cd firestore-tests && npm install && npm test`.

> Remaining: wire native Crashlytics when ready (enable in Firebase console → add the gradle/pod config → `AppLogger.onError = (e, s, {reason}) => FirebaseCrashlytics.instance.recordError(e, s, reason: reason);` in `main()`).

---

## 🟡 Milestone D — Slim the screens (architecture, round 2)

The services are clean now, but the pages are still huge — logic and Firestore wiring live in the UI. Shrink them with tests (Milestone B) as a safety net.

- [x] **`owner_overview_tab.dart`** — extracted all dashboard financial aggregations (wallet float, stock value/investment, savings liability, period profit/revenue/cost, counts, currency formatting, date-range filter) into a pure, unit-tested `lib/utils/owner_metrics.dart` (**14 tests**). Stream callbacks are now one-liners; behaviour unchanged. This is the template for the rest.
- [x] **`member_trading_page.dart`** — extracted `TradingMath` (snap-to-0.25, weight formatting, buy cost / sell value). (Buy/sell/pawn *mutations* already live in the services — covered in Milestone B.)
- [x] **`member_gold_savings_page.dart`** — extracted `SavingsRules` (physical-withdrawal premium fee, quarter-baht withdrawal rule), removing inline magic numbers.
- [x] **`owner_products_page.dart` + `member_portfolio_page.dart`** — extracted `ProductPricing` (unit sell price, per-unit margin / margin %, stock investment) and `PortfolioMath` (total weight incl. savings, total cost, market value).
- All four helpers are pure and unit-tested (`test/unit/screen_math_test.dart`, **12 tests**). **Honest note:** the goal here is *logic out of the UI into tested helpers*, not line count — the screens' bulk is `build()` rendering, so line counts barely moved. Aggressive widget-tree restructuring is deferred until there are widget tests to catch regressions.
- [x] **Widget tests for the reusable presentation layer** — `test/widgets/widgets_test.dart` (**8 tests**): `ProductCard` (price math, loading state, in-/out-of-stock tap behaviour), `NewsCard`, `OwnerMetricCard` (skeleton→streamed value, tap), `StoreInfoCard`. Firebase-free, so they run in plain `flutter test`. This is the safety net for any UI restructuring.
- [~] **State management (Riverpod) — pilot landed.** Added `flutter_riverpod`, wrapped the app in `ProviderScope`, and created `lib/providers/app_providers.dart` (`marketServiceProvider`, `goldRateProvider`). Migrated the home screen's live gold rate to a `GoldRateConsumer` `ConsumerWidget` that `ref.watch`es the provider. **This proves the injectable-screen pattern**: the consumer is fully tested by overriding `goldRateProvider` with a fake stream — no Firebase (`test/providers/gold_rate_provider_test.dart`, `test/widgets/gold_rate_consumer_test.dart`, loading/data/error). Next streams (wallet, portfolio, savings) follow the same shape; converting the big screens to `ConsumerStatefulWidget` is the incremental remainder.
- [~] **Centralize config** — started (savings premium fee is now a named constant; pawn rate/labor tiers already live in their services). A single `AppConfig` / Firestore `config` doc is still worthwhile.

---

## 🔵 Milestone E — Make it grow (features & UX)

Once the foundation holds. Reorder freely based on what the shop needs.

- [ ] **Push notifications (FCM)** — remind customers when a pawn is due/overdue.
- [ ] **Offline support** — Firestore persistence for flaky in-shop wifi.
- [ ] **Receipt / transaction export** (PDF or share sheet).
- [ ] **Input validation everywhere** — weights, prices, phone, password strength before writes.
- [ ] **English localization** alongside Thai (`intl` already present).
- [ ] **Owner: low-stock alerts** + end-of-day sales summary.
- [ ] **Scheduled Firestore backups** so business data is never lost.

---

## Ongoing habits (every working session)
- Commit small and often, with a clear message.
- Run `flutter analyze` before committing; keep the count at/near 0.
- When you touch a feature, add or update a test for it.
- Update this file: check off what's done, add what you discover.
