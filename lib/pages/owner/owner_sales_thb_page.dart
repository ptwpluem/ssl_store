// lib/pages/owner/owner_sales_thb_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/date_formatters.dart';

class OwnerSalesThbPage extends StatelessWidget {
  final DateTimeRange? dateRange;

  const OwnerSalesThbPage({super.key, this.dateRange});

  @override
  Widget build(BuildContext context) {
    String title = 'รายการซื้อ (ลูกค้าซื้อจากร้าน)';
    if (dateRange != null) {
      final s = FormatterUtils.formatThaiDateShort(dateRange!.start);
      final e = FormatterUtils.formatThaiDateShort(dateRange!.end);
      title += ' ($s - $e)';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('type', isEqualTo: 'buy')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data?.docs ?? [];

          if (dateRange != null) {
            docs = docs.where((doc) {
              final ts = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              if (ts == null) return false;
              final d = ts.toDate();
              return d.isAfter(dateRange!.start) && d.isBefore(dateRange!.end);
            }).toList();
          }

          if (docs.isEmpty) {
            return const Center(child: Text('ไม่พบรายการซื้อ'));
          }

          final sortedDocs = docs.toList()
            ..sort((a, b) {
              final t1 = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final t2 = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              if (t1 == null || t2 == null) return 0;
              return t2.compareTo(t1);
            });

          // Compute totals for summary header
          double totalRevenue = 0, totalCost = 0, totalProfit = 0;
          for (final doc in sortedDocs) {
            final d = doc.data() as Map<String, dynamic>;
            totalRevenue += (d['amount'] as num?)?.toDouble() ?? 0.0;
            totalCost   += (d['cost']   as num?)?.toDouble() ?? 0.0;
            totalProfit += (d['profit'] as num?)?.toDouble() ?? 0.0;
          }

          return Column(
            children: [
              _SummaryBar(
                revenue: totalRevenue,
                cost: totalCost,
                profit: totalProfit,
                count: sortedDocs.length,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _BuyTransactionCard(data: data);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Summary bar ─────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final double revenue;
  final double cost;
  final double profit;
  final int count;

  const _SummaryBar({
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Container(
      color: const Color(0xFF1A237E).withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _SummaryCell(
            label: 'รายการ',
            value: '$count รายการ',
            color: Colors.grey[700]!,
          ),
          const SizedBox(width: 12),
          _SummaryCell(
            label: 'รายได้รวม',
            value: '฿${fmt.format(revenue)}',
            color: const Color(0xFF1A237E),
          ),
          const SizedBox(width: 12),
          _SummaryCell(
            label: 'ต้นทุนรวม',
            value: '฿${fmt.format(cost)}',
            color: Colors.grey[700]!,
          ),
          const SizedBox(width: 12),
          _SummaryCell(
            label: 'กำไรรวม',
            value: '฿${fmt.format(profit)}',
            color: profit >= 0 ? const Color(0xFF2E7D32) : Colors.red,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _SummaryCell({
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
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
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

// ─── Transaction card ─────────────────────────────────────────────────────────

class _BuyTransactionCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _BuyTransactionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final fmtShort = NumberFormat('#,##0');

    final details   = data['details']   as String? ?? 'ไม่ทราบรายการ';
    final userEmail = data['userEmail'] as String? ?? 'ไม่ทราบผู้ใช้';
    final amount    = (data['amount']   as num?)?.toDouble() ?? 0.0;
    final cost      = (data['cost']     as num?)?.toDouble() ?? 0.0;
    final profit    = (data['profit']   as num?)?.toDouble() ?? 0.0;
    final weight    = (data['weight']   as num?)?.toDouble();
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final costMethod = data['costMethod'] as String?;
    final isFifo = costMethod == 'fifo';

    final profitColor = profit >= 0 ? const Color(0xFF2E7D32) : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.12),
              radius: 20,
              child: const Icon(Icons.shopping_bag, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),

            // Main info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userEmail,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timestamp != null)
                    Text(
                      FormatterUtils.formatThaiDateShort(timestamp),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  const SizedBox(height: 6),

                  // Cost / profit row
                  Row(
                    children: [
                      _PillLabel(
                        label: 'ต้นทุน ฿${fmtShort.format(cost)}',
                        bg: Colors.grey[200]!,
                        fg: Colors.grey[700]!,
                      ),
                      const SizedBox(width: 6),
                      _PillLabel(
                        label: '${profit >= 0 ? '+' : ''}฿${fmtShort.format(profit)}',
                        bg: profitColor.withValues(alpha: 0.1),
                        fg: profitColor,
                        bold: true,
                      ),
                      if (isFifo) ...[
                        const SizedBox(width: 6),
                        _PillLabel(
                          label: 'FIFO',
                          bg: Colors.blue.withValues(alpha: 0.08),
                          fg: Colors.blue[700]!,
                        ),
                      ],
                      if (weight != null) ...[
                        const SizedBox(width: 6),
                        _PillLabel(
                          label: '${weight.toStringAsFixed(2)} บาท',
                          bg: Colors.amber.withValues(alpha: 0.1),
                          fg: Colors.amber[800]!,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount (revenue)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '฿${fmt.format(amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A237E),
                  ),
                ),
                Text(
                  'รายได้',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final bool bold;

  const _PillLabel({
    required this.label,
    required this.bg,
    required this.fg,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: fg,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
