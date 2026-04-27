import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/gold_savings.dart';
import '../models/notification_item.dart';
import '../models/wallet_transaction.dart';
import 'firestore_helper.dart';
import 'id_generator_service.dart';
import 'wallet_service.dart';

/// Handles gold savings (ออมทอง): deposit, sell, and physical withdrawal.
class SavingsService {
  static final SavingsService _instance = SavingsService._internal();
  factory SavingsService() => _instance;
  SavingsService._internal();

  final WalletService _walletService = WalletService();
  final IdGeneratorService _ids = IdGeneratorService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Streams ──────────────────────────────────────────────────────────────

  Stream<GoldSavingsAccount> getGoldSavingsAccountStream() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(GoldSavingsAccount(
        totalWeightSaved: 0.0,
        totalAmountInvested: 0.0,
        lastUpdated: DateTime.now(),
      ));
    }
    return Stream.fromFuture(getUserDocRef(uid)).asyncExpand((userRef) {
      return userRef.collection('savings').doc('account').snapshots().map((snapshot) {
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
    return Stream.fromFuture(getUserDocRef(uid)).asyncExpand((userRef) {
      return userRef
          .collection('savings')
          .doc('account')
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => GoldSavingsTransaction.fromMap(doc.id, doc.data()))
              .toList());
    });
  }

  // ─── Deposit ──────────────────────────────────────────────────────────────

  Future<void> depositToGoldSavings(
    double amountInTHB,
    double currentBuyPricePerBaht,
  ) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    final walletQuery = await FirebaseFirestore.instance
        .collection('wallets').where('userId', isEqualTo: uid).limit(1).get();
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');
    final walletId = walletQuery.docs.first.id;

    final userRef = await getUserDocRef(uid);
    final id = await _ids.generateId('transactions', prefixOverride: 'SAV');
    final displayName = await _getDisplayName(uid);
    final weightGained = amountInTHB / currentBuyPricePerBaht;
    final fmt = NumberFormat('#,##0.00');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletId,
        amount: amountInTHB,
        type: WalletTransactionType.purchase,
        description: 'Gold Savings Deposit',
        referenceId: id,
      );

      final savingsRef = userRef.collection('savings').doc('account');
      tx.set(savingsRef, {
        'totalWeightSaved': FieldValue.increment(weightGained),
        'totalAmountInvested': FieldValue.increment(amountInTHB),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final stxId = await _ids.generateId('savings_transactions');
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

      tx.set(FirebaseFirestore.instance.collection('transactions').doc(id), {
        'assetId': 'savings',
        'type': 'savings_deposit',
        'amount': amountInTHB,
        'weight': weightGained,
        'category': 'Savings',
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ออมทอง: ฝาก ฿${fmt.format(amountInTHB)}',
        'userId': uid,
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      final notifId = await _ids.generateId('notifications');
      tx.set(userRef.collection('notifications').doc(notifId), NotificationItem(
        id: notifId,
        title: 'ฝากเงินออมทองสำเร็จ',
        message: 'ฝากเงิน ฿${fmt.format(amountInTHB)} เข้าออมทองสำเร็จแล้ว ได้รับทองเพิ่ม ${weightGained.toStringAsFixed(4)} บาท',
        type: 'savings',
        timestamp: DateTime.now(),
        isRead: false,
      ).toMap());
    });
  }

  // ─── Sell from savings ────────────────────────────────────────────────────

  Future<void> sellFromGoldSavings(
    double weightToSell,
    double currentSellPricePerBaht,
  ) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    final walletQuery = await FirebaseFirestore.instance
        .collection('wallets').where('userId', isEqualTo: uid).limit(1).get();
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');
    final walletId = walletQuery.docs.first.id;

    final userRef = await getUserDocRef(uid);
    final id = await _ids.generateId('transactions', prefixOverride: 'SAV');
    final displayName = await _getDisplayName(uid);
    final amountInTHB = weightToSell * currentSellPricePerBaht;
    final fmt = NumberFormat('#,##0.00');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final savingsRef = userRef.collection('savings').doc('account');
      final savingsDoc = await tx.get(savingsRef);
      final currentWeight =
          ((savingsDoc.data() as Map<String, dynamic>?)?['totalWeightSaved'] ?? 0.0 as num)
              .toDouble();

      if (currentWeight < weightToSell) {
        throw Exception('Insufficient gold weight in your savings.');
      }

      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletId,
        amount: amountInTHB,
        type: WalletTransactionType.sale,
        description: 'Gold Savings Withdrawal',
        referenceId: id,
      );

      final proportionSold = weightToSell / currentWeight;
      final currentInvested =
          ((savingsDoc.data() as Map<String, dynamic>?)?['totalAmountInvested'] ?? 0.0 as num)
              .toDouble();

      tx.set(savingsRef, {
        'totalWeightSaved': FieldValue.increment(-weightToSell),
        'totalAmountInvested': FieldValue.increment(-(proportionSold * currentInvested)),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final stxId = await _ids.generateId('savings_transactions');
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

      tx.set(FirebaseFirestore.instance.collection('transactions').doc(id), {
        'assetId': 'savings',
        'type': 'savings_withdraw',
        'amount': amountInTHB,
        'weight': weightToSell,
        'category': 'Savings',
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ออมทอง: ขาย ${weightToSell.toStringAsFixed(4)} บาท',
        'userId': uid,
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      final notifId = await _ids.generateId('notifications');
      tx.set(userRef.collection('notifications').doc(notifId), NotificationItem(
        id: notifId,
        title: 'ขายทองออมสำเร็จ',
        message: 'ขายทองออมจำนวน ${weightToSell.toStringAsFixed(4)} บาท สำเร็จแล้ว คุณได้รับเงิน ฿${fmt.format(amountInTHB)} กลับเข้าวอลเล็ต',
        type: 'savings',
        timestamp: DateTime.now(),
        isRead: false,
      ).toMap());
    });
  }

  // ─── Withdraw physical gold bar ───────────────────────────────────────────

  /// Returns the new asset ID of the created gold bar asset.
  Future<String> withdrawPhysicalGoldBar(
    double weightToWithdraw,
    double currentBuyPricePerBaht,
    double premiumFee,
  ) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    if (weightToWithdraw % 0.25 != 0) {
      throw Exception('น้ำหนักทองที่ถอนได้ต้องเป็นทวีคูณของ 0.25 บาทเท่านั้น');
    }

    final walletQuery = await FirebaseFirestore.instance
        .collection('wallets').where('userId', isEqualTo: uid).limit(1).get();
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');
    final walletId = walletQuery.docs.first.id;

    final userRef = await getUserDocRef(uid);
    final id = await _ids.generateId('transactions', prefixOverride: 'SAV');
    final assetId = await _ids.generateId('assets', prefixOverride: 'AST');
    final displayName = await _getDisplayName(uid);

    // Find the matching gold bar product before the transaction
    final productQuery = await FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: 'ทองคำแท่ง')
        .where('weight', isEqualTo: weightToWithdraw)
        .limit(1)
        .get();
    final productDocRef =
        productQuery.docs.isNotEmpty ? productQuery.docs.first.reference : null;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final savingsRef = userRef.collection('savings').doc('account');
      final savingsDoc = await tx.get(savingsRef);
      final currentWeight =
          ((savingsDoc.data() as Map<String, dynamic>?)?['totalWeightSaved'] ?? 0.0 as num)
              .toDouble();

      if (currentWeight < weightToWithdraw) {
        throw Exception('คุณมีทองสะสมไม่เพียงพอสำหรับการถอน');
      }

      // Deduct premium fee from wallet
      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletId,
        amount: premiumFee,
        type: WalletTransactionType.purchase,
        description: 'ค่าธรรมเนียมถอนทองแท่ง ($weightToWithdraw บาท)',
        referenceId: id,
      );

      final proportionSold = weightToWithdraw / currentWeight;
      final currentInvested =
          ((savingsDoc.data() as Map<String, dynamic>?)?['totalAmountInvested'] ?? 0.0 as num)
              .toDouble();

      tx.set(savingsRef, {
        'totalWeightSaved': FieldValue.increment(-weightToWithdraw),
        'totalAmountInvested': FieldValue.increment(-(proportionSold * currentInvested)),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final stxId = await _ids.generateId('savings_transactions');
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

      // Decrement store stock
      if (productDocRef != null) {
        final productSnap = await tx.get(productDocRef);
        final currentStock = (productSnap.data()?['stock'] ?? 0 as num).toInt();
        if (currentStock <= 0) {
          throw Exception('ขออภัย ทองคำแท่งน้ำหนักนี้หมดสต็อกชั่วคราว');
        }
        tx.update(productDocRef, {'stock': FieldValue.increment(-1)});
      }

      tx.set(FirebaseFirestore.instance.collection('transactions').doc(id), {
        'assetId': assetId,
        'type': 'savings_physical_withdraw',
        'amount': premiumFee,
        'weight': weightToWithdraw,
        'category': 'ทองคำแท่ง',
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ออมทอง: ถอนทองแท่ง $weightToWithdraw บาท',
        'userId': uid,
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      final notifId = await _ids.generateId('notifications');
      tx.set(userRef.collection('notifications').doc(notifId), {
        'id': notifId,
        'title': 'ถอนทองแท่งสำเร็จ',
        'message': 'คุณได้ถอนทองแท่งจำนวน $weightToWithdraw บาท จากบัญชีออมทองเรียบร้อยแล้ว กรุณานัดหมายวันรับสินค้า',
        'type': 'savings',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    });

    return assetId;
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
