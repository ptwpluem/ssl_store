# Firestore security-rules tests

Tests `../firestore.rules` against the real Firebase **emulator** — the rules
engine that runs in production. The Dart suite under `../test/` uses an
in-memory fake that ignores rules, so this is where access control is verified:
money/PII isolation between members, owner-only writes, append-only audit logs,
and default-deny.

## Run

```bash
cd firestore-tests
npm install          # once
npm test             # boots the Firestore emulator, runs rules.test.js, shuts down
```

Requires the Firebase CLI (`firebase`) and a JDK on PATH — the emulator is a
Java process. `npm test` wraps `firebase emulators:exec --only firestore`, so it
starts and tears the emulator down for you; nothing touches a real project
(it runs under the `demo-ssl-rules` project id).

## What's covered

See `rules.test.js` — 23 assertions across products (public read / owner write),
user profiles + assets, wallets, the transactions ledger, pawn loans, immutable
market history, and the default-deny catch-all.
