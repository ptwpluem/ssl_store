import 'package:flutter/material.dart';

/// Owner dashboard restock alert. Renders nothing when stock is healthy, or a
/// warning banner summarising out-of-stock + low-stock products otherwise.
///
/// Takes the already-computed lists (see `OwnerAlerts`) so it stays a pure,
/// testable renderer.
class LowStockBanner extends StatelessWidget {
  const LowStockBanner({
    super.key,
    required this.lowStock,
    required this.outOfStock,
  });

  final List<Map<String, dynamic>> lowStock;
  final List<Map<String, dynamic>> outOfStock;

  @override
  Widget build(BuildContext context) {
    if (lowStock.isEmpty && outOfStock.isEmpty) return const SizedBox.shrink();

    final parts = <String>[
      if (outOfStock.isNotEmpty) 'สินค้าหมด ${outOfStock.length} รายการ',
      if (lowStock.isNotEmpty) 'ใกล้หมด ${lowStock.length} รายการ',
    ];
    final names = [...outOfStock, ...lowStock]
        .take(3)
        .map((p) => (p['name'] as String?) ?? '-')
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parts.join(' • '),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ควรเติมสต็อก: $names',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
