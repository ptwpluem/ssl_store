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

## 🧹 Milestone A — Tidy the repo (quick, do first)

Small loose ends from the big refactor. Low effort, removes noise.

- [ ] **Remove `lib.zip` from the repo** (227 KB binary backup) and add `*.zip` to `.gitignore`. Source backups don't belong in git.
- [ ] **Decide on `users.json`** — if it's test/seed data, delete it; secrets shouldn't sit at repo root.
- [ ] **Move design docs into a `docs/` folder** — `database_design_academic_review.md`, `firebase_database_assessment.md`, `ssl_store_firestore_er*.xml`, `UC10_appointment_management.xml`. Keep the root clean.
- [ ] **Finish the analyzer mop-up (28 → 0).** Fix the 2 remaining `use_build_context_synchronously` (guard with `if (!mounted) return;`), then the mechanical ones: `curly_braces` (8), `unnecessary_cast` (6), `constant_identifier_names` (3), etc.

---

## 🟢 Milestone B — Trust the money (testing) — TOP PRIORITY

There are still **zero real tests** (only the 30-line placeholder). The 9 new services are now cleanly separable and finally testable. Lock the money math down before changing more.

- [ ] **Set up the Firebase emulator** for local Firestore/Auth so tests never touch production.
- [ ] **Unit-test pawn interest** (`pawn_service.dart` / `gold_asset.dart`, 1.25%/month accrual) — known inputs → known THB.
- [ ] **Unit-test labor-fee / pricing** logic.
- [ ] **Unit-test wallet** (`wallet_service.dart`) — deposit, withdraw, insufficient balance, atomicity.
- [ ] **Integration-test the buy flow** (`trading_service.dart`) — stock decremented, wallet debited, transaction recorded, all-or-nothing.
- [ ] **Integration-test gold-savings** deposit/withdraw round-trip (THB→weight→THB) via `savings_service.dart`.
- [ ] **Replace placeholder `widget_test.dart`** with a real boot/login smoke test.

---

## 🟠 Milestone C — Visibility (errors & logging)

Make failures visible so future changes don't silently break money flows.

- [ ] **Add Crashlytics + a logger package**; report caught errors instead of swallowing them.
- [ ] **Audit `catch` blocks** across the 9 services for silent failures; log or surface them.
- [ ] **Verify security rules with the emulator** — confirm a member account cannot read another member's wallet/assets (the rules look right; prove it with a test).

---

## 🟡 Milestone D — Slim the screens (architecture, round 2)

The services are clean now, but the pages are still huge — logic and Firestore wiring live in the UI. Shrink them with tests (Milestone B) as a safety net.

- [ ] **`owner_overview_tab.dart` (1,508)** — extract calculations/queries into the owner/services layer; the widget should mostly render.
- [ ] **`member_trading_page.dart` (1,471)** — move buy/sell/pawn orchestration into `trading_service` / `pawn_service`.
- [ ] **`member_gold_savings_page.dart` (1,362)** — move deposit/withdraw math into `savings_service`.
- [ ] **`owner_products_page.dart` (1,178)** and **`member_portfolio_page.dart` (1,015)** — same treatment.
- [ ] **Consider a state-management layer** (Riverpod) once pages are thinner — pilot on the gold-rate stream first.
- [ ] **Centralize config** — interest rate, labor-fee tiers, fallback prices into one `AppConfig` / Firestore `config` doc.

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
