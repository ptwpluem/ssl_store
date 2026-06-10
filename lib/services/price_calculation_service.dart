class PriceCalculationService {
  /// Calculates the Labor Fee (ค่ากำเหน็จ) based on category and weight.
  /// Weights are in Baht.
  static double calculateLaborFee(String category, double weight) {
    // Normalize category for lookup
    final normalizedCategory = category.toLowerCase();

    if (normalizedCategory.contains('bar') || normalizedCategory.contains('แท่ง')) {
      return _calculateGoldBarFee(weight);
    } else if (normalizedCategory.contains('earring') || normalizedCategory.contains('ต่างหู')) {
      // NOTE: earring MUST be checked before ring — 'earring'.contains('ring')
      // is true, so the ring branch would otherwise swallow every earring.
      return _calculateEarringFee(weight);
    } else if (normalizedCategory.contains('ring') || normalizedCategory.contains('แหวน')) {
      return _calculateRingFee(weight);
    } else if (normalizedCategory.contains('necklace') || normalizedCategory.contains('necklet') || normalizedCategory.contains('สร้อยคอ')) {
      return _calculateNecklaceFee(weight);
    } else if (normalizedCategory.contains('bracelet') || normalizedCategory.contains('ข้อมือ')) {
      return _calculateBraceletFee(weight);
    }

    // Default fallback for general jewelry
    return _calculateGeneralJewelryFee(weight);
  }

  static double _calculateGoldBarFee(double weight) {
    if (weight < 0.5) return 150.0;
    if (weight < 1.0) return 200.0;
    if (weight < 5.0) return 300.0;
    return 500.0; // Large bars have standard low fees
  }

  static double _calculateRingFee(double weight) {
    if (weight <= 0.125) return 500.0; // 0.5 Salueng (ครึ่งสลึง)
    if (weight <= 0.25) return 800.0;  // 1 Salueng (หนึ่งสลึง)
    if (weight <= 0.5) return 1200.0;
    if (weight <= 1.0) return 2000.0;
    return 3500.0 * (weight / 1.0).ceil(); // Scales for larger rings
  }

  static double _calculateNecklaceFee(double weight) {
    if (weight <= 0.25) return 1000.0;
    if (weight <= 0.5) return 1500.0;
    if (weight <= 1.0) return 2500.0;
    if (weight <= 2.0) return 4500.0;
    return 2500.0 * weight; // approx 2500 per baht for large pieces
  }

  static double _calculateBraceletFee(double weight) {
    if (weight <= 0.25) return 1200.0;
    if (weight <= 0.5) return 1800.0;
    if (weight <= 1.0) return 3000.0;
    if (weight <= 2.0) return 5000.0;
    return 3000.0 * weight;
  }

  static double _calculateEarringFee(double weight) {
    if (weight <= 0.125) return 800.0;
    if (weight <= 0.25) return 1200.0;
    return 2000.0; // Earrings rarely exceed 0.5 baht
  }

  static double _calculateGeneralJewelryFee(double weight) {
    // Standard baseline for other categories (approx 2000 per Baht)
    return 2000.0 * (weight < 0.25 ? 0.5 : weight);
  }
}