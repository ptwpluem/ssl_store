// lib/services/inventory_lot_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory_lot.dart';

/// Manages per-lot inventory cost tracking for owner-purchased stock.
///
/// Design: each product has a subcollection `inventory_lots` where every
/// owner restock creates one lot document. When a customer buys an item, the
/// service finds the oldest lot with stock remaining (FIFO) and deducts from
/// it inside the same Firestore transaction as the sale.
///
/// This ensures the profit on every sale is calculated against what the owner
/// *actually paid* for that specific unit — not the live market rate.
class InventoryLotService {
  static final InventoryLotService _instance = InventoryLotService._internal();
  factory InventoryLotService() => _instance;
  InventoryLotService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Subcollection reference helper ──────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _lotsRef(String productId) =>
      _db.collection('products').doc(productId).collection('inventory_lots');

  // ─── Read ─────────────────────────────────────────────────────────────────

  /// Live stream of all lots for a product, ordered oldest-first.
  Stream<List<InventoryLot>> getLotsByProduct(String productId) {
    return _lotsRef(productId)
        .orderBy('purchaseDate', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => InventoryLot.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Snapshot of active (non-exhausted) lots for a product, ordered FIFO.
  ///
  /// Filters remainingQuantity > 0 in Dart to avoid requiring a composite
  /// Firestore index (range filter + orderBy on different fields).
  Future<List<InventoryLot>> getActiveLots(String productId) async {
    final snap = await _lotsRef(productId)
        .orderBy('purchaseDate', descending: false)
        .get();
    return snap.docs
        .map((doc) => InventoryLot.fromMap(doc.id, doc.data()))
        .where((lot) => lot.remainingQuantity > 0)
        .toList();
  }

  /// Finds the oldest lot that still has stock (FIFO head).
  /// Returns null if no active lots exist.
  ///
  /// Orders by purchaseDate only (no composite index needed). The
  /// remainingQuantity > 0 guard is applied in Dart after the fetch.
  Future<InventoryLot?> getOldestActiveLot(String productId) async {
    final snap = await _lotsRef(productId)
        .orderBy('purchaseDate', descending: false)
        .get();
    final active = snap.docs
        .map((doc) => InventoryLot.fromMap(doc.id, doc.data()))
        .where((lot) => lot.remainingQuantity > 0)
        .toList();
    return active.isEmpty ? null : active.first;
  }

  // ─── Write ────────────────────────────────────────────────────────────────

  /// Creates a new inventory lot inside an existing Firestore [transaction].
  ///
  /// Called from [CatalogService.restockProduct] so the lot write is atomic
  /// with the stock increment and restock transaction document.
  void createLotWithTx({
    required Transaction transaction,
    required String lotId,
    required String productId,
    required String productName,
    required int quantity,
    required double unitCost,
    required String restockTransactionId,
    String? note,
  }) {
    final lotRef = _lotsRef(productId).doc(lotId);
    transaction.set(lotRef, {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'remainingQuantity': quantity,
      'unitCost': unitCost,
      'purchaseDate': FieldValue.serverTimestamp(),
      'restockTransactionId': restockTransactionId,
      if (note != null) 'note': note,
    });
  }

  /// Deducts [quantity] units from the oldest active lot (FIFO) within an
  /// existing Firestore [transaction].
  ///
  /// Must be called with a pre-fetched [lotRef] that was already identified
  /// via [getOldestActiveLot] **before** the transaction started, so that
  /// [tx.get()] can re-read and lock the document for atomicity.
  ///
  /// Returns the [unitCost] of the consumed lot (used to compute profit).
  ///
  /// Throws [Exception] if the lot is exhausted or doesn't exist.
  Future<double> consumeFromLotWithTx({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> lotRef,
    required int quantity,
  }) async {
    final lotDoc = await transaction.get(lotRef);
    if (!lotDoc.exists) {
      throw Exception('Inventory lot not found — please restock before selling.');
    }

    final data = lotDoc.data()!;
    final remaining = (data['remainingQuantity'] as num?)?.toInt() ?? 0;
    final unitCost = (data['unitCost'] as num?)?.toDouble() ?? 0.0;

    if (remaining < quantity) {
      throw Exception(
        'Lot has only $remaining unit(s) left but $quantity requested. '
        'Restock the product and try again.',
      );
    }

    transaction.update(lotRef, {
      'remainingQuantity': FieldValue.increment(-quantity),
    });

    return unitCost;
  }

  // ─── Summary helpers (for dashboard / inventory page) ────────────────────

  /// Total weighted-average cost basis across all active lots for a product.
  /// Useful for display purposes — the actual sale uses per-lot FIFO cost.
  Future<double> getWeightedAverageCost(String productId) async {
    final lots = await getActiveLots(productId);
    if (lots.isEmpty) return 0.0;
    double totalCost = 0.0;
    int totalUnits = 0;
    for (final lot in lots) {
      totalCost += lot.unitCost * lot.remainingQuantity;
      totalUnits += lot.remainingQuantity;
    }
    return totalUnits > 0 ? totalCost / totalUnits : 0.0;
  }

  /// Total units in stock across all active lots for a product.
  Future<int> getTotalRemainingUnits(String productId) async {
    final lots = await getActiveLots(productId);
    return lots.fold<int>(0, (acc, lot) => acc + lot.remainingQuantity);
  }

  /// Reference to a specific lot document — used by calling code to pass into
  /// [consumeFromLotWithTx] after a pre-fetch with [getOldestActiveLot].
  DocumentReference<Map<String, dynamic>> lotDocRef(
    String productId,
    String lotId,
  ) =>
      _lotsRef(productId).doc(lotId);
}
