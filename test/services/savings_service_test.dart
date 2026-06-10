import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/wallet_transaction.dart';
import 'package:ssl_store/services/id_generator_service.dart';
import 'package:ssl_store/services/savings_service.dart';
import 'package:ssl_store/services/wallet_service.dart';

/// Gold-savings converts THB <-> gold weight at the live rate, so the headline
/// guarantee is that money in == money out at the same price (no value leaks).
///
/// KNOWN FAKE LIMITATION: fake_cloud_firestore mis-handles `FieldValue.increment`
/// inside `tx.set(..., SetOptions(merge: true))` — it stores the delta instead of
/// adding to the existing value (verified directly). The savings *aggregate* doc
/// (`totalWeightSaved` / `totalAmountInvested`) is updated that way, so its value
/// after a DECREMENT can't be asserted here. We therefore verify the reliable
/// source-of-truth instead — wallet balance (explicit arithmetic), the global +
/// per-deposit ledger rows, asset minting, and stock (which uses `tx.update`,
/// where the fake increments correctly). Asserting the aggregate cache after a
/// sell/withdraw is left to the Firebase-emulator suite (Milestone C).
void main() {
  const uid = 'uid-1';
  const userDocId = 'CST-1';

  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late WalletService wallet;
  late SavingsService savings;

  Future<void> bootstrap({double initialBalance = 0}) async {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: 'test@example.com'),
    );
    wallet = WalletService(firestore: db, ids: IdGeneratorService(firestore: db));
    savings = SavingsService(firestore: db, auth: auth, walletService: wallet);

    await db.collection('users').doc(userDocId).set({
      'uid': uid,
      'firstName': 'Test',
      'lastName': 'User',
      'email': 'test@example.com',
    });

    await wallet.createWalletForUser(uid);
    if (initialBalance > 0) {
      await wallet.performTransaction(
        walletId: await _walletId(db, uid),
        amount: initialBalance,
        type: WalletTransactionType.deposit,
      );
    }
  }

  Future<double> balance() async {
    final doc = await db.collection('wallets').doc(await _walletId(db, uid)).get();
    return (doc.data()!['balance'] as num).toDouble();
  }

  Future<Map<String, dynamic>?> savingsAccount() async {
    final doc = await db
        .collection('users')
        .doc(userDocId)
        .collection('savings')
        .doc('account')
        .get();
    return doc.data();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> globalTxns(
    String type,
  ) async =>
      (await db.collection('transactions').where('type', isEqualTo: type).get())
          .docs;

  group('depositToGoldSavings', () {
    test('debits wallet, credits weight + invested, writes both ledgers', () async {
      await bootstrap(initialBalance: 100000);

      // 41000 THB at 41000/baht -> exactly 1.0 baht of gold.
      await savings.depositToGoldSavings(41000, 41000);

      expect(await balance(), 59000.0);

      final acct = await savingsAccount();
      expect(acct!['totalWeightSaved'], closeTo(1.0, 1e-9));
      expect(acct['totalAmountInvested'], closeTo(41000.0, 1e-9));

      // Per-deposit savings ledger row.
      final stx = (await db
              .collection('users')
              .doc(userDocId)
              .collection('savings')
              .doc('account')
              .collection('transactions')
              .get())
          .docs;
      expect(stx, hasLength(1));
      expect(stx.first.data()['amountInvested'], 41000.0);
      expect(stx.first.data()['weightGained'], closeTo(1.0, 1e-9));
      expect(stx.first.data()['buyPriceAtTransaction'], 41000.0);

      // Global ledger row.
      final g = await globalTxns('savings_deposit');
      expect(g, hasLength(1));
      expect(g.first.data()['amount'], 41000.0);
      expect(g.first.data()['weight'], closeTo(1.0, 1e-9));
    });

    test('insufficient funds throws and changes nothing', () async {
      await bootstrap(initialBalance: 1000);

      await expectLater(
        savings.depositToGoldSavings(41000, 41000),
        throwsA(isA<Exception>()),
      );

      expect(await balance(), 1000.0);
      expect(await savingsAccount(), isNull); // account never created
      expect(await globalTxns('savings_deposit'), isEmpty);
    });
  });

  group('sellFromGoldSavings', () {
    test('credits the wallet and records the withdrawal in both ledgers', () async {
      await bootstrap(initialBalance: 100000);
      await savings.depositToGoldSavings(41000, 41000); // 1.0 baht, bal 59000

      // Sell half a baht at 42000/baht -> +21000 THB.
      await savings.sellFromGoldSavings(0.5, 42000);

      expect(await balance(), 80000.0); // 59000 + 21000 (reliable: explicit math)

      // Global ledger row.
      final g = await globalTxns('savings_withdraw');
      expect(g, hasLength(1));
      expect(g.first.data()['amount'], closeTo(21000.0, 1e-9));
      expect(g.first.data()['weight'], closeTo(0.5, 1e-9));

      // Per-transaction savings ledger row (plain set — reliable): a sell is
      // recorded as negative invested + negative weight.
      final stx = (await db
              .collection('users')
              .doc(userDocId)
              .collection('savings')
              .doc('account')
              .collection('transactions')
              .where('weightGained', isLessThan: 0)
              .get())
          .docs;
      expect(stx, hasLength(1));
      expect(stx.first.data()['amountInvested'], closeTo(-21000.0, 1e-9));
      expect(stx.first.data()['weightGained'], closeTo(-0.5, 1e-9));

      // NOTE: post-sell totalWeightSaved (0.5) / totalAmountInvested (20500 =
      // 41000 - 0.5*41000) are correct in production but can't be asserted here
      // — see the fake-limitation note at the top of this file.
    });

    test('selling more weight than saved throws and changes nothing', () async {
      await bootstrap(initialBalance: 100000);
      await savings.depositToGoldSavings(41000, 41000); // 1.0 baht
      final balBefore = await balance();

      await expectLater(
        savings.sellFromGoldSavings(2.0, 42000),
        throwsA(isA<Exception>()),
      );

      expect(await balance(), balBefore);
      expect((await savingsAccount())!['totalWeightSaved'], closeTo(1.0, 1e-9));
      expect(await globalTxns('savings_withdraw'), isEmpty);
    });
  });

  group('round trip (THB -> weight -> THB)', () {
    test('deposit then sell-all at the same price restores the money', () async {
      await bootstrap(initialBalance: 100000);

      // Deposit 41000 at a 40000 rate -> 1.025 baht of gold.
      await savings.depositToGoldSavings(41000, 40000);
      final acct = await savingsAccount();
      final weight = (acct!['totalWeightSaved'] as num).toDouble();
      expect(weight, closeTo(1.025, 1e-9));

      // Sell every baht back at the same rate -> original cash returned.
      await savings.sellFromGoldSavings(weight, 40000);

      // The headline guarantee: no value leaks across a full round trip.
      // (Wallet uses explicit arithmetic, so this is reliable; the savings
      // aggregate returning to 0 is correct in production but un-assertable
      // here — see the fake-limitation note at the top.)
      expect(await balance(), closeTo(100000.0, 1e-6));
    });
  });

  group('withdrawPhysicalGoldBar', () {
    test('rejects a weight that is not a multiple of 0.25 baht', () async {
      await bootstrap(initialBalance: 100000);
      await savings.depositToGoldSavings(41000, 41000);

      await expectLater(
        savings.withdrawPhysicalGoldBar(0.3, 41000, 500),
        throwsA(isA<Exception>()),
      );
    });

    test('deducts the premium fee, draws down savings, mints the asset, and decrements stock', () async {
      await bootstrap(initialBalance: 100000);
      await savings.depositToGoldSavings(41000, 41000); // 1.0 baht, bal 59000

      await db.collection('products').doc('PRD-BAR-1').set({
        'name': 'ทองคำแท่ง 1 บาท',
        'category': 'ทองคำแท่ง',
        'weight': 1.0,
        'stock': 5,
      });

      final assetId =
          await savings.withdrawPhysicalGoldBar(1.0, 41000, 500);

      // Wallet charged only the premium fee (reliable: explicit math).
      expect(await balance(), 58500.0); // 59000 - 500
      // (totalWeightSaved drops by 1.0 baht in production — un-assertable here,
      // see the fake-limitation note at the top.)

      // A real, owned asset was minted in the portfolio.
      expect(assetId, startsWith('AST-'));
      final asset = await db
          .collection('users')
          .doc(userDocId)
          .collection('assets')
          .doc(assetId)
          .get();
      expect(asset.exists, isTrue);
      expect(asset.data()!['status'], 'owned');
      expect(asset.data()!['weight'], 1.0);
      expect(asset.data()!['category'], 'ทองคำแท่ง');

      // Store stock decremented.
      final product = await db.collection('products').doc('PRD-BAR-1').get();
      expect(product.data()!['stock'], 4);

      expect(await globalTxns('savings_physical_withdraw'), hasLength(1));
    });
  });

  group('auth guard', () {
    test('deposit throws when not logged in', () async {
      await bootstrap(initialBalance: 100000);
      final loggedOut = SavingsService(
        firestore: db,
        auth: MockFirebaseAuth(signedIn: false),
        walletService: wallet,
      );
      await expectLater(
        loggedOut.depositToGoldSavings(1000, 41000),
        throwsA(isA<Exception>()),
      );
    });
  });
}

Future<String> _walletId(FakeFirebaseFirestore db, String uid) async {
  final q = await db
      .collection('wallets')
      .where('userId', isEqualTo: uid)
      .limit(1)
      .get();
  return q.docs.first.id;
}
