import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/gold_asset.dart';
import 'package:ssl_store/models/wallet_transaction.dart';
import 'package:ssl_store/services/id_generator_service.dart';
import 'package:ssl_store/services/trading_service.dart';
import 'package:ssl_store/services/wallet_service.dart';

/// End-to-end buy/sell tests for TradingService against an in-memory Firestore.
/// These assert the *whole* effect of a transaction — wallet, stock, lot,
/// portfolio asset, ledger row — and that a rejected transaction changes
/// nothing (atomicity). This is the highest-stakes flow in the app.
void main() {
  const uid = 'uid-1';
  const userDocId = 'CST-1';

  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late WalletService wallet;
  late TradingService trading;

  /// Builds a signed-in user with a Firestore profile + wallet, and returns the
  /// wired-up TradingService backed entirely by the fake.
  Future<void> bootstrap({double initialBalance = 0}) async {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: 'test@example.com'),
    );
    wallet = WalletService(firestore: db, ids: IdGeneratorService(firestore: db));
    trading = TradingService(firestore: db, auth: auth, walletService: wallet);

    // getUserDocRef resolves the profile by its `uid` field.
    await db.collection('users').doc(userDocId).set({
      'uid': uid,
      'firstName': 'Test',
      'lastName': 'User',
      'email': 'test@example.com',
    });

    await wallet.createWalletForUser(uid);
    if (initialBalance > 0) {
      final walletId = await _walletIdFor(db, uid);
      await wallet.performTransaction(
        walletId: walletId,
        amount: initialBalance,
        type: WalletTransactionType.deposit,
      );
    }

    // A market rate is read during the buy flow's repair pass and as the
    // fallback cost basis when no FIFO lot exists.
    await db.collection('market').doc('gold_rate').set({
      'buyPrice': 40000.0,
      'sellPrice': 40100.0,
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> assets() async =>
      (await db.collection('users').doc(userDocId).collection('assets').get())
          .docs;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> buyTxns() async =>
      (await db.collection('transactions').where('type', isEqualTo: 'buy').get())
          .docs;

  Future<double> balance() async {
    final walletId = await _walletIdFor(db, uid);
    final doc = await db.collection('wallets').doc(walletId).get();
    return (doc.data()!['balance'] as num).toDouble();
  }

  group('createBuyTransaction — raw gold (market-rate cost basis)', () {
    test('debits the wallet, creates the asset, and records the ledger row', () async {
      await bootstrap(initialBalance: 100000);

      await trading.createBuyTransaction(
        assetName: 'ทองคำแท่ง 1 บาท',
        weight: 1.0,
        amount: 41000,
        category: 'Gold Bar',
      );

      // Wallet: 100000 - 41000.
      expect(await balance(), 59000.0);

      // Portfolio: one owned asset at the per-unit price.
      final a = await assets();
      expect(a, hasLength(1));
      expect(a.first.data()['status'], 'owned');
      expect(a.first.data()['weight'], 1.0);
      expect(a.first.data()['acquisitionPrice'], 41000.0);
      expect(a.first.data()['category'], 'Gold Bar');

      // Ledger: cost from market rate (1.0 * 40000), profit = amount - cost.
      final txns = await buyTxns();
      expect(txns, hasLength(1));
      final tx = txns.first.data();
      expect(tx['amount'], 41000.0);
      expect(tx['cost'], 40000.0);
      expect(tx['profit'], 1000.0);
      expect(tx['costMethod'], 'market_rate');
      expect(tx['userId'], uid);

      // Reward points = amount ~/ 1000; lifetime buy total recorded.
      final userDoc = await db.collection('users').doc(userDocId).get();
      expect(userDoc.data()!['rewardPoints'], 41);
      expect(userDoc.data()!['totalBuyAmount'], 41000.0);
    });
  });

  group('createBuyTransaction — catalog product (FIFO lot cost basis)', () {
    Future<void> seedProductWithLot({
      required int stock,
      required double unitCost,
      int lotQty = 5,
    }) async {
      await db.collection('products').doc('PRD-1').set({
        'name': 'ทองคำแท่ง',
        'category': 'Gold Bar',
        'stock': stock,
      });
      await db
          .collection('products')
          .doc('PRD-1')
          .collection('inventory_lots')
          .doc('LOT-1')
          .set({
        'productId': 'PRD-1',
        'productName': 'ทองคำแท่ง',
        'quantity': lotQty,
        'remainingQuantity': lotQty,
        'unitCost': unitCost,
        'purchaseDate': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
    }

    test('uses the lot unit cost, decrements stock and the lot remaining', () async {
      await bootstrap(initialBalance: 100000);
      await seedProductWithLot(stock: 5, unitCost: 38000);

      await trading.createBuyTransaction(
        assetName: 'ทองคำแท่ง 1 บาท',
        weight: 1.0,
        amount: 41000,
        category: 'Gold Bar',
        productId: 'PRD-1',
      );

      expect(await balance(), 59000.0);

      // Cost basis comes from the lot (38000), not the market rate (40000).
      final tx = (await buyTxns()).first.data();
      expect(tx['cost'], 38000.0);
      expect(tx['profit'], 3000.0);
      expect(tx['costMethod'], 'fifo');
      expect(tx['lotId'], 'LOT-1');

      // Catalog stock decremented and the FIFO lot drawn down.
      final product = await db.collection('products').doc('PRD-1').get();
      expect(product.data()!['stock'], 4);
      final lot = await db
          .collection('products')
          .doc('PRD-1')
          .collection('inventory_lots')
          .doc('LOT-1')
          .get();
      expect(lot.data()!['remainingQuantity'], 4);
    });
  });

  group('atomicity & guards', () {
    test('insufficient funds throws and changes nothing', () async {
      await bootstrap(initialBalance: 1000); // far less than the price

      await expectLater(
        trading.createBuyTransaction(
          assetName: 'ทองคำแท่ง 1 บาท',
          weight: 1.0,
          amount: 41000,
          category: 'Gold Bar',
        ),
        throwsA(isA<Exception>()),
      );

      expect(await balance(), 1000.0); // untouched
      expect(await assets(), isEmpty); // no asset created
      expect(await buyTxns(), isEmpty); // no ledger row
    });

    test('buying an out-of-stock product throws and changes nothing', () async {
      await bootstrap(initialBalance: 100000);
      await db.collection('products').doc('PRD-OOS').set({
        'name': 'ทองคำแท่ง',
        'category': 'Gold Bar',
        'stock': 0,
      });

      await expectLater(
        trading.createBuyTransaction(
          assetName: 'ทองคำแท่ง',
          weight: 1.0,
          amount: 41000,
          category: 'Gold Bar',
          productId: 'PRD-OOS',
        ),
        throwsA(isA<Exception>()),
      );

      expect(await balance(), 100000.0);
      expect(await assets(), isEmpty);
    });

    test('throws when the user is not logged in', () async {
      await bootstrap(initialBalance: 100000);
      final loggedOut = TradingService(
        firestore: db,
        auth: MockFirebaseAuth(signedIn: false),
        walletService: wallet,
      );

      await expectLater(
        loggedOut.createBuyTransaction(
          assetName: 'x',
          weight: 1.0,
          amount: 100,
          category: 'Gold Bar',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('sellAsset', () {
    test('credits the wallet, marks the asset sold, and records profit', () async {
      await bootstrap(initialBalance: 0);

      // Seed an owned asset bought at 38000.
      await db
          .collection('users')
          .doc(userDocId)
          .collection('assets')
          .doc('AST-1')
          .set({
        'name': 'สร้อยคอทองคำ',
        'weight': 1.0,
        'category': 'necklace',
        'acquisitionDate': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'acquisitionPrice': 38000.0,
        'status': 'owned',
        'purity': 0.965,
      });

      final asset = GoldAsset(
        id: 'AST-1',
        name: 'สร้อยคอทองคำ',
        weight: 1.0,
        category: 'necklace',
        acquisitionDate: DateTime(2026, 1, 1),
        acquisitionPrice: 38000.0,
        status: 'owned',
      );

      await trading.sellAsset(asset: asset, sellPrice: 41000);

      // Wallet credited by the sale price.
      expect(await balance(), 41000.0);

      // Asset soft-deleted (marked sold), not removed.
      final sold = await db
          .collection('users')
          .doc(userDocId)
          .collection('assets')
          .doc('AST-1')
          .get();
      expect(sold.data()!['status'], 'sold');
      expect(sold.data()!['soldPrice'], 41000.0);

      // Sell ledger row with profit = sellPrice - acquisitionPrice.
      final sellTxns = (await db
              .collection('transactions')
              .where('type', isEqualTo: 'sell')
              .get())
          .docs;
      expect(sellTxns, hasLength(1));
      expect(sellTxns.first.data()['profit'], 3000.0);
      expect(sellTxns.first.data()['amount'], 41000.0);
    });

    test('throws when selling an asset not in the portfolio', () async {
      await bootstrap(initialBalance: 0);
      final ghost = GoldAsset(
        id: 'AST-GHOST',
        name: 'ไม่มีจริง',
        weight: 1.0,
        category: 'ring',
        acquisitionDate: DateTime(2026, 1, 1),
        acquisitionPrice: 1000,
        status: 'owned',
      );
      await expectLater(
        trading.sellAsset(asset: ghost, sellPrice: 5000),
        throwsA(isA<Exception>()),
      );
    });
  });
}

Future<String> _walletIdFor(FakeFirebaseFirestore db, String uid) async {
  final q = await db
      .collection('wallets')
      .where('userId', isEqualTo: uid)
      .limit(1)
      .get();
  return q.docs.first.id;
}
