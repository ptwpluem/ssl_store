class GoldRate {
  final double buyPrice; // ราคาที่ร้านซื้อจากลูกค้า
  final double sellPrice; // ราคาที่ร้านขายให้กับลูกค้า
  final DateTime timestamp;
  final String trend; // up, down, stable

  GoldRate({
    required this.buyPrice,
    required this.sellPrice,
    required this.timestamp,
    this.trend = 'stable',
  });
}
