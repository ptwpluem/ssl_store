import 'package:cloud_firestore/cloud_firestore.dart';

class GoldSavingsAccount {
  // บัญชีสรุป
  final double totalWeightSaved; // น้ำหนักรวมที่ออมไว้ (บาท)
  final double totalAmountInvested; // เงินรวมที่ลงทุนไป (บาท)
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
      totalAmountInvested: ((data['totalAmountInvested'] ?? 0.0) as num)
          .toDouble(),
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
  // บัญชีแยกแต่ละรายการฝาก
  final String id; // transaction id
  final double amountInvested; // เงินที่ฝากครั้งนี้
  final double weightGained; // ทองที่ได้ครั้งนี้
  final double buyPriceAtTransaction; // ราคา ณ เวลาที่ฝาก
  final DateTime timestamp;

  GoldSavingsTransaction({
    required this.id,
    required this.amountInvested,
    required this.weightGained,
    required this.buyPriceAtTransaction,
    required this.timestamp,
  });

  factory GoldSavingsTransaction.fromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return GoldSavingsTransaction(
      id: documentId,
      amountInvested: ((data['amountInvested'] ?? 0.0) as num).toDouble(),
      weightGained: ((data['weightGained'] ?? 0.0) as num).toDouble(),
      buyPriceAtTransaction: ((data['buyPriceAtTransaction'] ?? 0.0) as num)
          .toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amountInvested': amountInvested,
      'weightGained':
          weightGained, // amountInvested / buyPriceAtTransaction = 1000 / 41000 = 0.0244 weight
      'buyPriceAtTransaction': buyPriceAtTransaction,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
