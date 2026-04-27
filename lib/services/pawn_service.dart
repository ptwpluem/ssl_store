import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/gold_asset.dart';
import '../models/notification_item.dart';
import '../models/wallet_transaction.dart';
import 'firestore_helper.dart';
import 'id_generator_service.dart';
import 'wallet_service.dart';

/// Handles pawn (จำนำ) and redeem (ไถ่ถอน) transactions.
class PawnService {
  static final PawnService _instance = PawnService._internal();
  factory PawnService() => _instance;
  PawnService._internal();

  final WalletService _walletService = WalletService();
  final IdGeneratorService _ids = IdGeneratorService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Pawn an asset ────────────────────────────────────────────────────────

  Future<void> pawnAsset({
    required GoldAsset asset,
    required double loanAmount,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    final id = await _ids.generateId('transactions', prefixOverride: 'PWN');
    final displayName = await _getDisplayName(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final walletQuery = await FirebaseFirestore.instance
          .collection('wallets').where('userId', isEqualTo: uid).limit(1).get();
      if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');

      final userRef = await getUserDocRef(uid);
      final assetRef = userRef.collection('assets').doc(asset.id);
      final assetDoc = await tx.get(assetRef);

      if (!assetDoc.exists) throw Exception('Asset not found in portfolio.');
      if ((assetDoc.data() as Map<String, dynamic>)['status'] != 'owned') {
        throw Exception('Only fully owned assets can be pawned.');
      }

      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletQuery.docs.first.id,
        amount: loanAmount,
        type: WalletTransactionType.deposit,
        description: 'เงินกู้จำนำ: ${asset.name}',
        referenceId: id,
      );

      final dueDate = DateTime.now().add(const Duration(days: 30));
      tx.update(assetRef, {
        'status': 'pawned',
        'loanAmount': loanAmount,
        'pawnDate': FieldValue.serverTimestamp(),
        'dueDate': Timestamp.fromDate(dueDate),
        'interestRate': 0.0125,
        'loanId': id,   // ← cross-reference to pawn_loans document
      });

      // ── Create pawn loan as a first-class entity ───────────────────────────
      // Stored in a top-level collection so the owner can query ALL active
      // loans without scanning every user's assets subcollection.
      tx.set(FirebaseFirestore.instance.collection('pawn_loans').doc(id), {
        'userId': uid,
        'assetId': asset.id,
        'assetName': asset.name,
        'assetWeight': asset.weight,
        'assetCategory': asset.category,
        'principal': loanAmount,
        'interestRateMonthly': 0.0125,
        'startDate': FieldValue.serverTimestamp(),
        'dueDate': Timestamp.fromDate(dueDate),
        'gracePeriodDays': 7,
        'status': 'active',
        'openedByTxId': id,
      });

      // ── Asset lifecycle event (immutable audit trail) ──────────────────────
      final pawnEventId = await _ids.generateId('events');
      tx.set(assetRef.collection('events').doc(pawnEventId), {
        'type': 'pawned',
        'timestamp': FieldValue.serverTimestamp(),
        'transactionId': id,
        'actorId': uid,
        'loanId': id,
        'loanAmount': loanAmount,
      });

      tx.set(FirebaseFirestore.instance.collection('transactions').doc(id), {
        'assetId': asset.id,
        'type': 'pawn',
        'amount': loanAmount,
        'weight': asset.weight,
        'category': asset.category,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'จำนำ: ${asset.name} (${asset.weight} บาท)',
        'loanId': id,
        'userId': uid,
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      final notifId = await _ids.generateId('notifications');
      final fmt = NumberFormat('#,##0.00');
      tx.set(userRef.collection('notifications').doc(notifId), NotificationItem(
        id: notifId,
        title: 'จำนำสำเร็จ',
        message: 'จำนำ ${asset.name} สำเร็จแล้ว ได้รับเงินกู้ ฿${fmt.format(loanAmount)}',
        type: 'pawn',
        timestamp: DateTime.now(),
        isRead: false,
      ).toMap());
    });
  }

  // ─── Redeem an asset ──────────────────────────────────────────────────────

  Future<void> redeemAsset({
    required GoldAsset asset,
    required double totalOwed,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    final id = await _ids.generateId('transactions', prefixOverride: 'RED');
    final displayName = await _getDisplayName(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final walletQuery = await FirebaseFirestore.instance
          .collection('wallets').where('userId', isEqualTo: uid).limit(1).get();
      if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');

      final userRef = await getUserDocRef(uid);
      final assetRef = userRef.collection('assets').doc(asset.id);
      final assetDoc = await tx.get(assetRef);

      if (!assetDoc.exists) throw Exception('Asset not found in portfolio.');
      if ((assetDoc.data() as Map<String, dynamic>)['status'] != 'pawned') {
        throw Exception('Asset is not currently pawned.');
      }

      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletQuery.docs.first.id,
        amount: totalOwed,
        type: WalletTransactionType.withdrawal,
        description: 'Pawn Redemption: ${asset.name}',
        referenceId: id,
      );

      final assetData = assetDoc.data() as Map<String, dynamic>;
      final principal = (assetData['loanAmount'] as num?)?.toDouble() ?? 0.0;
      final interestPaid = totalOwed - principal;
      final loanId = assetData['loanId'] as String?;

      tx.update(assetRef, {
        'status': 'owned',
        'loanAmount': FieldValue.delete(),
        'pawnDate': FieldValue.delete(),
        'dueDate': FieldValue.delete(),
        'interestRate': FieldValue.delete(),
        'loanId': FieldValue.delete(),
      });

      // ── Close the pawn loan record ─────────────────────────────────────────
      if (loanId != null) {
        tx.update(
          FirebaseFirestore.instance.collection('pawn_loans').doc(loanId),
          {
            'status': 'redeemed',
            'closedByTxId': id,
            'totalInterestPaid': interestPaid,
            'redeemedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      // ── Asset lifecycle event (immutable audit trail) ──────────────────────
      final redeemEventId = await _ids.generateId('events');
      tx.set(assetRef.collection('events').doc(redeemEventId), {
        'type': 'redeemed',
        'timestamp': FieldValue.serverTimestamp(),
        'transactionId': id,
        'actorId': uid,
        'totalOwed': totalOwed,
        'interestPaid': interestPaid,
      });

      tx.set(FirebaseFirestore.instance.collection('transactions').doc(id), {
        'assetId': asset.id,
        'type': 'redeem',
        'amount': totalOwed,
        'principal': principal,
        'interestPaid': interestPaid,
        'profit': interestPaid,
        'cost': 0.0,
        'purity': asset.purity,
        'weight': asset.weight,
        'category': asset.category,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ไถ่ถอน: ${asset.name} (${asset.weight} บาท)',
        'loanId': loanId,
        'userId': uid,
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      final notifId = await _ids.generateId('notifications');
      final fmt = NumberFormat('#,##0.00');
      tx.set(userRef.collection('notifications').doc(notifId), NotificationItem(
        id: notifId,
        title: 'ไถ่ถอนสินทรัพย์สำเร็จ',
        message: 'ไถ่ถอน ${asset.name} สำเร็จแล้ว ยอดชำระทั้งหมด: ฿${fmt.format(totalOwed)}',
        type: 'pawn',
        timestamp: DateTime.now(),
        isRead: false,
      ).toMap());
    });
  }

  // ─── Calculation helpers ──────────────────────────────────────────────────

  /// Returns 85% of the current buy value as the loan offer.
  double calculatePawnLoan(double weight, double currentBuyPrice) {
    return (weight * currentBuyPrice) * 0.85;
  }

  /// Breaks down the total owed into principal, standard interest, and
  /// any overdue penalty interest. [monthlyRate] is a decimal (e.g. 0.0125).
  Map<String, double> calculatePawnOwed(
    double principal,
    DateTime pawnDate,
    DateTime dueDate,
    double monthlyRate,
  ) {
    final now = DateTime.now();
    int daysPawned = now.difference(pawnDate).inDays;
    if (daysPawned < 1) daysPawned = 1;

    final standardInterest = principal * monthlyRate * (daysPawned / 30.0);
    double penaltyInterest = 0.0;
    if (now.isAfter(dueDate)) {
      final daysOverdue = now.difference(dueDate).inDays;
      penaltyInterest = principal * 0.02 * (daysOverdue / 30.0);
    }

    return {
      'principal': principal,
      'standardInterest': standardInterest,
      'penaltyInterest': penaltyInterest,
      'totalOwed': principal + standardInterest + penaltyInterest,
    };
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

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
