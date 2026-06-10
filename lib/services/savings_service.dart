import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/gold_savings.dart';
import '../models/notification_item.dart';
import '../models/wallet_transaction.dart';
import '../utils/app_logger.dart';
import 'firestore_helper.dart';
import 'id_generator_service.dart';
import 'wallet_service.dart';

// [1] ทองที่สะสมได้
// [2] ยอดเงินสะสม

class SavingsService {
  /// No-arg `SavingsService()` returns the app-wide singleton (production,
  /// unchanged). Passing any dependency builds an isolated instance for tests;
  /// sub-services default to ones backed by the injected [firestore].
  factory SavingsService({
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
    return SavingsService._(
      firestore: db,
      auth: auth ?? FirebaseAuth.instance,
      walletService: walletService ?? WalletService(firestore: db),
      ids: ids ?? IdGeneratorService(firestore: db),
    );
  }

  static final SavingsService _instance = SavingsService._(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    walletService: WalletService(),
    ids: IdGeneratorService(),
  );

  SavingsService._({
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

  // ─── Streams ──────────────────────────────────────────────────────────────

  Stream<GoldSavingsAccount> getGoldSavingsAccountStream() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(
        GoldSavingsAccount(
          totalWeightSaved: 0.0,
          totalAmountInvested: 0.0,
          lastUpdated: DateTime.now(),
        ),
      );
    }
    return Stream.fromFuture(getUserDocRef(uid, firestore: _firestore, auth: _auth)).asyncExpand((userRef) {
      return userRef.collection('savings').doc('account').snapshots().map((
        snapshot,
      ) {
        if (!snapshot.exists || snapshot.data() == null) {
          return GoldSavingsAccount(
            totalWeightSaved: 0.0,
            totalAmountInvested: 0.0,
            lastUpdated: DateTime.now(),
          );
        }
        return GoldSavingsAccount.fromMap(snapshot.data()!);
      });
    });
  }

  Stream<List<GoldSavingsTransaction>> getGoldSavingsTransactionsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return Stream.fromFuture(getUserDocRef(uid, firestore: _firestore, auth: _auth)).asyncExpand((userRef) {
      return userRef
          .collection('savings')
          .doc('account')
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(
                  (doc) => GoldSavingsTransaction.fromMap(doc.id, doc.data()),
                )
                .toList(),
          );
    });
  }

  // ─── Deposit ──────────────────────────────────────────────────────────────

  Future<void> depositToGoldSavings(
    double amountInTHB,
    double currentBuyPricePerBaht,
  ) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

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
    final id = await _ids.generateId('transactions', prefixOverride: 'SAV');
    final stxId = await _ids.generateId('savings_transactions');
    final notifId = await _ids.generateId('notifications');
    final displayName = await _getDisplayName(
      userRef,
    ); // reuse userRef — no extra Firestore call
    final weightGained =
        amountInTHB / currentBuyPricePerBaht; // [1] ทองที่สะสมได้
    final fmt = NumberFormat('#,##0.00');

    await _firestore.runTransaction((tx) async {
      // ── ALL reads before any writes ───────────────────────────────────────
      final walletSnap = await tx.get(walletRef); // READ 1

      // ── Writes begin here ─────────────────────────────────────────────────
      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletId,
        amount: amountInTHB,
        type: WalletTransactionType.purchase,
        description: 'Gold Savings Deposit',
        referenceId: id,
        preReadWalletSnapshot: walletSnap,
      );

      final savingsRef = userRef.collection('savings').doc('account');
      tx.set(savingsRef, {
        'totalWeightSaved': FieldValue.increment(weightGained),
        'totalAmountInvested': FieldValue.increment(
          amountInTHB,
        ), // [2] ยอดเงินสะสม เพิ่มเมื่อ Deposit, ลดเมื่อ Withdraw
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(
        savingsRef.collection('transactions').doc(stxId),
        GoldSavingsTransaction(
          id: stxId,
          amountInvested: amountInTHB,
          weightGained: weightGained,
          buyPriceAtTransaction: currentBuyPricePerBaht,
          timestamp: DateTime.now(),
        ).toMap(),
      );

      tx.set(_firestore.collection('transactions').doc(id), {
        'assetId': 'savings',
        'type': 'savings_deposit',
        'amount': amountInTHB,
        'weight': weightGained,
        'category': 'Savings',
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ออมทอง: ฝาก ฿${fmt.format(amountInTHB)}',
        'userId': uid,
        'userEmail': _auth.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      tx.set(
        userRef.collection('notifications').doc(notifId),
        NotificationItem(
          id: notifId,
          title: 'ฝากเงินออมทองสำเร็จ',
          message:
              'ฝากเงิน ฿${fmt.format(amountInTHB)} เข้าออมทองสำเร็จแล้ว ได้รับทองเพิ่ม ${weightGained.toStringAsFixed(4)} บาท',
          type: 'savings',
          timestamp: DateTime.now(),
          isRead: false,
        ).toMap(),
      );
    });
  }

  // ─── Sell from savings ────────────────────────────────────────────────────

  Future<void> sellFromGoldSavings(
    // ออกจา Saving โดยการ Sell
    double weightToSell,
    double currentSellPricePerBaht,
  ) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

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
    final id = await _ids.generateId('transactions', prefixOverride: 'SAV');
    final stxId = await _ids.generateId('savings_transactions');
    final notifId = await _ids.generateId('notifications');
    final displayName = await _getDisplayName(
      userRef,
    ); // reuse userRef — no extra Firestore call
    final amountInTHB = weightToSell * currentSellPricePerBaht;
    final fmt = NumberFormat('#,##0.00');

    await _firestore.runTransaction((tx) async {
      final savingsRef = userRef.collection('savings').doc('account');

      // ── ALL reads before any writes ───────────────────────────────────────
      final savingsDoc = await tx.get(savingsRef); // READ 1
      final walletSnap = await tx.get(walletRef); // READ 2

      final currentWeight =
          ((savingsDoc.data())?['totalWeightSaved'] ??
                  0.0 as num)
              .toDouble();

      if (currentWeight < weightToSell) {
        throw Exception('Insufficient gold weight in your savings.');
      }

      // ── Writes begin here ─────────────────────────────────────────────────
      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletId,
        amount: amountInTHB,
        type: WalletTransactionType.sale,
        description: 'Gold Savings Withdrawal',
        referenceId: id,
        preReadWalletSnapshot: walletSnap,
      );

      final proportionSold = weightToSell / currentWeight;
      final currentInvested =
          ((savingsDoc.data())?['totalAmountInvested'] ??
                  0.0 as num)
              .toDouble();

      tx.set(savingsRef, {
        'totalWeightSaved': FieldValue.increment(-weightToSell),
        'totalAmountInvested': FieldValue.increment(
          -(proportionSold * currentInvested),
        ),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(
        savingsRef.collection('transactions').doc(stxId),
        GoldSavingsTransaction(
          id: stxId,
          amountInvested: -amountInTHB,
          weightGained: -weightToSell,
          buyPriceAtTransaction: currentSellPricePerBaht,
          timestamp: DateTime.now(),
        ).toMap(),
      );

      tx.set(_firestore.collection('transactions').doc(id), {
        'assetId': 'savings',
        'type': 'savings_withdraw',
        'amount': amountInTHB,
        'weight': weightToSell,
        'category': 'Savings',
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ออมทอง: ขาย ${weightToSell.toStringAsFixed(4)} บาท',
        'userId': uid,
        'userEmail': _auth.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      tx.set(
        userRef.collection('notifications').doc(notifId),
        NotificationItem(
          id: notifId,
          title: 'ขายทองออมสำเร็จ',
          message:
              'ขายทองออมจำนวน ${weightToSell.toStringAsFixed(4)} บาท สำเร็จแล้ว คุณได้รับเงิน ฿${fmt.format(amountInTHB)} กลับเข้าวอลเล็ต',
          type: 'savings',
          timestamp: DateTime.now(),
          isRead: false,
        ).toMap(),
      );
    });
  }

  // ─── Withdraw physical gold bar ───────────────────────────────────────────

  /// Returns the new asset ID of the created gold bar asset.
  Future<String> withdrawPhysicalGoldBar(
    // ออกจาก Saving โดยการ Withdraw
    double weightToWithdraw,
    double currentBuyPricePerBaht,
    double premiumFee,
  ) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    if (weightToWithdraw % 0.25 != 0) {
      throw Exception('น้ำหนักทองที่ถอนได้ต้องเป็นทวีคูณของ 0.25 บาทเท่านั้น');
    }

    final walletQuery = await _firestore
        .collection('wallets')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');
    final walletId = walletQuery.docs.first.id;

    final userRef = await getUserDocRef(uid, firestore: _firestore, auth: _auth);
    final id = await _ids.generateId('transactions', prefixOverride: 'SAV');
    final assetId = await _ids.generateId('assets', prefixOverride: 'AST');
    final stxId = await _ids.generateId('savings_transactions');
    final notifId = await _ids.generateId('notifications');
    final displayName = await _getDisplayName(
      userRef,
    ); // reuse userRef — no extra Firestore call
    final walletRef = _firestore
        .collection('wallets')
        .doc(walletId);

    // Find the matching gold bar product before the transaction
    final productQuery = await _firestore
        .collection('products')
        .where('category', isEqualTo: 'ทองคำแท่ง')
        .where('weight', isEqualTo: weightToWithdraw)
        .limit(1)
        .get();
    final productDocRef = productQuery.docs.isNotEmpty
        ? productQuery.docs.first.reference
        : null;

    await _firestore.runTransaction((tx) async {
      final savingsRef = userRef.collection('savings').doc('account');

      // ── ALL reads before any writes ───────────────────────────────────────
      final savingsDoc = await tx.get(savingsRef); // READ 1
      final walletSnap = await tx.get(walletRef); // READ 2
      DocumentSnapshot? productSnap;
      if (productDocRef != null) {
        productSnap = await tx.get(productDocRef); // READ 3 (moved to top!)
      }

      // ── Validate before writes ────────────────────────────────────────────
      final currentWeight =
          ((savingsDoc.data())?['totalWeightSaved'] ??
                  0.0 as num)
              .toDouble();
      if (currentWeight < weightToWithdraw) {
        throw Exception('คุณมีทองสะสมไม่เพียงพอสำหรับการถอน');
      }
      if (productSnap != null &&
          ((productSnap.data() as Map<String, dynamic>?)?['stock'] ?? 0 as num)
                  .toInt() <=
              0) {
        throw Exception('ขออภัย ทองคำแท่งน้ำหนักนี้หมดสต็อกชั่วคราว');
      }

      // ── Writes begin here ─────────────────────────────────────────────────

      // Deduct premium fee from wallet
      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletId,
        amount: premiumFee,
        type: WalletTransactionType.purchase,
        description: 'ค่าธรรมเนียมถอนทองแท่ง ($weightToWithdraw บาท)',
        referenceId: id,
        preReadWalletSnapshot: walletSnap,
      );

      final proportionSold = weightToWithdraw / currentWeight;
      final currentInvested =
          ((savingsDoc.data())?['totalAmountInvested'] ??
                  0.0 as num)
              .toDouble();

      tx.set(savingsRef, {
        'totalWeightSaved': FieldValue.increment(-weightToWithdraw),
        'totalAmountInvested': FieldValue.increment(
          -(proportionSold * currentInvested),
        ),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(savingsRef.collection('transactions').doc(stxId), {
        'id': stxId,
        'amountInvested': 0.0,
        'weightGained': -weightToWithdraw,
        'buyPriceAtTransaction': currentBuyPricePerBaht,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'physical_withdrawal',
      });

      // Create the physical asset
      tx.set(userRef.collection('assets').doc(assetId), {
        'id': assetId,
        'name': 'ทองคำแท่ง ($weightToWithdraw บาท)',
        'weight': weightToWithdraw,
        'category': 'ทองคำแท่ง',
        'acquisitionDate': FieldValue.serverTimestamp(),
        'acquisitionPrice': weightToWithdraw * currentBuyPricePerBaht,
        'status': 'owned',
        'purity': 0.965,
      });

      // Decrement store stock (productSnap already read above)
      if (productDocRef != null) {
        tx.update(productDocRef, {'stock': FieldValue.increment(-1)});
      }

      tx.set(_firestore.collection('transactions').doc(id), {
        'assetId': assetId,
        'type': 'savings_physical_withdraw',
        'amount': premiumFee,
        'weight': weightToWithdraw,
        'category': 'ทองคำแท่ง',
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ออมทอง: ถอนทองแท่ง $weightToWithdraw บาท',
        'userId': uid,
        'userEmail': _auth.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      tx.set(userRef.collection('notifications').doc(notifId), {
        'id': notifId,
        'title': 'ถอนทองแท่งสำเร็จ',
        'message':
            'คุณได้ถอนทองแท่งจำนวน $weightToWithdraw บาท จากบัญชีออมทองเรียบร้อยแล้ว กรุณานัดหมายวันรับสินค้า',
        'type': 'savings',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    });

    return assetId;
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  // Accepts the already-fetched userRef to avoid a redundant getUserDocRef call.
  Future<String> _getDisplayName(DocumentReference userRef) async {
    try {
      final doc = await userRef.get();
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
