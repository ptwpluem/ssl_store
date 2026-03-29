enum TransactionType { buy, sell, pawn, redeem, savings_deposit, savings_withdraw }

class GoldTransaction {
  final String id;
  final String assetId;
  final TransactionType type;
  final double amount; // THB
  final double weight; // Baht
  final double purity; // 0.965 or 0.9999
  final double? laborFee; // ค่ากำเหน็จ
  final DateTime timestamp;
  final String details;
  final String userId;

  GoldTransaction({
    required this.id,
    required this.assetId,
    required this.type,
    required this.amount,
    required this.weight,
    this.purity = 0.965,
    this.laborFee,
    required this.timestamp,
    required this.details,
    required this.userId,
  });
}
