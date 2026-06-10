import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/gold_asset.dart';

/// Pawn interest is the shop's revenue on loans, so the 1.25%/month accrual
/// formula is money-critical. `accruedInterest` reads `DateTime.now()` directly,
/// so each test sets `pawnDate` a fixed span in the past and adds a small buffer
/// (e.g. +1h) so `Duration.inDays` floors to the intended whole-day count
/// regardless of the millisecond the test runs.
void main() {
  GoldAsset pawned({
    required double loanAmount,
    required Duration ago,
    double? interestRate,
    String status = 'pawned',
  }) {
    final pawnDate = DateTime.now().subtract(ago);
    return GoldAsset(
      id: 'AST-1',
      name: 'สร้อยคอทองคำ',
      weight: 1.0,
      category: 'necklace',
      acquisitionDate: pawnDate,
      acquisitionPrice: 40000,
      status: status,
      loanAmount: loanAmount,
      pawnDate: pawnDate,
      dueDate: pawnDate.add(const Duration(days: 30)),
      interestRate: interestRate,
    );
  }

  group('accruedInterest', () {
    test('is zero when the asset is not pawned', () {
      final owned = GoldAsset(
        id: 'AST-1',
        name: 'แหวน',
        weight: 0.5,
        category: 'ring',
        acquisitionDate: DateTime.now(),
        acquisitionPrice: 20000,
        status: 'owned',
      );
      expect(owned.accruedInterest, 0.0);
    });

    test('is zero when pawnDate or loanAmount is missing', () {
      final noLoan = GoldAsset(
        id: 'AST-1',
        name: 'แหวน',
        weight: 0.5,
        category: 'ring',
        acquisitionDate: DateTime.now(),
        acquisitionPrice: 20000,
        status: 'pawned', // marked pawned but loan fields absent
      );
      expect(noLoan.accruedInterest, 0.0);
    });

    test('is zero on the day of pawning (elapsed days <= 0)', () {
      final today = pawned(loanAmount: 10000, ago: const Duration(hours: 1));
      expect(today.accruedInterest, 0.0);
    });

    test('accrues 1.25%/month at the default rate over 30 days', () {
      // dailyRate = 0.0125 / 30; interest = 10000 * dailyRate * 30 = 125.
      final asset = pawned(
        loanAmount: 10000,
        ago: const Duration(days: 30, hours: 1),
      );
      expect(asset.accruedInterest, closeTo(125.0, 0.001));
    });

    test('scales linearly with elapsed days', () {
      // 60 days at default rate = 2 * one month = 250.
      final asset = pawned(
        loanAmount: 10000,
        ago: const Duration(days: 60, hours: 1),
      );
      expect(asset.accruedInterest, closeTo(250.0, 0.001));
    });

    test('honours a custom interest rate', () {
      // 2%/month over 30 days on 10000 = 200.
      final asset = pawned(
        loanAmount: 10000,
        ago: const Duration(days: 30, hours: 1),
        interestRate: 0.02,
      );
      expect(asset.accruedInterest, closeTo(200.0, 0.001));
    });

    test('scales linearly with loan amount', () {
      final small = pawned(loanAmount: 10000, ago: const Duration(days: 30, hours: 1));
      final big = pawned(loanAmount: 50000, ago: const Duration(days: 30, hours: 1));
      expect(big.accruedInterest, closeTo(small.accruedInterest * 5, 0.001));
    });
  });

  group('totalRedemptionAmount', () {
    test('is principal plus accrued interest', () {
      final asset = pawned(
        loanAmount: 10000,
        ago: const Duration(days: 30, hours: 1),
      );
      expect(asset.totalRedemptionAmount, closeTo(10125.0, 0.001));
    });

    test('is zero principal when not pawned', () {
      final owned = GoldAsset(
        id: 'AST-1',
        name: 'แหวน',
        weight: 0.5,
        category: 'ring',
        acquisitionDate: DateTime.now(),
        acquisitionPrice: 20000,
        status: 'owned',
      );
      expect(owned.totalRedemptionAmount, 0.0);
    });
  });

  group('copyWith', () {
    final base = GoldAsset(
      id: 'AST-9',
      name: 'สร้อย',
      weight: 1.0,
      category: 'necklace',
      acquisitionDate: DateTime(2026, 1, 1),
      acquisitionPrice: 40000,
      status: 'owned',
      purity: 0.9999,
    );

    test('overrides only the named fields and preserves identity fields', () {
      final pawnDate = DateTime(2026, 6, 1);
      final updated = base.copyWith(
        status: 'pawned',
        loanAmount: 34000,
        pawnDate: pawnDate,
        dueDate: pawnDate.add(const Duration(days: 30)),
        interestRate: 0.0125,
      );
      expect(updated.id, 'AST-9');
      expect(updated.name, 'สร้อย');
      expect(updated.weight, 1.0);
      expect(updated.purity, 0.9999);
      expect(updated.status, 'pawned');
      expect(updated.loanAmount, 34000);
      expect(updated.pawnDate, pawnDate);
    });

    test('clearLoan nullifies every loan field even if values are passed', () {
      final loaned = base.copyWith(
        status: 'pawned',
        loanAmount: 34000,
        pawnDate: DateTime(2026, 6, 1),
        interestRate: 0.0125,
      );
      final redeemed = loaned.copyWith(status: 'owned', clearLoan: true);
      expect(redeemed.status, 'owned');
      expect(redeemed.loanAmount, isNull);
      expect(redeemed.pawnDate, isNull);
      expect(redeemed.dueDate, isNull);
      expect(redeemed.interestRate, isNull);
    });
  });
}
