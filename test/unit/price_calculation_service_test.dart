import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/services/price_calculation_service.dart';

/// Labor fee (ค่ากำเหน็จ) is part of every purchase price, so these tiers are
/// real money. Each `group` pins one category's tier boundaries; the boundary
/// cases (exactly on a `<=` edge) are the ones most likely to regress.
void main() {
  group('gold bar fees (uses strict `<`)', () {
    test('tiers', () {
      expect(PriceCalculationService.calculateLaborFee('Gold Bar', 0.25), 150.0);
      expect(PriceCalculationService.calculateLaborFee('Gold Bar', 0.5), 200.0);
      expect(PriceCalculationService.calculateLaborFee('Gold Bar', 1.0), 300.0);
      expect(PriceCalculationService.calculateLaborFee('Gold Bar', 4.99), 300.0);
      expect(PriceCalculationService.calculateLaborFee('Gold Bar', 5.0), 500.0);
      expect(PriceCalculationService.calculateLaborFee('Gold Bar', 10.0), 500.0);
    });

    test('boundaries are exclusive (`< 0.5` means 0.5 is the next tier)', () {
      // 0.499 still in the first tier, 0.5 crosses into the second.
      expect(PriceCalculationService.calculateLaborFee('Gold Bar', 0.499), 150.0);
      expect(PriceCalculationService.calculateLaborFee('Gold Bar', 0.5), 200.0);
    });

    test('matches Thai category แท่ง', () {
      expect(PriceCalculationService.calculateLaborFee('ทองคำแท่ง', 1.0), 300.0);
    });
  });

  group('ring fees (uses inclusive `<=`)', () {
    test('tiers', () {
      expect(PriceCalculationService.calculateLaborFee('Ring', 0.125), 500.0);
      expect(PriceCalculationService.calculateLaborFee('Ring', 0.25), 800.0);
      expect(PriceCalculationService.calculateLaborFee('Ring', 0.5), 1200.0);
      expect(PriceCalculationService.calculateLaborFee('Ring', 1.0), 2000.0);
    });

    test('above 1.0 baht scales by ceil(weight)', () {
      // 3500 * ceil(weight / 1.0)
      expect(PriceCalculationService.calculateLaborFee('Ring', 1.01), 7000.0); // ceil -> 2
      expect(PriceCalculationService.calculateLaborFee('Ring', 2.0), 7000.0); // ceil -> 2
      expect(PriceCalculationService.calculateLaborFee('Ring', 2.5), 10500.0); // ceil -> 3
    });

    test('matches Thai category แหวน', () {
      expect(PriceCalculationService.calculateLaborFee('แหวนทอง', 0.25), 800.0);
    });
  });

  group('earring fees', () {
    test('tiers', () {
      expect(PriceCalculationService.calculateLaborFee('Earring', 0.125), 800.0);
      expect(PriceCalculationService.calculateLaborFee('Earring', 0.25), 1200.0);
      expect(PriceCalculationService.calculateLaborFee('Earring', 0.5), 2000.0);
    });

    test(
      'earring is NOT misclassified as a ring (regression: "earring".contains("ring"))',
      () {
        // If the ring branch ran first, weight 0.5 would return the ring fee
        // (1200) instead of the earring fee (2000).
        expect(
          PriceCalculationService.calculateLaborFee('Earring', 0.5),
          2000.0,
          reason: 'earring at 0.5 baht must use the earring tier, not the ring tier',
        );
        expect(
          PriceCalculationService.calculateLaborFee('Diamond Earrings', 0.3),
          2000.0,
        );
      },
    );

    test('matches Thai category ต่างหู', () {
      expect(PriceCalculationService.calculateLaborFee('ต่างหู', 0.125), 800.0);
    });
  });

  group('necklace fees', () {
    test('tiers', () {
      expect(PriceCalculationService.calculateLaborFee('Necklace', 0.25), 1000.0);
      expect(PriceCalculationService.calculateLaborFee('Necklace', 0.5), 1500.0);
      expect(PriceCalculationService.calculateLaborFee('Necklace', 1.0), 2500.0);
      expect(PriceCalculationService.calculateLaborFee('Necklace', 2.0), 4500.0);
    });

    test('above 2.0 baht scales linearly (2500 per baht)', () {
      expect(PriceCalculationService.calculateLaborFee('Necklace', 3.0), 7500.0);
    });

    test('matches Thai category สร้อยคอ', () {
      expect(PriceCalculationService.calculateLaborFee('สร้อยคอ', 1.0), 2500.0);
    });
  });

  group('bracelet fees', () {
    test('tiers', () {
      expect(PriceCalculationService.calculateLaborFee('Bracelet', 0.25), 1200.0);
      expect(PriceCalculationService.calculateLaborFee('Bracelet', 0.5), 1800.0);
      expect(PriceCalculationService.calculateLaborFee('Bracelet', 1.0), 3000.0);
      expect(PriceCalculationService.calculateLaborFee('Bracelet', 2.0), 5000.0);
    });

    test('above 2.0 baht scales linearly (3000 per baht)', () {
      expect(PriceCalculationService.calculateLaborFee('Bracelet', 3.0), 9000.0);
    });

    test('matches Thai category ข้อมือ', () {
      expect(PriceCalculationService.calculateLaborFee('สร้อยข้อมือ', 0.5), 1800.0);
    });
  });

  group('general / fallback fees', () {
    test('unknown category uses the general formula (2000 per baht)', () {
      // weight >= 0.25 -> 2000 * weight
      expect(PriceCalculationService.calculateLaborFee('Pendant', 1.0), 2000.0);
      expect(PriceCalculationService.calculateLaborFee('Pendant', 2.0), 4000.0);
    });

    test('tiny unknown items are floored at half a baht equivalent', () {
      // weight < 0.25 -> 2000 * 0.5
      expect(PriceCalculationService.calculateLaborFee('Pendant', 0.1), 1000.0);
    });

    test('empty category falls through to general', () {
      expect(PriceCalculationService.calculateLaborFee('', 1.0), 2000.0);
    });
  });

  group('category matching is case-insensitive', () {
    test('upper/mixed case resolves the same as lower case', () {
      expect(
        PriceCalculationService.calculateLaborFee('GOLD BAR', 1.0),
        PriceCalculationService.calculateLaborFee('gold bar', 1.0),
      );
      expect(
        PriceCalculationService.calculateLaborFee('NeCkLaCe', 1.0),
        2500.0,
      );
    });
  });
}
