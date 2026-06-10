/// Business rules for the gold-savings screen.
///
/// Centralises the previously-inline magic numbers (the physical-withdrawal
/// premium and the quarter-baht withdrawal step) so they're named, testable,
/// and changed in one place.
class SavingsRules {
  SavingsRules._();

  /// Premium charged per baht of gold when converting savings into a physical
  /// gold bar (THB per baht).
  static const double premiumFeePerBaht = 300;

  /// Fee to withdraw [weight] baht of saved gold as a physical bar.
  static double physicalWithdrawalFee(double weight) =>
      weight * premiumFeePerBaht;

  /// Physical gold bars are issued in quarter-baht multiples, so only positive
  /// multiples of 0.25 may be withdrawn.
  static bool isWithdrawableWeight(double weight) =>
      weight > 0 && (weight * 4) % 1 == 0;
}
