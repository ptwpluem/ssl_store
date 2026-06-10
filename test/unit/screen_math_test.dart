import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/gold_asset.dart';
import 'package:ssl_store/utils/portfolio_math.dart';
import 'package:ssl_store/utils/product_pricing.dart';
import 'package:ssl_store/utils/savings_rules.dart';
import 'package:ssl_store/utils/trading_math.dart';

/// Pure math extracted out of the four large screens in Milestone D. Pinning it
/// here means the screens are now thin renderers over tested logic.
void main() {
  group('TradingMath', () {
    test('snapWeight rounds to the nearest 0.25', () {
      expect(TradingMath.snapWeight(0.6), 0.5);
      expect(TradingMath.snapWeight(0.62), 0.5);
      expect(TradingMath.snapWeight(0.63), 0.75);
      expect(TradingMath.snapWeight(7.9999999999), 8.0);
      expect(TradingMath.snapWeight(1.0), 1.0);
    });

    test('formatWeight trims trailing zeros', () {
      expect(TradingMath.formatWeight(8.0), '8');
      expect(TradingMath.formatWeight(6.5), '6.5');
      expect(TradingMath.formatWeight(0.25), '0.25');
    });

    test('buyCost / sellValue apply the right rate direction', () {
      expect(TradingMath.buyCost(2.0, 41000), 82000.0);
      expect(TradingMath.sellValue(2.0, 40000), 80000.0);
    });
  });

  group('SavingsRules', () {
    test('physical withdrawal fee is 300 THB per baht', () {
      expect(SavingsRules.physicalWithdrawalFee(1.0), 300.0);
      expect(SavingsRules.physicalWithdrawalFee(2.5), 750.0);
    });

    test('only positive multiples of 0.25 are withdrawable', () {
      expect(SavingsRules.isWithdrawableWeight(0.25), isTrue);
      expect(SavingsRules.isWithdrawableWeight(2.0), isTrue);
      expect(SavingsRules.isWithdrawableWeight(0.3), isFalse);
      expect(SavingsRules.isWithdrawableWeight(0), isFalse);
      expect(SavingsRules.isWithdrawableWeight(-0.25), isFalse);
    });
  });

  group('PortfolioMath', () {
    GoldAsset asset(double weight, double cost) => GoldAsset(
          id: 'x',
          name: 'x',
          weight: weight,
          category: 'ring',
          acquisitionDate: DateTime(2026, 1, 1),
          acquisitionPrice: cost,
        );

    test('totalWeight adds asset weights plus saved gold', () {
      expect(
        PortfolioMath.totalWeight([asset(1.0, 0), asset(0.5, 0)], 0.25),
        closeTo(1.75, 1e-9),
      );
    });

    test('totalCost sums acquisition prices', () {
      expect(
        PortfolioMath.totalCost([asset(1, 40000), asset(1, 19000)]),
        59000.0,
      );
    });

    test('marketValue values weight at the buy rate; empties are zero', () {
      expect(PortfolioMath.marketValue(2.0, 40000), 80000.0);
      expect(PortfolioMath.totalWeight([], 0), 0.0);
      expect(PortfolioMath.totalCost([]), 0.0);
    });
  });

  group('ProductPricing', () {
    test('unitSellPrice = weight*sellRate + laborFee', () {
      expect(ProductPricing.unitSellPrice(1.0, 40000, 500), 40500.0);
    });

    test('marginPerUnit = sellPrice - costBasis', () {
      expect(ProductPricing.marginPerUnit(40500, 38000), 2500.0);
    });

    test('marginPct is margin over cost, and 0 when cost is unknown', () {
      expect(ProductPricing.marginPct(2000, 40000), closeTo(5.0, 1e-9));
      expect(ProductPricing.marginPct(2000, 0), 0.0);
    });

    test('stockInvestment = stock * costBasis', () {
      expect(ProductPricing.stockInvestment(3, 38000), 114000.0);
    });
  });
}
