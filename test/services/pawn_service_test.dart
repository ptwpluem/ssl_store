import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/gold_asset.dart';
import 'package:ssl_store/models/wallet_transaction.dart';
import 'package:ssl_store/services/id_generator_service.dart';
import 'package:ssl_store/services/pawn_service.dart';
import 'package:ssl_store/services/wallet_service.dart';

/// Pawn (จำนำ) lends cash against an asset; redeem (ไถ่ถอน) repays it. The loan
/// amount, interest, and the owned<->pawned state machine are all money, so we
/// pin the pure calculators and the full pawn/redeem flow incl. atomicity.
void main() {
  const uid = 'uid-1';
  const userDocId = 'CST-1';

  // ─── Pure calculators (no Firebase) ────────────────────────────────────────

  group('calculatePawnLoan', () {
    final svc = PawnService(
      firestore: FakeFirebaseFirestore(),
      auth: MockFirebaseAuth(),
    );

    test('offers 85% of the gold buy value', () {
      expect(svc.calculatePawnLoan(1.0, 40000), 34000.0); // 40000 * 0.85
      expect(svc.calculatePawnLoan(0.5, 40000), 17000.0);
    });
  });

  group('calculatePawnOwed', () {
    final svc = PawnService(
      firestore: FakeFirebaseFirestore(),
      auth: MockFirebaseAuth(),
    );

    test('standard interest only, before the due date', () {
      final pawnDate = DateTime.now().subtract(const Duration(days: 30, hours: 1));
      final dueDate = DateTime.now().add(const Duration(days: 30));
      final r = svc.calculatePawnOwed(30000, pawnDate, dueDate, 0.0125);

      // 30000 * 0.0125 * (30/30) = 375; no penalty.
      expect(r['standardInterest'], closeTo(375.0, 1e-6));
      expect(r['penaltyInterest'], 0.0);
      expect(r['totalOwed'], closeTo(30375.0, 1e-6));
    });

    test('adds penalty interest once overdue', () {
      final pawnDate = DateTime.now().subtract(const Duration(days: 50, hours: 1));
      final dueDate = DateTime.now().subtract(const Duration(days: 20, hours: 1));
      final r = svc.calculatePawnOwed(30000, pawnDate, dueDate, 0.0125);

      // standard: 30000 * 0.0125 * (50/30) = 625
      // penalty:  30000 * 0.02   * (20/30) = 400
      expect(r['standardInterest'], closeTo(625.0, 1e-6));
      expect(r['penaltyInterest'], closeTo(400.0, 1e-6));
      expect(r['totalOwed'], closeTo(31025.0, 1e-6));
    });

    test('charges a minimum of one day even when pawned moments ago', () {
      final now = DateTime.now();
      final r = svc.calculatePawnOwed(30000, now, now.add(const Duration(days: 30)), 0.0125);
      // daysPawned floored to 1: 30000 * 0.0125 * (1/30) = 12.5
      expect(r['standardInterest'], closeTo(12.5, 1e-6));
    });
  });

  // ─── Pawn / redeem flow (in-memory Firestore) ──────────────────────────────

  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late WalletService wallet;
  late PawnService pawn;

  Future<void> bootstrap({double initialBalance = 0}) async {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: 'test@example.com'),
    );
    wallet = WalletService(firestore: db, ids: IdGeneratorService(firestore: db));
    pawn = PawnService(firestore: db, auth: auth, walletService: wallet);

    await db.collection('users').doc(userDocId).set({
      'uid': uid,
      'firstName': 'Test',
      'lastName': 'User',
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

  Future<void> seedAsset(Map<String, dynamic> data) => db
      .collection('users')
      .doc(userDocId)
      .collection('assets')
      .doc('AST-1')
      .set(data);

  GoldAsset ownedAsset() => GoldAsset(
        id: 'AST-1',
        name: 'สร้อยคอทองคำ',
        weight: 1.0,
        category: 'necklace',
        acquisitionDate: DateTime(2026, 1, 1),
        acquisitionPrice: 40000,
        status: 'owned',
      );

  Future<Map<String, dynamic>?> assetData() async => (await db
          .collection('users')
          .doc(userDocId)
          .collection('assets')
          .doc('AST-1')
          .get())
      .data();

  Future<double> balance() async =>
      ((await db.collection('wallets').doc(await _walletId(db, uid)).get())
              .data()!['balance'] as num)
          .toDouble();

  group('pawnAsset', () {
    test('lends the loan into the wallet and pawns the asset', () async {
      await bootstrap(initialBalance: 10000);
      await seedAsset({
        'name': 'สร้อยคอทองคำ',
        'weight': 1.0,
        'category': 'necklace',
        'acquisitionPrice': 40000.0,
        'status': 'owned',
        'purity': 0.965,
      });

      await pawn.pawnAsset(asset: ownedAsset(), loanAmount: 34000);

      // Loan credited to wallet.
      expect(await balance(), 44000.0); // 10000 + 34000

      // Asset flipped to pawned with loan metadata.
      final a = (await assetData())!;
      expect(a['status'], 'pawned');
      expect(a['loanAmount'], 34000.0);
      expect(a['interestRate'], 0.0125);
      expect(a['loanId'], isNotNull);

      // First-class pawn_loans record opened, keyed by the txn id.
      final loanId = a['loanId'] as String;
      final loan = await db.collection('pawn_loans').doc(loanId).get();
      expect(loan.exists, isTrue);
      expect(loan.data()!['status'], 'active');
      expect(loan.data()!['principal'], 34000.0);

      // Global ledger row.
      final g = (await db.collection('transactions').where('type', isEqualTo: 'pawn').get()).docs;
      expect(g, hasLength(1));
      expect(g.first.data()['amount'], 34000.0);
    });

    test('refuses to pawn an asset that is not fully owned', () async {
      await bootstrap(initialBalance: 10000);
      await seedAsset({'name': 'x', 'weight': 1.0, 'status': 'pawned'});

      await expectLater(
        pawn.pawnAsset(asset: ownedAsset(), loanAmount: 34000),
        throwsA(isA<Exception>()),
      );
      expect(await balance(), 10000.0); // no loan paid out
    });
  });

  group('redeemAsset', () {
    Future<void> seedPawned() async {
      await seedAsset({
        'name': 'สร้อยคอทองคำ',
        'weight': 1.0,
        'category': 'necklace',
        'acquisitionPrice': 40000.0,
        'status': 'pawned',
        'loanAmount': 34000.0,
        'interestRate': 0.0125,
        'loanId': 'PWN-1',
        'purity': 0.965,
      });
      await db.collection('pawn_loans').doc('PWN-1').set({
        'userId': uid,
        'principal': 34000.0,
        'status': 'active',
      });
    }

    GoldAsset pawnedAsset() => GoldAsset(
          id: 'AST-1',
          name: 'สร้อยคอทองคำ',
          weight: 1.0,
          category: 'necklace',
          acquisitionDate: DateTime(2026, 1, 1),
          acquisitionPrice: 40000,
          status: 'pawned',
          loanAmount: 34000,
        );

    test('repays the loan, frees the asset, and closes the loan record', () async {
      await bootstrap(initialBalance: 50000);
      await seedPawned();

      await pawn.redeemAsset(asset: pawnedAsset(), totalOwed: 34500);

      // Wallet debited the full amount owed.
      expect(await balance(), 15500.0); // 50000 - 34500

      // Asset back to owned with loan fields cleared.
      final a = (await assetData())!;
      expect(a['status'], 'owned');
      expect(a.containsKey('loanAmount'), isFalse);
      expect(a.containsKey('loanId'), isFalse);

      // Loan record closed with the interest recorded.
      final loan = await db.collection('pawn_loans').doc('PWN-1').get();
      expect(loan.data()!['status'], 'redeemed');
      expect(loan.data()!['totalInterestPaid'], closeTo(500.0, 1e-9));

      // Global ledger row: profit == interest paid.
      final g = (await db.collection('transactions').where('type', isEqualTo: 'redeem').get()).docs;
      expect(g, hasLength(1));
      expect(g.first.data()['principal'], 34000.0);
      expect(g.first.data()['interestPaid'], closeTo(500.0, 1e-9));
      expect(g.first.data()['profit'], closeTo(500.0, 1e-9));
    });

    test('refuses to redeem an asset that is not pawned', () async {
      await bootstrap(initialBalance: 50000);
      await seedAsset({'name': 'x', 'weight': 1.0, 'status': 'owned'});

      await expectLater(
        pawn.redeemAsset(asset: pawnedAsset(), totalOwed: 34500),
        throwsA(isA<Exception>()),
      );
    });

    test('insufficient funds to redeem throws and changes nothing', () async {
      await bootstrap(initialBalance: 1000); // can't cover 34500
      await seedPawned();

      await expectLater(
        pawn.redeemAsset(asset: pawnedAsset(), totalOwed: 34500),
        throwsA(isA<Exception>()),
      );

      expect(await balance(), 1000.0); // untouched
      expect((await assetData())!['status'], 'pawned'); // still pawned
      final loan = await db.collection('pawn_loans').doc('PWN-1').get();
      expect(loan.data()!['status'], 'active'); // still open
    });
  });

  group('pawn -> redeem round trip', () {
    test('returns the asset to owned and nets only the interest in cash', () async {
      await bootstrap(initialBalance: 100000);
      await seedAsset({
        'name': 'สร้อยคอทองคำ',
        'weight': 1.0,
        'category': 'necklace',
        'acquisitionPrice': 40000.0,
        'status': 'owned',
        'purity': 0.965,
      });

      await pawn.pawnAsset(asset: ownedAsset(), loanAmount: 34000); // +34000
      expect(await balance(), 134000.0);

      // The asset is now pawned; pawnAsset stored the loanId on the doc, which
      // redeemAsset reads back — the passed object doesn't carry it.
      final pawnedNow = GoldAsset(
        id: 'AST-1',
        name: 'สร้อยคอทองคำ',
        weight: 1.0,
        category: 'necklace',
        acquisitionDate: DateTime(2026, 1, 1),
        acquisitionPrice: 40000,
        status: 'pawned',
        loanAmount: 34000,
      );

      await pawn.redeemAsset(asset: pawnedNow, totalOwed: 34500); // -34500

      // Net cash change = -interest (500); asset owned again.
      expect(await balance(), 99500.0);
      expect((await assetData())!['status'], 'owned');
    });
  });

  group('auth guard', () {
    test('pawn throws when not logged in', () async {
      await bootstrap(initialBalance: 10000);
      final loggedOut =
          PawnService(firestore: db, auth: MockFirebaseAuth(signedIn: false), walletService: wallet);
      await expectLater(
        loggedOut.pawnAsset(asset: ownedAsset(), loanAmount: 1000),
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
