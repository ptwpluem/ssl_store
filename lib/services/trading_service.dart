import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/gold_asset.dart';
import '../models/gold_transaction.dart';
import '../models/notification_item.dart';
import '../models/wallet_transaction.dart';
import 'firestore_helper.dart';
import 'id_generator_service.dart';
import 'inventory_lot_service.dart';
import 'wallet_service.dart';

/// Handles buy and sell transactions and manages a user's asset portfolio.
class TradingService {
  static final TradingService _instance = TradingService._internal();
  factory TradingService() => _instance;
  TradingService._internal();

  final WalletService _walletService = WalletService();
  final IdGeneratorService _ids = IdGeneratorService();
  final InventoryLotService _lotService = InventoryLotService();

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
                    (data['acquisitionDate'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                acquisitionPrice: (data['acquisitionPrice'] ?? 0 as num)
                    .toDouble(),
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
  ///
  /// Cost resolution priority:
  ///   1. If [productId] is given → FIFO from the product's inventory_lots subcollection.
  ///      The profit reflects what the owner *actually paid* for that specific unit.
  ///   2. If no [productId] (raw gold bar trade without catalog product) → falls back
  ///      to the live market buy rate.
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

    // ── Resolve cost basis BEFORE the transaction ─────────────────────────
    // We must do async work (query + ID generation) outside runTransaction
    // because Firestore transactions cannot contain async gaps on their own.

    double totalCost;
    String? consumedLotId;
    DocumentReference<Map<String, dynamic>>? lotRef;

    if (productId != null) {
      // FIFO: find the oldest lot with stock available.
      final oldestLot = await _lotService.getOldestActiveLot(productId);
      if (oldestLot != null) {
        // Cost = per-unit acquisition cost × number of units purchased.
        totalCost = oldestLot.unitCost * quantity;
        consumedLotId = oldestLot.id;
        lotRef = _lotService.lotDocRef(productId, oldestLot.id);
      } else {
        // No lot records exist yet (pre-existing stock before this feature
        // was added). Gracefully fall back to live market rate.
        final rateDoc = await FirebaseFirestore.instance
            .collection('market')
            .doc('gold_rate')
            .get();
        final buyRate =
            (rateDoc.data()?['buyPrice'] as num?)?.toDouble() ?? 41000.0;
        totalCost = weight * buyRate;
      }
    } else {
      // No catalog product — raw gold trade. Use live market buy rate.
      final rateDoc = await FirebaseFirestore.instance
          .collection('market')
          .doc('gold_rate')
          .get();
      final buyRate =
          (rateDoc.data()?['buyPrice'] as num?)?.toDouble() ?? 41000.0;
      totalCost = weight * buyRate;
    }

    final profit = amount - totalCost;
    final notifId = await _ids.generateId('notifications');

    // Pre-generate one asset ID and one event ID per unit purchased.
    // IDs must be created outside runTransaction because async calls are not
    // permitted inside a Firestore transaction.
    final assetIds = <String>[];
    final assetEventIds = <String>[];
    for (int i = 0; i < quantity; i++) {
      assetIds.add(
        i == 0
            ? id
            : await _ids.generateId('transactions', prefixOverride: 'BUY'),
      );
      assetEventIds.add(await _ids.generateId('events'));
    }

    // ── Atomic Firestore transaction ──────────────────────────────────────
    final userRef = await getUserDocRef(uid);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final walletQuery = await FirebaseFirestore.instance
          .collection('wallets')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      if (walletQuery.docs.isEmpty) {
        throw Exception('Wallet not found. Please top up first.');
      }

      // ── ALL reads must happen before any writes (Firestore rule) ────────────
      // Read product doc.
      DocumentSnapshot? productDoc;
      if (productId != null) {
        productDoc = await tx.get(
          FirebaseFirestore.instance.collection('products').doc(productId),
        );
        if (productDoc.exists) {
          if ((productDoc.data() as Map<String, dynamic>)['stock'] <= 0) {
            throw Exception('Product is out of stock.');
          }
        } else {
          productDoc = null;
        }
      }

      // Pre-read wallet BEFORE any writes so we don't violate the
      // "all reads before writes" constraint when consumeFromLotWithTx
      // issues its tx.update(lotRef) write below.
      final walletId = walletQuery.docs.first.id;
      final walletRef = FirebaseFirestore.instance
          .collection('wallets')
          .doc(walletId);
      final preReadWalletSnapshot = await tx.get(walletRef);

      // ── Writes begin here ─────────────────────────────────────────────────
      // Deduct from FIFO lot (does tx.get + tx.update internally).
      if (lotRef != null) {
        await _lotService.consumeFromLotWithTx(
          transaction: tx,
          lotRef: lotRef!,
          quantity: quantity,
        );
      }

      await _walletService.performTransactionWithTx(
        transaction: tx,
        walletId: walletId,
        amount: amount,
        type: WalletTransactionType.purchase,
        description: 'Purchase: $assetName',
        referenceId: id,
        preReadWalletSnapshot: preReadWalletSnapshot,
      );

      if (productId != null && productDoc != null) {
        tx.update(productDoc.reference, {
          'stock': FieldValue.increment(-quantity),
        });
      }

      // ── Create one asset document per unit purchased ─────────────────────
      // Buying N units produces N individual portfolio entries, each with
      // per-unit weight and per-unit acquisition price, so the customer's
      // portfolio correctly shows N separate items they can sell individually.
      final unitWeight = weight / quantity;
      final unitPrice = amount / quantity;

      for (int i = 0; i < quantity; i++) {
        final assetRef = userRef.collection('assets').doc(assetIds[i]);
        tx.set(assetRef, {
          'name': assetName,
          'weight': unitWeight,
          'category': category ?? 'General',
          'acquisitionDate': FieldValue.serverTimestamp(),
          'acquisitionPrice': unitPrice,
          'status': 'owned',
          'purity': purity,
        });

        // ── Asset lifecycle event (immutable audit trail) ──────────────────
        // All per-unit events link back to the same purchase transaction ID.
        tx.set(assetRef.collection('events').doc(assetEventIds[i]), {
          'type': 'acquired',
          'timestamp': FieldValue.serverTimestamp(),
          'transactionId': id,
          'actorId': uid,
        });
      }

      // ── Reward points and lifetime buy total ─────────────────────────────
      tx.set(userRef, {
        'rewardPoints': FieldValue.increment(amount ~/ 1000),
        'totalBuyAmount': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      tx.set(FirebaseFirestore.instance.collection('transactions').doc(id), {
        // Primary asset ID (first unit); assetIds contains the full list when
        // quantity > 1, allowing reconciliation of every portfolio entry.
        'assetId': assetIds[0],
        if (quantity > 1) 'assetIds': assetIds,
        'type': TransactionType.buy.name,
        'amount': amount,
        'weight': weight,
        'quantity': quantity,
        'category': category ?? 'General',
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ซื้อ: $assetName (${weight / quantity} บาท x$quantity)',
        'cost': totalCost,
        'profit': profit,
        'purity': purity,
        'laborFee': laborFee,
        // Audit trail: which lot was consumed for this sale's cost basis.
        if (consumedLotId != null) 'lotId': consumedLotId,
        'costMethod': consumedLotId != null ? 'fifo' : 'market_rate',
        'userId': uid,
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      final unitWeightForNotif = weight / quantity;
      final unitLabel = quantity > 1
          ? '$quantity ชิ้น (${unitWeightForNotif.toStringAsFixed(2)} บาท/ชิ้น)'
          : '${unitWeightForNotif.toStringAsFixed(2)} บาท';
      tx.set(
        userRef.collection('notifications').doc(notifId),
        NotificationItem(
          id: notifId,
          title: 'ทำรายการสำเร็จ',
          message: 'ซื้อ $assetName $unitLabel สำเร็จแล้ว',
          type: 'store',
          timestamp: DateTime.now(),
          isRead: false,
        ).toMap(),
      );
    });
  }

  // ─── Sell transaction ─────────────────────────────────────────────────────

  Future<void> sellAsset({
    required GoldAsset asset,
    required double sellPrice,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('User not logged in');

    final id = await _ids.generateId('transactions', prefixOverride: 'SEL');
    final displayName = await _getDisplayName(uid);

    final userRef = await getUserDocRef(uid);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final walletQuery = await FirebaseFirestore.instance
          .collection('wallets')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');

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
        'assetId': asset.id,
        'type': TransactionType.sell.name,
        'amount': sellPrice,
        'weight': asset.weight,
        'category': asset.category,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'ขาย: ${asset.name} (${asset.weight} บาท)',
        'cost': asset.acquisitionPrice,
        'profit': profit,
        'purity': asset.purity,
        'userId': uid,
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'userDisplayName': displayName,
      });

      final notifId = await _ids.generateId('notifications');
      final fmt = NumberFormat('#,##0.00');
      tx.set(
        userRef.collection('notifications').doc(notifId),
        NotificationItem(
          id: notifId,
          title: 'ขายสินทรัพย์สำเร็จ',
          message:
              'ขาย ${asset.name} สำเร็จแล้ว เป็นเงิน ฿${fmt.format(sellPrice)}',
          type: 'store',
          timestamp: DateTime.now(),
          isRead: false,
        ).toMap(),
      );
    });
  }

  // ─── Data repair (called once per UID per session) ───────────────────────
  // A bool flag on the singleton would never reset when a different user logs
  // in within the same app session. Tracking the last repaired UID ensures
  // repairs always run for a newly authenticated user.

  String? _lastRepairedUid;

  Future<void> _runRepairs() async {
    final uid = _uid;
    if (uid == null) return;
    if (_lastRepairedUid == uid) return; // already repaired for this user
    _lastRepairedUid = uid;
    await _cleanupPhantomPawnAssets(); // Must run before repair to avoid false-negatives
    await _repairMissingPawnAssets();
    await repairAllTransactions();
  }

  Future<void> repairAllTransactions() async {
    final rateDoc = await FirebaseFirestore.instance
        .collection('market')
        .doc('gold_rate')
        .get();
    final buyRate =
        (rateDoc.data()?['buyPrice'] as num?)?.toDouble() ?? 41000.0;

    final buyTxQuery = await FirebaseFirestore.instance
        .collection('transactions')
        .where('type', isEqualTo: 'buy')
        .get();
    var batch = FirebaseFirestore.instance.batch();
    bool needed = false;
    for (var doc in buyTxQuery.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final cost = (data['cost'] as num?)?.toDouble();
      final profit = (data['profit'] as num?)?.toDouble();

      // Skip transactions that already have a valid cost/profit pair,
      // INCLUDING those resolved via FIFO lot cost (costMethod == 'fifo').
      // Only repair truly missing or corrupted legacy records.
      final costMethod = data['costMethod'] as String?;
      if (costMethod == 'fifo')
        continue; // FIFO cost is authoritative — never overwrite.

      if (cost == null ||
          profit == null ||
          (amount - (cost + profit)).abs() > 1.0) {
        double weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
        if (weight <= 0 && amount > 0) weight = amount / (buyRate * 1.04);
        batch.update(doc.reference, {
          'cost': weight * buyRate,
          'profit': amount - (weight * buyRate),
          'weight': weight,
          'costMethod': 'market_rate_repair',
        });
        needed = true;
      }
    }
    if (needed) {
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      needed = false;
    }

    final redeemQuery = await FirebaseFirestore.instance
        .collection('transactions')
        .where('type', isEqualTo: 'redeem')
        .get();
    for (var doc in redeemQuery.docs) {
      final data = doc.data();
      if (data['profit'] == null || data['interestPaid'] == null) {
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        double principal = (data['principal'] as num?)?.toDouble() ?? 0.0;
        if (principal <= 0) principal = amount * 0.98;
        batch.update(doc.reference, {
          'principal': principal,
          'interestPaid': amount - principal,
          'profit': amount - principal,
        });
        needed = true;
      }
    }
    if (needed) await batch.commit();
  }

  Future<void> _repairMissingPawnAssets() async {
    final uid = _uid;
    if (uid == null) return;

    final query = await FirebaseFirestore.instance
        .collection('transactions')
        .where('type', isEqualTo: 'pawn')
        .where('userId', isEqualTo: uid)
        .get();
    if (query.docs.isEmpty) return;

    final userRef = await getUserDocRef(uid);
    final batch = FirebaseFirestore.instance.batch();
    bool needed = false;

    for (var txDoc in query.docs) {
      final data = txDoc.data();

      // Check if a REAL asset already exists that references this pawn transaction
      // via the loanId field (set by pawnAsset() in PawnService).
      // Using loanId — not a derived document ID — prevents creating phantom
      // duplicates that inflate portfolio value with artificially low acquisitionPrice.
      final existingByLoanId = await userRef
          .collection('assets')
          .where('loanId', isEqualTo: txDoc.id)
          .limit(1)
          .get();
      if (existingByLoanId.docs.isNotEmpty)
        continue; // Real asset exists — skip.

      // Also check the legacy a{digits} pattern in case a prior repair ran.
      final txId = txDoc.id.replaceAll(RegExp(r'[^0-9]'), '');
      final legacyAssetDoc = await userRef
          .collection('assets')
          .doc('a$txId')
          .get();
      if (legacyAssetDoc.exists)
        continue; // Legacy phantom exists — skip creation.

      // Truly missing: create a repair asset.
      // acquisitionPrice uses goldValue (weight × pricePerBaht from the transaction),
      // NOT loanAmount, so P&L reflects real cost basis, not the borrowed sum.
      final ts = (data['timestamp'] as Timestamp?) ?? Timestamp.now();
      final weight = (data['weight'] as num?)?.toDouble() ?? 1.0;
      final loanAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      // Derive cost basis from pricePerBaht stored on the transaction if available,
      // else fall back to loan amount / 0.85 (reversing the 85% LTV ratio).
      final pricePerBaht = (data['pricePerBaht'] as num?)?.toDouble();
      final acquisitionPrice = pricePerBaht != null
          ? weight * pricePerBaht
          : loanAmount / 0.85;

      final assetRef = userRef.collection('assets').doc('a$txId');
      batch.set(assetRef, {
        'name':
            data['details']?.toString().split(':').last.trim() ?? 'Pawned Item',
        'weight': weight,
        'category': 'General',
        'acquisitionDate': ts,
        'acquisitionPrice': acquisitionPrice,
        'status': 'pawned',
        'loanAmount': loanAmount,
        'loanId': txDoc.id,
        'pawnDate': ts,
        'dueDate': Timestamp.fromDate(
          ts.toDate().add(const Duration(days: 30)),
        ),
      });
      needed = true;
    }
    if (needed) await batch.commit();
  }

  /// Removes phantom pawn-asset documents that were incorrectly written to the
  /// current user's assets subcollection by the old global repair function.
  ///
  /// A phantom asset has the ID pattern `a{digits}` (e.g. a000004, a1772512076877)
  /// and has no corresponding pawn transaction owned by this user.
  Future<void> _cleanupPhantomPawnAssets() async {
    final uid = _uid;
    if (uid == null) return;

    final userRef = await getUserDocRef(uid);

    final ownPawnSnap = await FirebaseFirestore.instance
        .collection('transactions')
        .where('type', isEqualTo: 'pawn')
        .where('userId', isEqualTo: uid)
        .get();

    // Map of loanId → pawn tx, used to detect duplicates below.
    final pawnTxIds = ownPawnSnap.docs.map((tx) => tx.id).toSet();
    final validSuffixes = ownPawnSnap.docs
        .map((tx) => tx.id.replaceAll(RegExp(r'[^0-9]'), ''))
        .toSet();

    final assetsSnap = await userRef.collection('assets').get();
    final batch = FirebaseFirestore.instance.batch();
    bool needed = false;

    for (var assetDoc in assetsSnap.docs) {
      if (!RegExp(r'^a\d+$').hasMatch(assetDoc.id)) continue;

      final suffix = assetDoc.id.substring(1);

      // Case 1: suffix doesn't match any pawn transaction at all → orphan, delete.
      if (!validSuffixes.contains(suffix)) {
        batch.delete(assetDoc.reference);
        needed = true;
        continue;
      }

      // Case 2: suffix matches a pawn transaction, but a REAL asset with the same
      // loanId also exists (created by pawnAsset()). This is the phantom duplicate
      // that inflates P&L. Delete the phantom; keep the real one.
      final loanId = ownPawnSnap.docs
          .firstWhere(
            (tx) => tx.id.replaceAll(RegExp(r'[^0-9]'), '') == suffix,
            orElse: () => ownPawnSnap.docs.first,
          )
          .id;
      if (!pawnTxIds.contains(loanId)) continue;

      final realAssetQuery = await userRef
          .collection('assets')
          .where('loanId', isEqualTo: loanId)
          .limit(2)
          .get();

      // If more than one asset has this loanId (the real one + this phantom), delete phantom.
      final hasRealAsset = realAssetQuery.docs.any(
        (doc) => doc.id != assetDoc.id,
      );
      if (hasRealAsset) {
        batch.delete(assetDoc.reference);
        needed = true;
      }
    }

    if (needed) await batch.commit();
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
