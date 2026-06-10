import '../models/gold_asset.dart';

/// Pure valuation helpers for the member portfolio screen.
class PortfolioMath {
  PortfolioMath._();

  /// Total gold weight the member holds: every asset (owned + pawned) plus the
  /// gold sitting in their savings account.
  static double totalWeight(
    Iterable<GoldAsset> assets,
    double savingsWeight,
  ) =>
      assets.fold(0.0, (acc, a) => acc + a.weight) + savingsWeight;

  /// Total acquisition cost (cost basis) of the held assets.
  static double totalCost(Iterable<GoldAsset> assets) =>
      assets.fold(0.0, (acc, a) => acc + a.acquisitionPrice);

  /// Current market value of [weight] baht at the shop's [buyRate] (what the
  /// member could sell it back for).
  static double marketValue(double weight, double buyRate) => weight * buyRate;
}
