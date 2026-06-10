import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/wallet.dart';
import 'package:ssl_store/models/wallet_transaction.dart';

/// These round-trips guard against `toMap`/`fromFirestore` drifting apart — a
/// silent way money data could be lost or mis-typed when written then re-read.
void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  group('WalletTransaction', () {
    test('survives a toMap -> Firestore -> fromFirestore round trip', () async {
      final original = WalletTransaction(
        id: 'WTX-1',
        amount: 1234.56,
        type: WalletTransactionType.purchase,
        resultingBalance: 8765.44,
        description: 'Purchase: สร้อยคอ',
        referenceId: 'BUY-1',
        timestamp: DateTime(2026, 6, 10, 14, 30),
      );

      await db.collection('t').doc('WTX-1').set(original.toMap());
      final restored = WalletTransaction.fromFirestore(
        await db.collection('t').doc('WTX-1').get(),
      );

      expect(restored.id, original.id);
      expect(restored.amount, original.amount);
      expect(restored.type, original.type);
      expect(restored.resultingBalance, original.resultingBalance);
      expect(restored.description, original.description);
      expect(restored.referenceId, original.referenceId);
      expect(restored.timestamp, original.timestamp);
    });

    test('each enum type name survives the round trip', () async {
      for (final type in WalletTransactionType.values) {
        await db.collection('t').doc('x').set(
              WalletTransaction(
                id: 'x',
                amount: 1,
                type: type,
                resultingBalance: 1,
                timestamp: DateTime(2026, 1, 1),
              ).toMap(),
            );
        final restored = WalletTransaction.fromFirestore(
          await db.collection('t').doc('x').get(),
        );
        expect(restored.type, type);
      }
    });

    test('unknown stored type falls back to deposit (no crash)', () async {
      await db.collection('t').doc('legacy').set({
        'amount': 10,
        'type': 'some_legacy_type',
        'resultingBalance': 10,
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      final restored = WalletTransaction.fromFirestore(
        await db.collection('t').doc('legacy').get(),
      );
      expect(restored.type, WalletTransactionType.deposit);
    });

    test('integer amounts from Firestore are coerced to double', () async {
      // Firestore may store a whole number as an int; the model must not throw.
      await db.collection('t').doc('int').set({
        'amount': 500, // int, not double
        'type': 'deposit',
        'resultingBalance': 500,
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      final restored = WalletTransaction.fromFirestore(
        await db.collection('t').doc('int').get(),
      );
      expect(restored.amount, 500.0);
      expect(restored.amount, isA<double>());
    });
  });

  group('Wallet', () {
    test('reads core fields from a Firestore document', () async {
      await db.collection('wallets').doc('WAL-1').set({
        'userId': 'uid-123',
        'balance': 4200.50,
        'updatedAt': Timestamp.fromDate(DateTime(2026, 6, 10)),
      });
      final wallet = Wallet.fromFirestore(
        await db.collection('wallets').doc('WAL-1').get(),
      );
      expect(wallet.id, 'WAL-1');
      expect(wallet.userId, 'uid-123');
      expect(wallet.balance, 4200.50);
      expect(wallet.updatedAt, DateTime(2026, 6, 10));
    });

    test('defaults gracefully when fields are missing', () async {
      await db.collection('wallets').doc('WAL-empty').set({});
      final wallet = Wallet.fromFirestore(
        await db.collection('wallets').doc('WAL-empty').get(),
      );
      expect(wallet.userId, '');
      expect(wallet.balance, 0.0);
    });
  });
}
