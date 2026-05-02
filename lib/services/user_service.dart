import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

import '../models/gold_transaction.dart';
import '../models/notification_item.dart';
import '../models/wallet_transaction.dart';
import 'firestore_helper.dart';
import 'id_generator_service.dart';
import 'wallet_service.dart';

/// Manages user profile data, wallet balance, and transaction history.
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final WalletService _walletService = WalletService();
  final IdGeneratorService _ids = IdGeneratorService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Profile ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUserProfile() async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');
    final ref = await getUserDocRef(uid);
    final doc = await ref.get();
    return doc.data() as Map<String, dynamic>? ?? {};
  }

  Future<void> updateUserProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');
    final ref = await getUserDocRef(uid);
    await ref.set(
      {'firstName': firstName, 'lastName': lastName, 'phoneNumber': phoneNumber},
      SetOptions(merge: true),
    );
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.updateDisplayName('$firstName $lastName'.trim());
  }

  Future<String> uploadProfilePicture(Uint8List fileBytes, String extension) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');
    final ref = FirebaseStorage.instance.ref().child('avatars').child('$uid.$extension');
    final task = await ref.putData(fileBytes, SettableMetadata(contentType: 'image/$extension'));
    final url = await task.ref.getDownloadURL();
    final userRef = await getUserDocRef(uid);
    await userRef.set({'photoUrl': url}, SetOptions(merge: true));
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.updatePhotoURL(url);
    return url;
  }

  // ─── Wallet ───────────────────────────────────────────────────────────────

  Stream<double> getWalletBalanceStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(0.0);
    return _walletService.getWalletStream(uid).map((w) => w?.balance ?? 0.0);
  }

  Future<void> addFunds(double amount) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');
    await _walletService.createWalletForUser(uid);

    final walletQuery = await FirebaseFirestore.instance
        .collection('wallets')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');

    final globalTxId = await _ids.generateId('transactions', prefixOverride: 'TOP');
    await _walletService.performTransaction(
      walletId: walletQuery.docs.first.id,
      amount: amount,
      type: WalletTransactionType.deposit,
      description: 'Wallet Top-Up',
      referenceId: globalTxId,
    );

    await FirebaseFirestore.instance.collection('transactions').doc(globalTxId).set({
      'type': 'deposit',
      'amount': amount,
      'userId': uid,
      'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
      'category': 'Wallet',
      'timestamp': FieldValue.serverTimestamp(),
      'details': 'เติมเงินเข้าวอลเล็ต (Top-Up)',
    });

    await _sendNotification(uid, 'เติมเงินเข้าวอลเล็ต',
        'เติมเงินเข้าวอลเล็ตสำเร็จ จำนวน ฿${NumberFormat('#,##0.00').format(amount)}', 'store');
  }

  Future<void> withdrawFunds(double amount) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    final walletQuery = await FirebaseFirestore.instance
        .collection('wallets')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');

    final globalTxId = await _ids.generateId('transactions', prefixOverride: 'WDL');
    await _walletService.performTransaction(
      walletId: walletQuery.docs.first.id,
      amount: amount,
      type: WalletTransactionType.withdrawal,
      description: 'Wallet Withdrawal',
      referenceId: globalTxId,
    );

    await FirebaseFirestore.instance.collection('transactions').doc(globalTxId).set({
      'type': 'withdrawal',
      'amount': amount,
      'userId': uid,
      'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
      'category': 'Wallet',
      'timestamp': FieldValue.serverTimestamp(),
      'details': 'ถอนเงินจากวอลเล็ต (Withdrawal)',
    });

    await _sendNotification(uid, 'ถอนเงินจากวอลเล็ต',
        'ถอนเงินจากวอลเล็ตสำเร็จ จำนวน ฿${NumberFormat('#,##0.00').format(amount)}', 'store');
  }

  // ─── Transaction history ──────────────────────────────────────────────────

  Stream<List<GoldTransaction>> getTransactionHistoryStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        // Note: orderBy is intentionally omitted here to avoid requiring a
        // composite Firestore index (userId + timestamp) that may not yet be
        // deployed. Results are sorted client-side below instead.
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final tA = (a.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
          final tB = (b.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
          return tB.compareTo(tA); // descending — newest first
        });
      return docs.map((doc) {
        final data = doc.data();
        // Map every known type string to its enum value. Previously
        // savings_physical_withdraw was missing, causing it to silently
        // appear as TransactionType.buy in the history screen.
        final TransactionType type;
        switch (data['type'] as String? ?? '') {
          case 'sell':     type = TransactionType.sell; break;
          case 'pawn':     type = TransactionType.pawn; break;
          case 'redeem':   type = TransactionType.redeem; break;
          case 'savings_deposit':          type = TransactionType.savings_deposit; break;
          case 'savings_withdraw':         type = TransactionType.savings_withdraw; break;
          case 'savings_physical_withdraw': type = TransactionType.savings_physical_withdraw; break;
          default:         type = TransactionType.buy;
        }
        return GoldTransaction(
          id: doc.id,
          assetId: data['assetId'] ?? '',
          type: type,
          amount: ((data['amount'] ?? 0) as num).toDouble(),
          weight: ((data['weight'] ?? 0) as num).toDouble(),
          purity: ((data['purity'] ?? 0.965) as num).toDouble(),
          laborFee: (data['laborFee'] as num?)?.toDouble(),
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          details: data['details'] ?? '',
          userId: data['userId'] ?? uid,
        );
      }).toList();
    });
  }

  /// Reads the pre-accumulated rewardPoints field on the user document.
  /// This is an O(1) read — the field is incremented via FieldValue.increment()
  /// inside createBuyTransaction, replacing the previous O(n) full-scan approach.
  Stream<int> getRewardPointsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);
    return Stream.fromFuture(getUserDocRef(uid)).asyncExpand((userRef) {
      return userRef.snapshots().map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return ((data?['rewardPoints'] ?? 0) as num).toInt();
      });
    });
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  Future<void> _sendNotification(
      String uid, String title, String message, String type) async {
    final userRef = await getUserDocRef(uid);
    final id = await _ids.generateId('notifications');
    final notif = NotificationItem(
      id: id, title: title, message: message, type: type,
      timestamp: DateTime.now(), isRead: false,
    );
    await userRef.collection('notifications').doc(id).set(notif.toMap());
  }
}
