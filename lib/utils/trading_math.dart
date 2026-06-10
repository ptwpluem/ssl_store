/// Pure helpers for the buy/sell trading screen.
///
/// In this shop, the customer **buys** gold at the shop's *sell* rate and
/// **sells** gold at the shop's *buy* rate — naming the two directions here
/// keeps that easy-to-flip convention in one tested place.
class TradingMath {
  TradingMath._();

  /// Gold bars trade in quarter-baht steps. Snaps a slider value to the
  /// nearest 0.25.
  static double snapWeight(double value) => (value * 4).round() / 4.0;

  /// Trims trailing zeros for display: 8.00 → "8", 6.50 → "6.5".
  static String formatWeight(double weight) {
    final s = weight.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }

  /// What the customer pays to buy [weight] baht of gold at the shop's
  /// [sellRate].
  static double buyCost(double weight, double sellRate) => weight * sellRate;

  /// What the customer receives for selling [weight] baht of gold at the
  /// shop's [buyRate].
  static double sellValue(double weight, double buyRate) => weight * buyRate;
}
