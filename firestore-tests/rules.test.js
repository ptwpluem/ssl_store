// Security-rules tests for ../firestore.rules, run against the Firestore
// emulator. These prove the access-control guarantees that fake_cloud_firestore
// can't (it ignores rules): money/PII isolation between members, owner-only
// writes, append-only audit logs, and default-deny.
//
// Run:  cd firestore-tests && npm install && npm test
// (npm test wraps `firebase emulators:exec --only firestore`.)

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-ssl-rules';
const OWNER_UID = 'owner_uid';

let env;

async function setup() {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });

  // Seed fixtures with rules bypassed.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // User profiles: the doc's `uid` field is the ownership key.
    await setDoc(doc(db, 'users/U_alice'), { uid: 'alice', email: 'alice@x.com' });
    await setDoc(doc(db, 'users/U_bob'), { uid: 'bob', email: 'bob@x.com' });
    await setDoc(doc(db, 'users/U_alice/assets/A1'), { name: 'Ring', weight: 1 });
    // Role mirror that makes OWNER_UID an owner.
    await setDoc(doc(db, `roles/${OWNER_UID}`), { role: 'owner' });
    // Wallets / ledgers carry a `userId` field equal to the Auth uid.
    await setDoc(doc(db, 'wallets/W_alice'), { userId: 'alice', balance: 100 });
    await setDoc(doc(db, 'transactions/T_alice'), { userId: 'alice', amount: 1 });
    await setDoc(doc(db, 'pawn_loans/L_alice'), { userId: 'alice', principal: 1 });
    await setDoc(doc(db, 'products/P1'), { name: 'Ring', stock: 5 });
    await setDoc(doc(db, 'markethistory/H1'), { price: 40000 });
  });
}

// ── tiny runner ────────────────────────────────────────────────────────────
const tests = [];
const test = (name, fn) => tests.push({ name, fn });

// Auth contexts.
const ctxs = () => ({
  alice: env.authenticatedContext('alice').firestore(),
  bob: env.authenticatedContext('bob').firestore(),
  owner: env.authenticatedContext(OWNER_UID).firestore(),
  anon: env.unauthenticatedContext().firestore(),
});

// ── public, read-only collections ────────────────────────────────────────
test('anyone may read the public product catalog', async () => {
  const { anon } = ctxs();
  await assertSucceeds(getDoc(doc(anon, 'products/P1')));
});
test('a member may NOT write products (owner-only)', async () => {
  const { alice } = ctxs();
  await assertFails(setDoc(doc(alice, 'products/P2'), { name: 'x', stock: 1 }));
});
test('an owner MAY write products', async () => {
  const { owner } = ctxs();
  await assertSucceeds(setDoc(doc(owner, 'products/P3'), { name: 'x', stock: 1 }));
});

// ── user profiles & subcollections ────────────────────────────────────────
test('a member may read their own profile', async () => {
  const { alice } = ctxs();
  await assertSucceeds(getDoc(doc(alice, 'users/U_alice')));
});
test('a member may NOT read another member profile', async () => {
  const { alice } = ctxs();
  await assertFails(getDoc(doc(alice, 'users/U_bob')));
});
test('an owner may read any member profile', async () => {
  const { owner } = ctxs();
  await assertSucceeds(getDoc(doc(owner, 'users/U_alice')));
});
test('a member may read their own assets subcollection', async () => {
  const { alice } = ctxs();
  await assertSucceeds(getDoc(doc(alice, 'users/U_alice/assets/A1')));
});
test('a member may NOT read another member assets', async () => {
  const { bob } = ctxs();
  await assertFails(getDoc(doc(bob, 'users/U_alice/assets/A1')));
});
test('an unauthenticated user may NOT read any profile', async () => {
  const { anon } = ctxs();
  await assertFails(getDoc(doc(anon, 'users/U_alice')));
});

// ── wallets (the money) ────────────────────────────────────────────────────
test('a member may read their own wallet', async () => {
  const { alice } = ctxs();
  await assertSucceeds(getDoc(doc(alice, 'wallets/W_alice')));
});
test('a member may NOT read another member wallet', async () => {
  const { bob } = ctxs();
  await assertFails(getDoc(doc(bob, 'wallets/W_alice')));
});
test('an owner may read any wallet', async () => {
  const { owner } = ctxs();
  await assertSucceeds(getDoc(doc(owner, 'wallets/W_alice')));
});
test('a member may create a wallet only with their own userId', async () => {
  const { alice } = ctxs();
  await assertSucceeds(setDoc(doc(alice, 'wallets/W_new'), { userId: 'alice', balance: 0 }));
});
test('a member may NOT create a wallet spoofing another userId', async () => {
  const { alice } = ctxs();
  await assertFails(setDoc(doc(alice, 'wallets/W_spoof'), { userId: 'bob', balance: 0 }));
});

// ── transactions ledger ────────────────────────────────────────────────────
test('a member may create a transaction tagged with their own userId', async () => {
  const { alice } = ctxs();
  await assertSucceeds(setDoc(doc(alice, 'transactions/T_new'), { userId: 'alice', amount: 5 }));
});
test('a member may NOT create a transaction spoofing another userId', async () => {
  const { alice } = ctxs();
  await assertFails(setDoc(doc(alice, 'transactions/T_spoof'), { userId: 'bob', amount: 5 }));
});
test('a member may NOT read another member transaction', async () => {
  const { bob } = ctxs();
  await assertFails(getDoc(doc(bob, 'transactions/T_alice')));
});

// ── pawn loans ──────────────────────────────────────────────────────────────
test('a member may read their own pawn loan', async () => {
  const { alice } = ctxs();
  await assertSucceeds(getDoc(doc(alice, 'pawn_loans/L_alice')));
});
test('a member may NOT read another member pawn loan', async () => {
  const { bob } = ctxs();
  await assertFails(getDoc(doc(bob, 'pawn_loans/L_alice')));
});

// ── market history: append-only audit trail ────────────────────────────────
test('any signed-in user may read market history', async () => {
  const { alice } = ctxs();
  await assertSucceeds(getDoc(doc(alice, 'markethistory/H1')));
});
test('only an owner may append market history', async () => {
  const { alice, owner } = ctxs();
  await assertFails(setDoc(doc(alice, 'markethistory/H2'), { price: 1 }));
  await assertSucceeds(setDoc(doc(owner, 'markethistory/H3'), { price: 1 }));
});
test('market history is immutable — even an owner cannot edit or delete it', async () => {
  const { owner } = ctxs();
  await assertFails(updateDoc(doc(owner, 'markethistory/H1'), { price: 2 }));
  await assertFails(deleteDoc(doc(owner, 'markethistory/H1')));
});

// ── default deny ────────────────────────────────────────────────────────────
test('an unknown collection is denied for everyone (default-deny)', async () => {
  const { alice } = ctxs();
  await assertFails(getDoc(doc(alice, 'secret_stuff/x')));
  await assertFails(setDoc(doc(alice, 'secret_stuff/x'), { a: 1 }));
});

(async () => {
  await setup();
  let passed = 0;
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  ✓ ${t.name}`);
      passed++;
    } catch (e) {
      console.error(`  ✗ ${t.name}\n      ${e.message}`);
      failed++;
    }
  }
  await env.cleanup();
  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
})();
