import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/gold_asset.dart';
import '../models/notification_item.dart';
import '../models/wallet_transaction.dart';
import '../utils/app_logger.dart';
import 'firestore_helper.dart';
import 'id_generator_service.dart';
import 'wallet_service.dart';

// [1] Interest Rate

/// Handles pawn (จำนำ) and redeem (ไถ่ถอน) transactions.
class PawnService {
  /// No-arg `PawnService()` returns the app-wide singleton (production,
  /// unchanged). Passing any dependency builds an isolated instance for tests;
  /// sub-services default to ones backed by the injected [firestore].
  factory PawnService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    WalletService? walletService,
    IdGeneratorService? ids,
  }) {
    if (firestore == null &&
        auth == null &&
        walletService == null &&
        ids == null) {
      return _instance;
    }
    final db = firestore ?? FirebaseFirestore.instance;
    return PawnService._(
      firestore: db,
      auth: auth ?? FirebaseAuth.instance,
      walletService: walletService ?? WalletService(firestore: db),
      ids: ids ?? IdGeneratorService(firestore: db),
    );
  }

  static final PawnService _instance = PawnService._(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    walletService: WalletService(),
    ids: IdGeneratorService(),
  );

  PawnService._({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required WalletService walletService,
    required IdGeneratorService ids,
  })  : _firestore = firestore,
        _auth = auth,
        _walletService = walletService,
        _ids = ids;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final WalletService _walletService;
  final IdGeneratorService _ids;

  String? get _uid => _auth.currentUser?.uid;

  // ─── Pawn an asset ────────────────────────────────────────────────────────

  Future<void> pawnAsset({
    // จำนำทอง
    required GoldAsset asset,
    required double loanAmount,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    // ── Pre-generate all IDs and resolve wallet OUTSIDE the transaction ───────
    // Firestore transactions must not contain additional async reads/writes
    // beyond tx.get() calls. Generating IDs and querying the wallet here
    // prevents any accidental reads-after-writes inside runTransaction.
    final id = await _ids.generateId('transactions', prefixOverride: 'PWN');
    final pawnEventId = await _ids.generateId('events');
    final notifId = await _ids.generateId('notifications');
    final displayName = await _getDisplayName(uid);

    final walletQuery = await _firestore
        .collection('wallets')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');
    final walletId = walletQuery.docs.first.id;
    final walletRef = _firestore
        .collection('wallets')
        .doc(walletId);

    final userRef = await getUserDocRef(uid, firestore: _firestore, auth: _auth);
    final fmt = NumberFormat('#,##0.00');

    await _firestore.runTransaction((tx) async {
      // ── ALL reads before any writes ───────────────────────────────────────
      final assetRef = userRef.collection('assets').doc(asset.id);
      final assetDoc = await tx.get(assetRef); // READ 1
      final walletSnap = await tx.get(walletRef); // READ 2

      if (!assetDoc.exists) throw Exception('Asset not found in portfolio.');
      if ((assetDoc.data() as Map<String, dynamic>)['status'] != 'owned') {
        throw Exception('Only fully owned assets can be pawned.');
      }

      // ── Writes begin here ─────────────────────────────────────────────────
      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletId,
        amount: loanAmount,
        type: WalletTransactionType.deposit,
        description: 'เงินกู้จำนำ: ${asset.name}',
        referenceId: id,
        preReadWalletSnapshot: walletSnap,
      );

      final dueDate = DateTime.now().add(const Duration(days: 30));
      tx.update(assetRef, {
        'status': 'pawned',
        'loanAmount': loanAmount,
        'pawnDate': FieldValue.serverTimestamp(),
        'dueDate': Timestamp.fromDate(dueDate),
        'interestRate': 0.0125, // [1] Interest Rate
        'loanId': id, // ← cross-reference to pawn_loans document
      });

      // ── Create pawn loan as a first-class entity ───────────────────────────
      // Stored in a top-level collection so the owner can query ALL active
      // loans without scanning every user's assets subcollection.
      tx.set(_firestore.collection('pawn_loans').doc(id), {
        'userId': uid,
        'assetId': asset.id,
        'assetName': asset.name,
        'assetWeight': asset.weight,
        'assetCategory': asset.category,
        'principal': loanAmount,
        'interestRateMonthly': 0.0125, // monthly rate
        'startDate': FieldValue.serverTimestamp(),
        'dueDate': Timestamp.fromDate(dueDate),
        'gracePeriodDays': 7,
        'status': 'active',
        'openedByTxId': id,
      });

      // ── Asset lifecycle event (immutable audit trail) ──────────────────────
      tx.set(assetRef.collection('events').doc(pawnEventId), {
        'type': 'pawned',
        'timestamp': FieldValue.serverTimestamp(),
        'transactionId': id,
        'actorId': uid,
        'loanId': id,
        'loanAmount': loanAmount,
      });

      tx.set(_firestore.collection('transactions').doc(id), {
        'assetId': asset.id,
        'type': 'pawn',
        'amount': loanAmount,
        'weight': asset.weight,
        'category': asset.category,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'จำนำ: ${asset.name} (${asset.weight} บาท)',
        'loanId': id,
        'userId': uid,
        'userEmail': _auth.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      tx.set(
        userRef.collection('notifications').doc(notifId),
        NotificationItem(
          id: notifId,
          title: 'จำนำสำเร็จ',
          message:
              'จำนำ ${asset.name} สำเร็จแล้ว ได้รับเงินกู้ ฿${fmt.format(loanAmount)}',
          type: 'pawn',
          timestamp: DateTime.now(),
          isRead: false,
        ).toMap(),
      );
    });
  }

  // ─── Redeem an asset ──────────────────────────────────────────────────────

  Future<void> redeemAsset({
    required GoldAsset asset,
    required double totalOwed,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    // ── Pre-generate all IDs and resolve wallet OUTSIDE the transaction ───────
    final id = await _ids.generateId('transactions', prefixOverride: 'RED');
    final redeemEventId = await _ids.generateId('events');
    final notifId = await _ids.generateId('notifications');
    final displayName = await _getDisplayName(uid);

    final walletQuery = await _firestore
        .collection('wallets')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');
    final walletId = walletQuery.docs.first.id;
    final walletRef = _firestore
        .collection('wallets')
        .doc(walletId);

    final userRef = await getUserDocRef(uid, firestore: _firestore, auth: _auth);
    final fmt = NumberFormat('#,##0.00');

    await _firestore.runTransaction((tx) async {
      // ── ALL reads before any writes ───────────────────────────────────────
      final assetRef = userRef.collection('assets').doc(asset.id);
      final assetDoc = await tx.get(assetRef); // READ 1
      final walletSnap = await tx.get(walletRef); // READ 2

      if (!assetDoc.exists) throw Exception('Asset not found in portfolio.');
      if ((assetDoc.data() as Map<String, dynamic>)['status'] != 'pawned') {
        throw Exception('Asset is not currently pawned.');
      }

      final assetData = assetDoc.data() as Map<String, dynamic>;
      final principal = (assetData['loanAmount'] as num?)?.toDouble() ?? 0.0;
      final interestPaid = totalOwed - principal;
      final loanId = assetData['loanId'] as String?;

      // ── Writes begin here ─────────────────────────────────────────────────
      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletId,
        amount: totalOwed,
        type: WalletTransactionType.withdrawal,
        description: 'ไถ่ถอนจำนำ: ${asset.name}',
        referenceId: id,
        preReadWalletSnapshot: walletSnap,
      );

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
          _firestore.collection('pawn_loans').doc(loanId),
          {
            'status': 'redeemed',
            'closedByTxId': id,
            'totalInterestPaid': interestPaid,
            'redeemedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      // ── Asset lifecycle event (immutable audit trail) ──────────────────────
      tx.set(assetRef.collection('events').doc(redeemEventId), {
        'type': 'redeemed',
        'timestamp': FieldValue.serverTimestamp(),
        'transactionId': id,
        'actorId': uid,
        'totalOwed': totalOwed,
        'interestPaid': interestPaid,
      });

      tx.set(_firestore.collection('transactions').doc(id), {
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
        'userEmail': _auth.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      tx.set(
        userRef.collection('notifications').doc(notifId),
        NotificationItem(
          id: notifId,
          title: 'ไถ่ถอนสินทรัพย์สำเร็จ',
          message:
              'ไถ่ถอน ${asset.name} สำเร็จแล้ว ยอดชำระทั้งหมด: ฿${fmt.format(totalOwed)}',
          type: 'pawn',
          timestamp: DateTime.now(),
          isRead: false,
        ).toMap(),
      );
    });
  }

  // ─── Calculation helpers ──────────────────────────────────────────────────

  /// Returns 85% of the current buy value as the loan offer.
  double calculatePawnLoan(double weight, double currentBuyPrice) {
    // คำนวณยอดเงินกู้
    return (weight * currentBuyPrice) * 0.85;
  }

  /// Breaks down the total owed into principal, standard interest, and
  /// any overdue penalty interest. [monthlyRate] is a decimal (e.g. 0.0125).
  Map<String, double> calculatePawnOwed(
    // คำนวนยอดที่ต้องชำระ
    double principal,
    DateTime pawnDate,
    DateTime dueDate,
    double monthlyRate,
  ) {
    // [2] สูตรคำนวนณแบบปกติ = 30557.5 * 0.0125 * (1/30) = 12.73 -> 13
    // ยอดชำระรวม = 30558 + 13 = 30,570
    final now = DateTime.now();
    int daysPawned = now.difference(pawnDate).inDays;
    if (daysPawned < 1) daysPawned = 1;

    // [3] สูตรคำนวนแบบพิเศษ | เริม 14 May -> make the 1st payment at 13 July (50 days)
    // Normal Rate: 30557 * 0.0125 * (50/30) = 636.7
    // Special Rate: 30557 * 0.02 * (20/30) = 407.4 -> ส่วนต่างที่ค้างจ่าย 20 วัน
    // Total Paid = 30557 + 636 + 407 = 31,601
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
      final ref = await getUserDocRef(uid, firestore: _firestore, auth: _auth);
      final doc = await ref.get();
      final data = doc.data() as Map<String, dynamic>?;
      if (data?['firstName'] != null && data?['lastName'] != null) {
        return '${data!['firstName']} ${data['lastName']}';
      }
    } catch (e, s) {
      AppLogger.debug('Could not resolve display name', error: e, stackTrace: s);
    }
    return 'Unknown User';
  }
}
