import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import 'id_generator_service.dart';

class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final IdGeneratorService _ids = IdGeneratorService();

  // Get stream of user's wallet
  Stream<Wallet?> getWalletStream(String userId) {
    return _firestore
        .collection('wallets')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return Wallet.fromFirestore(snapshot.docs.first);
      }
      return null;
    });
  }

  // Get transactions stream
  Stream<List<WalletTransaction>> getTransactionsStream(String walletId) {
    return _firestore
        .collection('wallets')
        .doc(walletId)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransaction.fromFirestore(doc))
            .toList());
  }

  // Create initial wallet for a new user
  Future<void> createWalletForUser(String userId) async {
    // Check if exists first
    final existing = await _firestore
        .collection('wallets')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      // Use WAL prefix so every wallet document is identifiable at a glance
      // (e.g. WAL-xK9mL2... instead of a bare Firestore auto-ID).
      final walletId = await _ids.generateId('wallets');
      await _firestore.collection('wallets').doc(walletId).set({
        'userId': userId,
        'balance': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Perform transaction using an overarching transaction (from MockService)
  Future<void> performTransactionWithTx({
    required Transaction transaction,
    required String walletId,
    required double amount,
    required WalletTransactionType type,
    String? description,
    String? referenceId,
  }) async {
    final walletRef = _firestore.collection('wallets').doc(walletId);

    // Use WTX prefix for wallet transaction IDs so ledger entries are
    // immediately distinguishable from global transaction IDs (BUY/SEL/etc).
    final wtxId = await _ids.generateId('wallet_transactions');
    final transactionRef = walletRef.collection('transactions').doc(wtxId);

    final walletSnapshot = await transaction.get(walletRef);
    if (!walletSnapshot.exists) {
      throw Exception("Wallet does not exist!");
    }

    double currentBalance = (walletSnapshot.data()?['balance'] ?? 0.0).toDouble();

    double newBalance = currentBalance;
    if (type == WalletTransactionType.deposit || type == WalletTransactionType.sale) {
      newBalance += amount;
    } else if (type == WalletTransactionType.withdrawal || type == WalletTransactionType.purchase) {
      if (currentBalance < amount) {
        throw Exception("Insufficient funds!");
      }
      newBalance -= amount;
    }

    // Update wallet balance
    transaction.update(walletRef, {
      'balance': newBalance,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Add to ledger
    transaction.set(transactionRef, {
      'amount': amount,
      'type': type.name,
      'resultingBalance': newBalance,
      'description': description,
      'referenceId': referenceId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Add transaction (deposits, purchases) using its own internal batch
  Future<void> performTransaction({
    required String walletId,
    required double amount,
    required WalletTransactionType type,
    String? description,
    String? referenceId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      await performTransactionWithTx(
        transaction: transaction,
        walletId: walletId,
        amount: amount,
        type: type,
        description: description,
        referenceId: referenceId,
      );
    });
  }
}
