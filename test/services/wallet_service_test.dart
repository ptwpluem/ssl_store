import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/wallet_transaction.dart';
import 'package:ssl_store/services/id_generator_service.dart';
import 'package:ssl_store/services/wallet_service.dart';

/// WalletService is the single money primitive every flow (buy/sell/pawn/
/// savings) routes through, so its balance math, ledger writes, and atomicity
/// are the highest-value things to lock down. All tests run against an
/// in-memory Firestore — no emulator, no network.
void main() {
  late FakeFirebaseFirestore db;
  late WalletService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = WalletService(
      firestore: db,
      ids: IdGeneratorService(firestore: db),
    );
  });

  Future<String> walletIdFor(String uid) async {
    final q = await db
        .collection('wallets')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    return q.docs.first.id;
  }

  Future<double> balanceOf(String walletId) async {
    final doc = await db.collection('wallets').doc(walletId).get();
    return (doc.data()!['balance'] as num).toDouble();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> ledgerOf(
    String walletId,
  ) async {
    final snap = await db
        .collection('wallets')
        .doc(walletId)
        .collection('transactions')
        .get();
    return snap.docs;
  }

  group('createWalletForUser', () {
    test('creates a wallet with zero balance and the WAL- prefix', () async {
      await service.createWalletForUser('uid-1');

      final id = await walletIdFor('uid-1');
      expect(id, startsWith('WAL-'));
      final doc = await db.collection('wallets').doc(id).get();
      expect(doc.data()!['userId'], 'uid-1');
      expect(doc.data()!['balance'], 0.0);
    });

    test('is idempotent — calling twice does not create a second wallet', () async {
      await service.createWalletForUser('uid-1');
      await service.createWalletForUser('uid-1');

      final all = await db
          .collection('wallets')
          .where('userId', isEqualTo: 'uid-1')
          .get();
      expect(all.docs, hasLength(1));
    });
  });

  group('credits (deposit & sale increase balance)', () {
    for (final type in [
      WalletTransactionType.deposit,
      WalletTransactionType.sale,
    ]) {
      test('$type adds to the balance and records the ledger entry', () async {
        await service.createWalletForUser('uid-1');
        final walletId = await walletIdFor('uid-1');

        await service.performTransaction(
          walletId: walletId,
          amount: 1500.0,
          type: type,
          description: 'credit',
          referenceId: 'REF-1',
        );

        expect(await balanceOf(walletId), 1500.0);

        final ledger = await ledgerOf(walletId);
        expect(ledger, hasLength(1));
        final entry = ledger.first.data();
        expect(ledger.first.id, startsWith('WTX-'));
        expect(entry['amount'], 1500.0);
        expect(entry['type'], type.name);
        expect(entry['resultingBalance'], 1500.0);
        expect(entry['description'], 'credit');
        expect(entry['referenceId'], 'REF-1');
      });
    }
  });

  group('debits (withdrawal & purchase decrease balance)', () {
    for (final type in [
      WalletTransactionType.withdrawal,
      WalletTransactionType.purchase,
    ]) {
      test('$type subtracts from a sufficient balance', () async {
        await service.createWalletForUser('uid-1');
        final walletId = await walletIdFor('uid-1');
        await service.performTransaction(
          walletId: walletId,
          amount: 2000.0,
          type: WalletTransactionType.deposit,
        );

        await service.performTransaction(
          walletId: walletId,
          amount: 750.0,
          type: type,
        );

        expect(await balanceOf(walletId), 1250.0);
        expect(await ledgerOf(walletId), hasLength(2));
      });

      test('$type throws "Insufficient funds!" when balance is too low', () async {
        await service.createWalletForUser('uid-1');
        final walletId = await walletIdFor('uid-1');
        await service.performTransaction(
          walletId: walletId,
          amount: 100.0,
          type: WalletTransactionType.deposit,
        );

        expect(
          () => service.performTransaction(
            walletId: walletId,
            amount: 100.01,
            type: type,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Insufficient funds'),
            ),
          ),
        );
      });
    }

    test('a debit exactly equal to the balance is allowed (boundary)', () async {
      await service.createWalletForUser('uid-1');
      final walletId = await walletIdFor('uid-1');
      await service.performTransaction(
        walletId: walletId,
        amount: 500.0,
        type: WalletTransactionType.deposit,
      );

      await service.performTransaction(
        walletId: walletId,
        amount: 500.0,
        type: WalletTransactionType.purchase,
      );

      expect(await balanceOf(walletId), 0.0);
    });
  });

  group('atomicity', () {
    test('a rejected debit leaves balance and ledger untouched', () async {
      await service.createWalletForUser('uid-1');
      final walletId = await walletIdFor('uid-1');
      await service.performTransaction(
        walletId: walletId,
        amount: 100.0,
        type: WalletTransactionType.deposit,
      );

      // Attempt an over-withdrawal that must fail and roll back.
      await expectLater(
        service.performTransaction(
          walletId: walletId,
          amount: 9999.0,
          type: WalletTransactionType.withdrawal,
        ),
        throwsA(isA<Exception>()),
      );

      // Balance unchanged, and NO failed ledger entry was committed.
      expect(await balanceOf(walletId), 100.0);
      expect(await ledgerOf(walletId), hasLength(1)); // only the deposit
    });
  });

  group('cumulative correctness', () {
    test('a sequence of credits and debits yields the right running balance', () async {
      await service.createWalletForUser('uid-1');
      final walletId = await walletIdFor('uid-1');

      Future<void> tx(double amount, WalletTransactionType type) =>
          service.performTransaction(
            walletId: walletId,
            amount: amount,
            type: type,
          );

      await tx(1000, WalletTransactionType.deposit); // 1000
      await tx(2500, WalletTransactionType.sale); // 3500
      await tx(500, WalletTransactionType.purchase); // 3000
      await tx(1000, WalletTransactionType.withdrawal); // 2000

      expect(await balanceOf(walletId), 2000.0);

      final ledger = await ledgerOf(walletId);
      expect(ledger, hasLength(4));
      // Every ledger entry's resultingBalance is the running total at that point.
      final balances = ledger.map((d) => d.data()['resultingBalance']).toSet();
      expect(balances, containsAll(<double>[1000, 3500, 3000, 2000]));
    });
  });

  group('error handling', () {
    test('transacting on a non-existent wallet throws', () async {
      expect(
        () => service.performTransaction(
          walletId: 'WAL-does-not-exist',
          amount: 10,
          type: WalletTransactionType.deposit,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Wallet does not exist'),
          ),
        ),
      );
    });
  });

  group('streams', () {
    test('getWalletStream emits the current balance', () async {
      await service.createWalletForUser('uid-1');
      final walletId = await walletIdFor('uid-1');
      await service.performTransaction(
        walletId: walletId,
        amount: 4200.0,
        type: WalletTransactionType.deposit,
      );

      final wallet = await service.getWalletStream('uid-1').first;
      expect(wallet, isNotNull);
      expect(wallet!.userId, 'uid-1');
      expect(wallet.balance, 4200.0);
    });

    test('getWalletStream emits null when the user has no wallet', () async {
      final wallet = await service.getWalletStream('nobody').first;
      expect(wallet, isNull);
    });

    test('getTransactionsStream returns every ledger entry', () async {
      await service.createWalletForUser('uid-1');
      final walletId = await walletIdFor('uid-1');
      await service.performTransaction(
        walletId: walletId,
        amount: 100,
        type: WalletTransactionType.deposit,
      );
      await service.performTransaction(
        walletId: walletId,
        amount: 50,
        type: WalletTransactionType.purchase,
      );

      final entries = await service.getTransactionsStream(walletId).first;
      expect(entries, hasLength(2));
      expect(
        entries.map((e) => e.type),
        containsAll(<WalletTransactionType>[
          WalletTransactionType.deposit,
          WalletTransactionType.purchase,
        ]),
      );
    });
  });
}
