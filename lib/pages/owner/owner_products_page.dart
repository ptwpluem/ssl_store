// lib/pages/owner/owner_products_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Owner catalog view — shows all products grouped by category.
///
/// Per product:
///   • Stock on hand
///   • Cost basis per unit (weighted average of owner's actual purchase price)
///   • Sell price per unit  = (weight × current market sell rate) + laborFee
///   • Margin per unit      = sell price − cost basis
///   • Total cost investment in current stock = stock × costBasis
///
/// Unlike OwnerInventoryCostPage (financial analysis), this page is for
/// catalog management — the owner can see all products including zero-stock
/// items and track cost basis changes over time.
class OwnerProductsPage extends StatelessWidget {
  const OwnerProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สินค้าในร้าน')),
      body: StreamBuilder<DocumentSnapshot>(
        // Fetch live market rate once at the top
        stream: FirebaseFirestore.instance
            .collection('market')
            .doc('gold_rate')
            .snapshots(),
        builder: (context, rateSnap) {
          final rateData =
              rateSnap.data?.data() as Map<String, dynamic>?;
          final sellRate =
              (rateData?['sellPrice'] as num?)?.toDouble() ?? 42000.0;

          return StreamBuilder<QuerySnapshot>(
            // Fetch all products ordered by category, then name
            stream: FirebaseFirestore.instance
                .collection('products')
                .orderBy('category')
                .snapshots(),
            builder: (context, productSnap) {
              if (productSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = productSnap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('ไม่พบสินค้า'));
              }

              // Build product stats
              final List<_ProductItem> items = docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final name = d['name'] as String? ?? '-';
                final category = d['category'] as String? ?? '-';
                final stock = (d['stock'] as num?)?.toInt() ?? 0;
                final weight = (d['weight'] as num?)?.toDouble() ?? 0.0;
                final laborFee =
                    (d['laborFee'] as num?)?.toDouble() ?? 0.0;
                final costBasis =
                    (d['costBasis'] as num?)?.toDouble() ?? 0.0;

                // Sell price = current market value + labor fee (craftsmanship)
                final sellPrice = (weight * sellRate) + laborFee;
                // Margin per unit
                final marginPerUnit = sellPrice - costBasis;
                final marginPct =
                    costBasis > 0 ? (marginPerUnit / costBasis) * 100 : 0.0;
                // Current stock investment
                final stockInvestment = stock * costBasis;

                return _ProductItem(
                  id: doc.id,
                  name: name,
                  category: category,
                  stock: stock,
                  weight: weight,
                  laborFee: laborFee,
                  costBasis: costBasis,
                  sellPrice: sellPrice,
                  marginPerUnit: marginPerUnit,
                  marginPct: marginPct,
                  stockInvestment: stockInvestment,
                );
              }).toList();

              // Grand totals
              int totalInStock = 0;
              double totalInvestment = 0;
              double totalRetailValue = 0;
              for (final item in items) {
                if (item.stock > 0) {
                  totalInStock++;
                  totalInvestment += item.stockInvestment;
                  totalRetailValue += item.stock * item.sellPrice;
                }
              }

              // Group by category
              final Map<String, List<_ProductItem>> grouped = {};
              for (final item in items) {
                grouped.putIfAbsent(item.category, () => []).add(item);
              }

              return Column(
                children: [
                  _SummaryBar(
                    productTypesWithStock: totalInStock,
                    totalProducts: items.length,
                    totalInvestment: totalInvestment,
                    totalRetailValue: totalRetailValue,
                    sellRate: sellRate,
                  ),
                  Expanded(
                    child: ListView(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        for (final category in grouped.keys) ...[
                          _CategoryHeader(
                            category: category,
                            items: grouped[category]!,
                          ),
                          for (final item in grouped[category]!)
                            _ProductCard(item: item),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _ProductItem {
  final String id;
  final String name;
  final String category;
  final int stock;
  final double weight;
  final double laborFee;
  final double costBasis;
  final double sellPrice;
  final double marginPerUnit;
  final double marginPct;
  final double stockInvestment;

  const _ProductItem({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.weight,
    required this.laborFee,
    required this.costBasis,
    required this.sellPrice,
    required this.marginPerUnit,
    required this.marginPct,
    required this.stockInvestment,
  });
}

// ─── Summary bar ─────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int productTypesWithStock;
  final int totalProducts;
  final double totalInvestment;
  final double totalRetailValue;
  final double sellRate;

  const _SummaryBar({
    required this.productTypesWithStock,
    required this.totalProducts,
    required this.totalInvestment,
    required this.totalRetailValue,
    required this.sellRate,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Container(
      color: const Color(0xFF2E7D32).withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              _Cell(
                label: 'ประเภทที่มีสต็อก',
                value: '$productTypesWithStock / $totalProducts ประเภท',
                color: Colors.grey[700]!,
              ),
              const SizedBox(width: 8),
              _Cell(
                label: 'ทุนในสต็อก',
                value: '฿${fmt.format(totalInvestment)}',
                color: const Color(0xFF4E342E),
                bold: true,
              ),
              const SizedBox(width: 8),
              _Cell(
                label: 'มูลค่าตามราคาขาย',
                value: '฿${fmt.format(totalRetailValue)}',
                color: const Color(0xFFEF6C00),
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.show_chart, size: 12, color: Colors.amber[700]),
              const SizedBox(width: 4),
              Text(
                'ราคาทองขาย: ฿${fmt.format(sellRate)}/บาท',
                style: TextStyle(fontSize: 11, color: Colors.amber[800]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _Cell({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Category header ──────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String category;
  final List<_ProductItem> items;

  const _CategoryHeader(
      {required this.category, required this.items});

  @override
  Widget build(BuildContext context) {
    final inStock = items.where((i) => i.stock > 0).length;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF800000),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            category,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF800000),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($inStock/${items.length} ประเภทมีสต็อก)',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ─── Product card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final _ProductItem item;

  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final fmtShort = NumberFormat('#,##0');
    final hasStock = item.stock > 0;
    final marginColor =
        item.marginPerUnit >= 0 ? const Color(0xFF2E7D32) : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasStock ? Colors.grey[200]! : Colors.grey[100]!,
        ),
      ),
      elevation: hasStock ? 1 : 0,
      color: hasStock ? Colors.white : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + stock badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: hasStock
                          ? Colors.black87
                          : Colors.grey[400],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasStock
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasStock ? '${item.stock} ชิ้น' : 'หมดสต็อก',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasStock
                          ? Colors.green[700]
                          : Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Info pills
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Pill(
                    '${item.weight.toStringAsFixed(3)} บาท/ชิ้น',
                    Colors.amber.withValues(alpha: 0.12),
                    Colors.amber[800]!),
                _Pill(
                    'กำเหน็จ ฿${fmtShort.format(item.laborFee)}',
                    Colors.blue.withValues(alpha: 0.08),
                    Colors.blue[700]!),
              ],
            ),

            const SizedBox(height: 10),

            // Price comparison: cost vs sell
            Row(
              children: [
                Expanded(
                  child: _PriceBox(
                    label: 'ต้นทุน/ชิ้น',
                    value: '฿${fmtShort.format(item.costBasis)}',
                    color: const Color(0xFF4E342E),
                    bg: Colors.brown.withValues(alpha: 0.06),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PriceBox(
                    label: 'ราคาขาย/ชิ้น',
                    value: '฿${fmtShort.format(item.sellPrice)}',
                    color: const Color(0xFFEF6C00),
                    bg: Colors.orange.withValues(alpha: 0.06),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PriceBox(
                    label:
                        'กำไร/ชิ้น (${item.marginPct >= 0 ? '+' : ''}${item.marginPct.toStringAsFixed(1)}%)',
                    value:
                        '${item.marginPerUnit >= 0 ? '+' : ''}฿${fmtShort.format(item.marginPerUnit)}',
                    color: marginColor,
                    bg: marginColor.withValues(alpha: 0.06),
                    bold: true,
                  ),
                ),
              ],
            ),

            // Stock investment total (only if in stock)
            if (hasStock) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'ทุนในสต็อก: ฿${fmt.format(item.stockInvestment)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final bool bold;

  const _PriceBox({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 9, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Pill(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}
