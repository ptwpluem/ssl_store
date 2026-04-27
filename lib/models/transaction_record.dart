import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionRecord {
  final String id;
  final String userId;
  final String type; // 'buy', 'sell', 'pawn'
  final double amount; // Baht weight or Monetary value depending on context
  final double price; // The actual fiat value transacted
  final DateTime date;
  final String description;
  final double? cost;
  final double? profit;

  TransactionRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.price,
    required this.date,
    required this.description,
    this.cost,
    this.profit,
  });

  factory TransactionRecord.fromMap(String id, Map<String, dynamic> data) {
    return TransactionRecord(
      id: id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'unknown',
      amount: (data['amount'] ?? 0.0).toDouble(),
      price: (data['price'] ?? 0.0).toDouble(),
      date: _parseDate(data['date']),
      description: data['description'] ?? '',
      cost: (data['cost'] as num?)?.toDouble(),
      profit: (data['profit'] as num?)?.toDouble(),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'amount': amount,
      'price': price,
      'date': date.toIso8601String(),
      'description': description,
      'cost': cost,
      'profit': profit,
    };
  }
}
