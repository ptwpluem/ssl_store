// lib/pages/owner/owner_sell_transactions_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/date_formatters.dart';

class OwnerSellTransactionsPage extends StatelessWidget {
  final DateTimeRange? dateRange;

  const OwnerSellTransactionsPage({super.key, this.dateRange});

  @override
  Widget build(BuildContext context) {
    String title = 'รายการขาย (ลูกค้าขายให้ร้าน)';
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
            .where('type', isEqualTo: 'sell')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data?.docs ?? [];

          if (dateRange != null) {
            final startDay = DateTime(dateRange!.start.year, dateRange!.start.month, dateRange!.start.day);
            final endDay = DateTime(dateRange!.end.year, dateRange!.end.month, dateRange!.end.day, 23, 59, 59, 999);
            docs = docs.where((doc) {
              final ts = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              if (ts == null) return false;
              final d = ts.toDate();
              return !d.isBefore(startDay) && !d.isAfter(endDay);
            }).toList();
          }

          if (docs.isEmpty) {
            return const Center(child: Text('ไม่พบรายการรับซื้อ'));
          }

          final sortedDocs = docs.toList()
            ..sort((a, b) {
              final t1 = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final t2 = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              if (t1 == null || t2 == null) return 0;
              return t2.compareTo(t1);
            });

          // Totals for summary header
          double totalPaid  = 0;
          double totalWeight = 0;
          for (final doc in sortedDocs) {
            final d = doc.data() as Map<String, dynamic>;
            totalPaid   += (d['amount'] as num?)?.toDouble() ?? 0.0;
            totalWeight += (d['weight'] as num?)?.toDouble() ?? 0.0;
          }

          return Column(
            children: [
              _SellSummaryBar(
                totalPaid: totalPaid,
                totalWeight: totalWeight,
                count: sortedDocs.length,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final data = sortedDocs[index].data() as Map<String, dynamic>;
                    return _SellTransactionCard(data: data);
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

class _SellSummaryBar extends StatelessWidget {
  final double totalPaid;
  final double totalWeight;
  final int count;

  const _SellSummaryBar({
    required this.totalPaid,
    required this.totalWeight,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Container(
      color: const Color(0xFFC62828).withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _Cell(
            label: 'รายการ',
            value: '$count รายการ',
            color: Colors.grey[700]!,
          ),
          const SizedBox(width: 12),
          _Cell(
            label: 'ยอดจ่ายออกรวม',
            value: '฿${fmt.format(totalPaid)}',
            color: const Color(0xFFC62828),
            bold: true,
          ),
          const SizedBox(width: 12),
          _Cell(
            label: 'น้ำหนักรับซื้อรวม',
            value: '${totalWeight.toStringAsFixed(3)} บาท',
            color: Colors.amber[800]!,
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

class _SellTransactionCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SellTransactionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final fmtShort = NumberFormat('#,##0');

    final details   = data['details']   as String? ?? 'ไม่ทราบรายการ';
    final userEmail = data['userEmail'] as String? ?? 'ไม่ทราบผู้ใช้';
    final amount    = (data['amount']   as num?)?.toDouble() ?? 0.0; // paid to customer
    final weight    = (data['weight']   as num?)?.toDouble() ?? 0.0;
    final purity    = (data['purity']   as num?)?.toDouble() ?? 0.965;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    // From the shop's perspective: buying gold in.
    // 'cost' here = acquisitionPrice the customer originally paid (their cost basis).
    // 'profit' here = sellPrice – acquisitionPrice = customer's gain.
    // We display it as "ราคาที่ลูกค้าซื้อมา" so the owner can see the spread.
    final customerOriginalCost = (data['cost'] as num?)?.toDouble();
    final customerGain = (data['profit'] as num?)?.toDouble();

    final purityLabel = purity >= 0.999 ? '99.99%' : '96.5%';

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
              backgroundColor: const Color(0xFFC62828).withValues(alpha: 0.1),
              radius: 20,
              child: const Icon(Icons.storefront, color: Color(0xFFC62828), size: 20),
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

                  // Info pills
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Pill(
                        label: '${weight.toStringAsFixed(2)} บาท',
                        bg: Colors.amber.withValues(alpha: 0.1),
                        fg: Colors.amber[800]!,
                      ),
                      _Pill(
                        label: purityLabel,
                        bg: Colors.grey[200]!,
                        fg: Colors.grey[700]!,
                      ),
                      if (customerOriginalCost != null)
                        _Pill(
                          label: 'ซื้อมา ฿${fmtShort.format(customerOriginalCost)}',
                          bg: Colors.grey[100]!,
                          fg: Colors.grey[600]!,
                        ),
                      if (customerGain != null)
                        _Pill(
                          label: 'ลูกค้า${customerGain >= 0 ? 'กำไร' : 'ขาดทุน'} ฿${fmtShort.format(customerGain.abs())}',
                          bg: customerGain >= 0
                              ? Colors.green.withValues(alpha: 0.08)
                              : Colors.red.withValues(alpha: 0.08),
                          fg: customerGain >= 0 ? Colors.green[700]! : Colors.red[700]!,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount paid out
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '฿${fmt.format(amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFFC62828),
                  ),
                ),
                Text(
                  'ที่ร้านจ่าย',
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

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Pill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: fg)),
    );
  }
}
