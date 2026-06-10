/// Pure per-unit pricing math for the owner products table.
class ProductPricing {
  ProductPricing._();

  /// Retail price of one unit: weight × market sell rate + craftsmanship fee.
  static double unitSellPrice(double weight, double sellRate, double laborFee) =>
      (weight * sellRate) + laborFee;

  /// Profit on one unit vs. what the shop paid for it.
  static double marginPerUnit(double sellPrice, double costBasis) =>
      sellPrice - costBasis;

  /// Margin as a percentage of cost. Zero when cost basis is unknown (avoids
  /// divide-by-zero).
  static double marginPct(double marginPerUnit, double costBasis) =>
      costBasis > 0 ? (marginPerUnit / costBasis) * 100 : 0.0;

  /// Capital tied up in the current stock of one product.
  static double stockInvestment(int stock, double costBasis) =>
      stock * costBasis;
}
