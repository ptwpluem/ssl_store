// ignore_for_file: constant_identifier_names
// The savings_* values are persisted as literal Firestore strings in the
// `transactions` collection and matched across the owner/ledger pages.
// Renaming them to lowerCamelCase would desync existing stored data — keep
// snake_case intentionally.
enum TransactionType {
  buy,
  sell,
  pawn,
  redeem,
  savings_deposit,
  savings_withdraw,
  savings_physical_withdraw,
}
// กำหนดค่าที่เป็นไปได้ล่วงหน้า ทำให้ไม่สามารถพิมพ์ผิดเป็น buyyy ได้

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
