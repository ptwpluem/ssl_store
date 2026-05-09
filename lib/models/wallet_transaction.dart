import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletTransactionType { deposit, withdrawal, purchase, sale }

class WalletTransaction {
  final String id;
  final double amount;
  final WalletTransactionType type;
  final double resultingBalance;
  final String? description;
  final String? referenceId; // orderId, etc.
  final DateTime timestamp;

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.resultingBalance,
    this.description,
    this.referenceId,
    required this.timestamp,
  });

  factory WalletTransaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WalletTransaction(
      id: doc.id,
      amount: (data['amount'] ?? 0.0).toDouble(),
      type: WalletTransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => WalletTransactionType.deposit,
      ),
      resultingBalance: (data['resultingBalance'] ?? 0.0)
          .toDouble(), // เก็บยอดคงเหลือหลังจากทำธุรกรรม
      description: data['description'],
      referenceId: data['referenceId'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'type': type.name,
      'resultingBalance': resultingBalance,
      'description': description,
      'referenceId': referenceId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
