import 'package:cloud_firestore/cloud_firestore.dart';

class GoldSavingsAccount {
  final double totalWeightSaved;
  final double totalAmountInvested;
  final DateTime lastUpdated;

  GoldSavingsAccount({
    required this.totalWeightSaved,
    required this.totalAmountInvested,
    required this.lastUpdated,
  });

  factory GoldSavingsAccount.fromMap(Map<String, dynamic> data) {
    return GoldSavingsAccount(
      // Fix: parentheses around the null-coalescing expression before casting.
      // Without them, `as num` binds only to the literal 0.0, not the whole expression.
      totalWeightSaved: ((data['totalWeightSaved'] ?? 0.0) as num).toDouble(),
      totalAmountInvested: ((data['totalAmountInvested'] ?? 0.0) as num).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalWeightSaved': totalWeightSaved,
      'totalAmountInvested': totalAmountInvested,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}

class GoldSavingsTransaction {
  final String id;
  final double amountInvested;
  final double weightGained;
  final double buyPriceAtTransaction;
  final DateTime timestamp;

  GoldSavingsTransaction({
    required this.id,
    required this.amountInvested,
    required this.weightGained,
    required this.buyPriceAtTransaction,
    required this.timestamp,
  });

  factory GoldSavingsTransaction.fromMap(String documentId, Map<String, dynamic> data) {
    return GoldSavingsTransaction(
      id: documentId,
      amountInvested: ((data['amountInvested'] ?? 0.0) as num).toDouble(),
      weightGained: ((data['weightGained'] ?? 0.0) as num).toDouble(),
      buyPriceAtTransaction: ((data['buyPriceAtTransaction'] ?? 0.0) as num).toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amountInvested': amountInvested,
      'weightGained': weightGained,
      'buyPriceAtTransaction': buyPriceAtTransaction,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
