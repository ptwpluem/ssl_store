// lib/models/inventory_lot.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryLot {
  // เก็บค่าพวกนี้เพราะจะได้ทำ Stock FIFO
  final String id;
  final String productId;
  final String productName;
  final int quantity; // จำนวนที่ซื้อมา
  final int remainingQuantity; // จำนวนที่เหลือ
  final double unitCost; // ต้นทุนต่อ 1 ชิ้น totalCost / quantity
  final DateTime purchaseDate; // วันที่ซื้อ
  /// Links back to the 'restock' transaction document for audit purposes.
  final String restockTransactionId;
  final String? note; // optional note

  const InventoryLot({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.remainingQuantity,
    required this.unitCost,
    required this.purchaseDate,
    required this.restockTransactionId,
    this.note,
  });

  factory InventoryLot.fromMap(String id, Map<String, dynamic> data) {
    return InventoryLot(
      id: id,
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      remainingQuantity: (data['remainingQuantity'] as num?)?.toInt() ?? 0,
      unitCost: (data['unitCost'] as num?)?.toDouble() ?? 0.0,
      purchaseDate: _parseTimestamp(data['purchaseDate']),
      restockTransactionId: data['restockTransactionId'] as String? ?? '',
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'remainingQuantity': remainingQuantity,
      'unitCost': unitCost,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'restockTransactionId': restockTransactionId,
      if (note != null) 'note': note,
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  InventoryLot copyWith({int? remainingQuantity}) {
    return InventoryLot(
      id: id,
      productId: productId,
      productName: productName,
      quantity: quantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      unitCost: unitCost,
      purchaseDate: purchaseDate,
      restockTransactionId: restockTransactionId,
      note: note,
    );
  }

  /// True when this lot has been fully consumed.
  bool get isExhausted => remainingQuantity <= 0;

  /// Percentage of original stock still available.
  double get remainingRatio =>
      quantity > 0 ? remainingQuantity / quantity : 0.0;
}
