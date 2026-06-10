/// Pure stock-alert helpers for the owner dashboard.
///
/// Take the raw product document data and surface what needs attention —
/// no widgets, no Firestore — so the dashboard can render a restock banner.
class OwnerAlerts {
  OwnerAlerts._();

  /// Default "running low" cutoff (matches the low-stock badge on ProductCard).
  static const int defaultLowStockThreshold = 5;

  /// Products that are low but not yet out: 0 < stock <= [threshold], returned
  /// neediest-first (lowest stock at the top).
  static List<Map<String, dynamic>> lowStock(
    Iterable<Map<String, dynamic>> products, {
    int threshold = defaultLowStockThreshold,
  }) {
    int stockOf(Map<String, dynamic> p) => (p['stock'] as num?)?.toInt() ?? 0;
    final list = products.where((p) {
      final s = stockOf(p);
      return s > 0 && s <= threshold;
    }).toList();
    list.sort((a, b) => stockOf(a).compareTo(stockOf(b)));
    return list;
  }

  /// Products that are completely out of stock (stock <= 0).
  static List<Map<String, dynamic>> outOfStock(
    Iterable<Map<String, dynamic>> products,
  ) =>
      products
          .where((p) => ((p['stock'] as num?)?.toInt() ?? 0) <= 0)
          .toList();
}
