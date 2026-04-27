import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/gold_asset.dart';
import '../models/gold_transaction.dart';
import '../models/notification_item.dart';
import '../models/wallet_transaction.dart';
import 'firestore_helper.dart';
import 'id_generator_service.dart';
import 'wallet_service.dart';

/// Handles buy and sell transactions and manages a user's asset portfolio.
class TradingService {
  static final TradingService _instance = TradingService._internal();
  factory TradingService() => _instance;
  TradingService._internal();

  final WalletService _walletService = WalletService();
  final IdGeneratorService _ids = IdGeneratorService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Asset portfolio ──────────────────────────────────────────────────────

  Stream<List<GoldAsset>> getMemberAssetsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    final userRefFuture = getUserDocRef(uid);
    return Stream.fromFuture(userRefFuture).asyncExpand((userRef) {
      return userRef.collection('assets').snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) {
              final data = doc.data();
              return GoldAsset(
                id: doc.id,
                name: data['name'] ?? 'Unknown Asset',
                weight: (data['weight'] ?? 0 as num).toDouble(),
                category: data['category'] ?? 'General',
                acquisitionDate:
                    (data['acquisitionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
                acquisitionPrice: (data['acquisitionPrice'] ?? 0 as num).toDouble(),
                status: data['status'] ?? 'owned',
                loanAmount: (data['loanAmount'] as num?)?.toDouble(),
                pawnDate: (data['pawnDate'] as Timestamp?)?.toDate(),
                dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
                interestRate: (data['interestRate'] as num?)?.toDouble(),
                purity: (data['purity'] ?? 0.965 as num).toDouble(),
              );
            })
            // Exclude sold assets from the active portfolio view.
            // Sold assets are retained in Firestore for reconciliation but
            // should not appear in the customer's live holdings.
            .where((a) => a.status != 'sold')
            .toList();
      });
    });
  }

  // ─── Buy transaction ──────────────────────────────────────────────────────

  /// Creates a buy transaction. Deducts funds from the wallet, creates the
  /// asset in the portfolio, and decrements product stock if [productId] is given.
  Future<void> createBuyTransaction({
    required String assetName,
    required double weight,
    required double amount,
    String? category,
    String? productId,
    int quantity = 1,
    double purity = 0.965,
    double? laborFee,
  }) async {
    await _runRepairs();
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    final id = await _ids.generateId('transactions', prefixOverride: 'BUY');
    final displayName = await _getDisplayName(uid);

    final rateDoc = await FirebaseFirestore.instance.collection('market').doc('gold_rate').get();
    final buyRate = (rateDoc.data()?['buyPrice'] as num?)?.toDouble() ?? 41000.0;
    final totalCost = weight * buyRate;
    final profit = amount - totalCost;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final walletQuery = await FirebaseFirestore.instance
          .collection('wallets').where('userId', isEqualTo: uid).limit(1).get();
      if (walletQuery.docs.isEmpty) throw Exception('Wallet not found. Please top up first.');

      DocumentSnapshot? productDoc;
      if (productId != null) {
        productDoc = await tx.get(FirebaseFirestore.instance.collection('products').doc(productId));
        if (productDoc.exists) {
          if ((productDoc.data() as Map<String, dynamic>)['stock'] <= 0) {
            throw Exception('Product is out of stock.');
          }
        } else {
          productDoc = null;
        }
      }

      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletQuery.docs.first.id,
        amount: amount,
        type: WalletTransactionType.purchase,
        description: 'Purchase: $assetName',
        referenceId: id,
      );

      if (productId != null && productDoc != null) {
        tx.update(productDoc.reference, {'stock': FieldValue.increment(-quantity)});
      }

      final userRef = await getUserDocRef(uid);
      final assetRef = userRef.collection('assets').doc(id);
      tx.set(assetRef, {
        'name': assetName, 'weight': weight, 'category': category ?? 'General',
        'acquisitionDate': FieldValue.serverTimestamp(), 'acquisitionPrice': amount,
        'status': 'owned', 'purity': purity,
      });

      // ── Asset lifecycle event (immutable audit trail) ──────────────────────
      final buyEventId = await _ids.generateId('events');
      tx.set(assetRef.collection('events').doc(buyEventId), {
        'type': 'acquired',
        'timestamp': FieldValue.serverTimestamp(),
        'transactionId': id,
        'actorId': uid,
      });

      // ── Increment reward points and total buy amount on user document ──────
      tx.set(userRef, {
        'rewardPoints': FieldValue.increment(amount ~/ 1000),
        'totalBuyAmount': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      tx.set(FirebaseFirestore.instance.collection('transactions').doc(id), {
        'assetId': id, 'type': TransactionType.buy.name, 'amount': amount,
        'weight': weight, 'category': category ?? 'General',
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ซื้อ: $assetName ($weight บาท x$quantity)',
        'cost': totalCost, 'profit': profit, 'purity': purity, 'laborFee': laborFee,
        'userId': uid,
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      final notifId = await _ids.generateId('notifications');
      tx.set(userRef.collection('notifications').doc(notifId), NotificationItem(
        id: notifId,
        title: 'ทำรายการสำเร็จ',
        message: 'ซื้อ $assetName (${weight.toStringAsFixed(2)} บาท) สำเร็จแล้ว',
        type: 'store',
        timestamp: DateTime.now(),
        isRead: false,
      ).toMap());
    });
  }

  // ─── Sell transaction ─────────────────────────────────────────────────────

  Future<void> sellAsset({required GoldAsset asset, required double sellPrice}) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    final id = await _ids.generateId('transactions', prefixOverride: 'SEL');
    final displayName = await _getDisplayName(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final walletQuery = await FirebaseFirestore.instance
          .collection('wallets').where('userId', isEqualTo: uid).limit(1).get();
      if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');

      final userRef = await getUserDocRef(uid);
      final assetRef = userRef.collection('assets').doc(asset.id);
      final assetDoc = await tx.get(assetRef);
      if (!assetDoc.exists) throw Exception('Asset not found in portfolio.');

      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletQuery.docs.first.id,
        amount: sellPrice,
        type: WalletTransactionType.sale,
        description: 'ขายสินทรัพย์: ${asset.name}',
        referenceId: id,
      );

      // ── Soft-delete: mark sold instead of deleting ─────────────────────────
      // Never hard-delete financial assets — preserves audit trail and enables
      // reconciliation: total bought = owned + pawned + sold + savings.
      final profit = sellPrice - asset.acquisitionPrice;
      tx.update(assetRef, {
        'status': 'sold',
        'soldAt': FieldValue.serverTimestamp(),
        'soldPrice': sellPrice,
      });

      // ── Asset lifecycle event (immutable audit trail) ──────────────────────
      final sellEventId = await _ids.generateId('events');
      tx.set(assetRef.collection('events').doc(sellEventId), {
        'type': 'sold',
        'timestamp': FieldValue.serverTimestamp(),
        'transactionId': id,
        'actorId': uid,
        'soldPrice': sellPrice,
      });

      tx.set(FirebaseFirestore.instance.collection('transactions').doc(id), {
        'assetId': asset.id, 'type': TransactionType.sell.name,
        'amount': sellPrice, 'weight': asset.weight, 'category': asset.category,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ขาย: ${asset.name} (${asset.weight} บาท)',
        'cost': asset.acquisitionPrice, 'profit': profit, 'purity': asset.purity,
        'userId': uid,
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      final notifId = await _ids.generateId('notifications');
      final fmt = NumberFormat('#,##0.00');
      tx.set(userRef.collection('notifications').doc(notifId), NotificationItem(
        id: notifId,
        title: 'ขายสินทรัพย์สำเร็จ',
        message: 'ขาย ${asset.name} สำเร็จแล้ว เป็นเงิน ฿${fmt.format(sellPrice)}',
        type: 'store',
        timestamp: DateTime.now(),
        isRead: false,
      ).toMap());
    });
  }

  // ─── Data repair (called once per session) ────────────────────────────────

  bool _repairsRun = false;

  Future<void> _runRepairs() async {
    if (_repairsRun) return;
    _repairsRun = true;
    await _repairMissingPawnAssets();
    await repairAllTransactions();
  }

  Future<void> repairAllTransactions() async {
    final rateDoc = await FirebaseFirestore.instance.collection('market').doc('gold_rate').get();
    final buyRate = (rateDoc.data()?['buyPrice'] as num?)?.toDouble() ?? 41000.0;

    final buyTxQuery = await FirebaseFirestore.instance
        .collection('transactions').where('type', isEqualTo: 'buy').get();
    var batch = FirebaseFirestore.instance.batch();
    bool needed = false;
    for (var doc in buyTxQuery.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final cost = (data['cost'] as num?)?.toDouble();
      final profit = (data['profit'] as num?)?.toDouble();
      if (cost == null || profit == null || (amount - (cost + profit)).abs() > 1.0) {
        double weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
        if (weight <= 0 && amount > 0) weight = amount / (buyRate * 1.04);
        batch.update(doc.reference, {'cost': weight * buyRate, 'profit': amount - (weight * buyRate), 'weight': weight});
        needed = true;
      }
    }
    if (needed) { await batch.commit(); batch = FirebaseFirestore.instance.batch(); needed = false; }

    final redeemQuery = await FirebaseFirestore.instance
        .collection('transactions').where('type', isEqualTo: 'redeem').get();
    for (var doc in redeemQuery.docs) {
      final data = doc.data();
      if (data['profit'] == null || data['interestPaid'] == null) {
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        double principal = (data['principal'] as num?)?.toDouble() ?? 0.0;
        if (principal <= 0) principal = amount * 0.98;
        batch.update(doc.reference, {'principal': principal, 'interestPaid': amount - principal, 'profit': amount - principal});
        needed = true;
      }
    }
    if (needed) await batch.commit();
  }

  Future<void> _repairMissingPawnAssets() async {
    final query = await FirebaseFirestore.instance
        .collection('transactions').where('type', isEqualTo: 'pawn').get();
    if (query.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (var txDoc in query.docs) {
      final data = txDoc.data();
      final uid = data['userId'] as String?;
      if (uid == null) continue;
      final txId = txDoc.id.replaceAll(RegExp(r'[^0-9]'), '');
      final userRef = await getUserDocRef(uid);
      final assetRef = userRef.collection('assets').doc('a$txId');
      final assetDoc = await assetRef.get();
      if (!assetDoc.exists) {
        final ts = (data['timestamp'] as Timestamp?) ?? Timestamp.now();
        batch.set(assetRef, {
          'name': data['details']?.toString().split(':').last.trim() ?? 'Pawned Item',
          'weight': (data['weight'] as num?)?.toDouble() ?? 1.0,
          'category': 'General',
          'acquisitionDate': ts, 'acquisitionPrice': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'status': 'pawned', 'loanAmount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'pawnDate': ts,
          'dueDate': Timestamp.fromDate(ts.toDate().add(const Duration(days: 30))),
        });
      }
    }
    await batch.commit();
  }

  Future<String> _getDisplayName(String uid) async {
    try {
      final ref = await getUserDocRef(uid);
      final doc = await ref.get();
      final data = doc.data() as Map<String, dynamic>?;
      if (data?['firstName'] != null && data?['lastName'] != null) {
        return '${data!['firstName']} ${data['lastName']}';
      }
    } catch (_) {}
    return 'Unknown User';
  }
}
