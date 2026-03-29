class GoldRate {
  final double buyPrice;
  final double sellPrice;
  final DateTime timestamp;
  final String trend;

  GoldRate({
    required this.buyPrice,
    required this.sellPrice,
    required this.timestamp,
    this.trend = 'stable',
  });
}
