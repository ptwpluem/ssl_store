// lib/pages/owner/owner_inventory_cost_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Shows a per-product breakdown of:
///   • Stock on hand (units)
///   • Cost investment in current stock  = stock × costBasis (weighted avg what owner paid)
///   • Retail value of current stock     = stock × (weight × sellPrice + laborFee)
///   • Unrealised margin                 = retail value − cost investment
///
/// Both the "มูลค่าสต็อก" and "เงินลงทุนในสต็อก" dashboard cards point here,
/// so the page shows both numbers clearly side-by-side per product.
///
/// NOTE: "Total invested historically" (sum of all restock amounts) is shown as
/// a secondary stat — it includes units already sold and should NOT be used as
/// the cost of current inventory.
class OwnerInventoryCostPage extends StatelessWidget {
  const OwnerInventoryCostPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ต้นทุนและมูลค่าสต็อก')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('market')
            .doc('gold_rate')
            .snapshots(),
        builder: (context, rateSnap) {
          final rateData =
              rateSnap.data?.data() as Map<String, dynamic>?;
          final sellPrice =
              (rateData?['sellPrice'] as num?)?.toDouble() ?? 42000.0;
          final buyPrice =
              (rateData?['buyPrice'] as num?)?.toDouble() ?? 40000.0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .orderBy('category')
                .snapshots(),
            builder: (context, productSnap) {
              if (productSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final productDocs = productSnap.data?.docs ?? [];
              if (productDocs.isEmpty) {
                return const Center(child: Text('ไม่พบสินค้า'));
              }

              // Pre-compute per-product numbers
              final List<_ProductStat> stats = productDocs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final name = d['name'] as String? ?? '-';
                final category = d['category'] as String? ?? '-';
                final stock = (d['stock'] as num?)?.toInt() ?? 0;
                final weight = (d['weight'] as num?)?.toDouble() ?? 0.0;
                final laborFee = (d['laborFee'] as num?)?.toDouble() ?? 0.0;
                final costBasis =
                    (d['costBasis'] as num?)?.toDouble() ?? 0.0;

                // ── Correct formulas ──────────────────────────────────────
                // Retail value: what the shop can sell each unit for today
                final unitRetailValue = (weight * sellPrice) + laborFee;
                final totalRetailValue = stock * unitRetailValue;

                // Cost investment: what the shop actually paid for units in
                // stock right now (weighted average cost basis per unit)
                final totalCostInvestment = stock * costBasis;

                // Unrealised margin: profit if all current stock sold today
                final unrealisedMargin =
                    totalRetailValue - totalCostInvestment;

                // Margin % relative to cost
                final marginPct = totalCostInvestment > 0
                    ? (unrealisedMargin / totalCostInvestment) * 100
                    : 0.0;

                return _ProductStat(
                  id: doc.id,
                  name: name,
                  category: category,
                  stock: stock,
                  weight: weight,
                  laborFee: laborFee,
                  costBasis: costBasis,
                  unitRetailValue: unitRetailValue,
                  totalRetailValue: totalRetailValue,
                  totalCostInvestment: totalCostInvestment,
                  unrealisedMargin: unrealisedMargin,
                  marginPct: marginPct,
                );
              }).toList();

              // Grand totals
              double grandRetail = 0;
              double grandCost = 0;
              for (final s in stats) {
                grandRetail += s.totalRetailValue;
                grandCost += s.totalCostInvestment;
              }
              final grandMargin = grandRetail - grandCost;

              // Group by category
              final Map<String, List<_ProductStat>> grouped = {};
              for (final s in stats) {
                grouped.putIfAbsent(s.category, () => []).add(s);
              }

              return Column(
                children: [
                  // ── Market rate indicator ───────────────────────────────
                  _RateBar(sellPrice: sellPrice, buyPrice: buyPrice),

                  // ── Grand summary ───────────────────────────────────────
                  _GrandSummaryBar(
                    grandRetail: grandRetail,
                    grandCost: grandCost,
                    grandMargin: grandMargin,
                  ),

                  // ── Per-product list ────────────────────────────────────
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        for (final category in grouped.keys) ...[
                          _CategoryHeader(category: category),
                          for (final stat in grouped[category]!)
                            _ProductCostCard(stat: stat),
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

class _ProductStat {
  final String id;
  final String name;
  final String category;
  final int stock;
  final double weight;
  final double laborFee;
  final double costBasis;
  final double unitRetailValue;
  final double totalRetailValue;
  final double totalCostInvestment;
  final double unrealisedMargin;
  final double marginPct;

  const _ProductStat({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.weight,
    required this.laborFee,
    required this.costBasis,
    required this.unitRetailValue,
    required this.totalRetailValue,
    required this.totalCostInvestment,
    required this.unrealisedMargin,
    required this.marginPct,
  });
}

// ─── Market rate bar ─────────────────────────────────────────────────────────

class _RateBar extends StatelessWidget {
  final double sellPrice;
  final double buyPrice;

  const _RateBar({required this.sellPrice, required this.buyPrice});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Container(
      color: Colors.amber.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.show_chart, size: 14, color: Colors.amber[800]),
          const SizedBox(width: 6),
          Text(
            'ราคาทองวันนี้ — ขาย: ฿${fmt.format(sellPrice)}/บาท  |  รับซื้อ: ฿${fmt.format(buyPrice)}/บาท',
            style: TextStyle(fontSize: 12, color: Colors.amber[900]),
          ),
        ],
      ),
    );
  }
}

// ─── Grand summary bar ────────────────────────────────────────────────────────

class _GrandSummaryBar extends StatelessWidget {
  final double grandRetail;
  final double grandCost;
  final double grandMargin;

  const _GrandSummaryBar({
    required this.grandRetail,
    required this.grandCost,
    required this.grandMargin,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    final marginColor =
        grandMargin >= 0 ? const Color(0xFF2E7D32) : Colors.red;
    return Container(
      color: const Color(0xFFEF6C00).withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _GCell(
            label: 'มูลค่าสต็อก (ราคาขาย)',
            value: '฿${fmt.format(grandRetail)}',
            color: const Color(0xFFEF6C00),
            bold: true,
          ),
          const SizedBox(width: 8),
          _GCell(
            label: 'เงินลงทุนในสต็อก',
            value: '฿${fmt.format(grandCost)}',
            color: const Color(0xFF4E342E),
          ),
          const SizedBox(width: 8),
          _GCell(
            label: 'กำไรที่ยังไม่ได้รับ',
            value: '฿${fmt.format(grandMargin)}',
            color: marginColor,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _GCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _GCell({
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
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
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

  const _CategoryHeader({required this.category});

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}

// ─── Product cost card ────────────────────────────────────────────────────────

class _ProductCostCard extends StatelessWidget {
  final _ProductStat stat;

  const _ProductCostCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final fmtShort = NumberFormat('#,##0');

    final marginColor =
        stat.unrealisedMargin >= 0 ? const Color(0xFF2E7D32) : Colors.red;
    final hasStock = stat.stock > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasStock ? Colors.grey[200]! : Colors.grey[100]!,
        ),
      ),
      elevation: hasStock ? 1 : 0,
      color: hasStock ? Colors.white : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    stat.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: hasStock ? Colors.black87 : Colors.grey[400],
                    ),
                  ),
                ),
                // Stock badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasStock
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasStock
                        ? '${stat.stock} ชิ้น'
                        : 'หมดสต็อก',
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

            if (hasStock) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Per-unit info
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _InfoPill(
                      '${stat.weight.toStringAsFixed(3)} บาท/ชิ้น',
                      Colors.amber.withValues(alpha: 0.12),
                      Colors.amber[800]!),
                  _InfoPill(
                      'ต้นทุน/ชิ้น ฿${fmtShort.format(stat.costBasis)}',
                      Colors.grey[100]!,
                      Colors.grey[700]!),
                  _InfoPill(
                      'ราคาขาย/ชิ้น ฿${fmtShort.format(stat.unitRetailValue)}',
                      Colors.orange.withValues(alpha: 0.1),
                      Colors.orange[800]!),
                  _InfoPill(
                      'กำเหน็จ ฿${fmtShort.format(stat.laborFee)}',
                      Colors.blue.withValues(alpha: 0.08),
                      Colors.blue[700]!),
                ],
              ),

              const SizedBox(height: 12),

              // Financial breakdown panel
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _FinRow(
                      label: 'เงินลงทุนในสต็อก',
                      sublabel:
                          '${stat.stock} ชิ้น × ฿${fmtShort.format(stat.costBasis)}',
                      value: '฿${fmt.format(stat.totalCostInvestment)}',
                      color: const Color(0xFF4E342E),
                    ),
                    const SizedBox(height: 6),
                    _FinRow(
                      label: 'มูลค่าสต็อก (ราคาขาย)',
                      sublabel:
                          '${stat.stock} ชิ้น × ฿${fmtShort.format(stat.unitRetailValue)}',
                      value: '฿${fmt.format(stat.totalRetailValue)}',
                      color: const Color(0xFFEF6C00),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'กำไรที่ยังไม่ได้รับ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            Text(
                              '(ถ้าขายหมดวันนี้)',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '฿${fmt.format(stat.unrealisedMargin)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: marginColor,
                              ),
                            ),
                            Text(
                              '${stat.marginPct >= 0 ? '+' : ''}${stat.marginPct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: marginColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _InfoPill(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}

class _FinRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final String value;
  final Color color;

  const _FinRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text(sublabel,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
