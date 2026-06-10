import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/utils/owner_alerts.dart';

void main() {
  Map<String, dynamic> p(String name, int stock) => {'name': name, 'stock': stock};

  group('lowStock', () {
    final products = [
      p('A', 0), // out — excluded
      p('B', 2),
      p('C', 5), // boundary — included
      p('D', 6), // above threshold — excluded
      p('E', 1),
    ];

    test('includes only 0 < stock <= threshold, neediest first', () {
      final low = OwnerAlerts.lowStock(products);
      expect(low.map((m) => m['name']), ['E', 'B', 'C']); // 1, 2, 5
    });

    test('respects a custom threshold', () {
      final low = OwnerAlerts.lowStock(products, threshold: 2);
      expect(low.map((m) => m['name']), ['E', 'B']);
    });

    test('missing stock field is treated as 0 (not low)', () {
      expect(OwnerAlerts.lowStock([{'name': 'X'}]), isEmpty);
    });
  });

  group('outOfStock', () {
    test('returns only products with no stock', () {
      final out = OwnerAlerts.outOfStock([p('A', 0), p('B', 3), {'name': 'C'}]);
      expect(out.map((m) => m['name']), containsAll(['A', 'C']));
      expect(out.map((m) => m['name']), isNot(contains('B')));
    });
  });
}
