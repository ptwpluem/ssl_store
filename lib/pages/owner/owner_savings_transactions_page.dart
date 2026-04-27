// lib/pages/owner/owner_savings_transactions_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/date_formatters.dart';

class OwnerSavingsTransactionsPage extends StatelessWidget {
  final DateTimeRange? dateRange;

  const OwnerSavingsTransactionsPage({super.key, this.dateRange});

  @override
  Widget build(BuildContext context) {
    String title = 'รายการออมทอง';
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
            .where('type', whereIn: [
              'savings_deposit',
              'savings_withdraw',
              'savings_physical_withdraw', // ← was missing before
            ])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data?.docs ?? [];

          if (dateRange != null) {
            docs = docs.where((doc) {
              final ts = (doc.data() as Map<String, dynamic>)['timestamp']
                  as Timestamp?;
              if (ts == null) return false;
              final d = ts.toDate();
              return d.isAfter(dateRange!.start) && d.isBefore(dateRange!.end);
            }).toList();
          }

          if (docs.isEmpty) {
            return const Center(child: Text('ไม่พบรายการออมทอง'));
          }

          final sortedDocs = docs.toList()
            ..sort((a, b) {
              final t1 = (a.data() as Map<String, dynamic>)['timestamp']
                  as Timestamp?;
              final t2 = (b.data() as Map<String, dynamic>)['timestamp']
                  as Timestamp?;
              if (t1 == null || t2 == null) return 0;
              return t2.compareTo(t1);
            });

          // Summary totals
          double totalDeposit = 0;
          double totalWithdraw = 0;
          double totalWeightIn = 0;
          double totalWeightOut = 0;
          int physicalWithdrawals = 0;

          for (final doc in sortedDocs) {
            final d = doc.data() as Map<String, dynamic>;
            final type = d['type'] as String? ?? '';
            final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
            final weight = (d['weight'] as num?)?.toDouble() ?? 0.0;

            if (type == 'savings_deposit') {
              totalDeposit += amount;
              totalWeightIn += weight;
            } else if (type == 'savings_withdraw') {
              totalWithdraw += amount;
              totalWeightOut += weight;
            } else if (type == 'savings_physical_withdraw') {
              physicalWithdrawals++;
              totalWeightOut += weight;
            }
          }

          return Column(
            children: [
              _SavingsSummaryBar(
                totalDeposit: totalDeposit,
                totalWithdraw: totalWithdraw,
                totalWeightIn: totalWeightIn,
                totalWeightOut: totalWeightOut,
                physicalWithdrawals: physicalWithdrawals,
                count: sortedDocs.length,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                        sortedDocs[index].data() as Map<String, dynamic>;
                    return _SavingsTransactionCard(data: data);
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

class _SavingsSummaryBar extends StatelessWidget {
  final double totalDeposit;
  final double totalWithdraw;
  final double totalWeightIn;
  final double totalWeightOut;
  final int physicalWithdrawals;
  final int count;

  const _SavingsSummaryBar({
    required this.totalDeposit,
    required this.totalWithdraw,
    required this.totalWeightIn,
    required this.totalWeightOut,
    required this.physicalWithdrawals,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Container(
      color: Colors.teal.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              _Cell(
                label: 'รายการทั้งหมด',
                value: '$count รายการ',
                color: Colors.grey[700]!,
              ),
              const SizedBox(width: 8),
              _Cell(
                label: 'ฝาก (THB)',
                value: '฿${fmt.format(totalDeposit)}',
                color: Colors.teal[700]!,
                bold: true,
              ),
              const SizedBox(width: 8),
              _Cell(
                label: 'ถอน/ขาย (THB)',
                value: '฿${fmt.format(totalWithdraw)}',
                color: Colors.orange[700]!,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Cell(
                label: 'ทองเข้า',
                value: '${totalWeightIn.toStringAsFixed(4)} บาท',
                color: Colors.teal[700]!,
              ),
              const SizedBox(width: 8),
              _Cell(
                label: 'ทองออก',
                value: '${totalWeightOut.toStringAsFixed(4)} บาท',
                color: Colors.orange[700]!,
              ),
              const SizedBox(width: 8),
              _Cell(
                label: 'ถอนแท่ง',
                value: physicalWithdrawals > 0
                    ? '$physicalWithdrawals รายการ'
                    : '-',
                color: physicalWithdrawals > 0
                    ? Colors.deepOrange
                    : Colors.grey[400]!,
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

// ─── Transaction card ─────────────────────────────────────────────────────────

class _SavingsTransactionCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SavingsTransactionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    final type = data['type'] as String? ?? '';
    final details = data['details'] as String? ?? 'รายการออมทอง';
    final userEmail = data['userEmail'] as String? ?? 'ไม่ทราบผู้ใช้';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final weight = (data['weight'] as num?)?.toDouble();
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    // Per-baht price at time of transaction (if recorded)
    final pricePerBaht = (data['buyPriceAtTransaction'] as num?)?.toDouble() ??
        (data['pricePerBaht'] as num?)?.toDouble();

    // Determine display config per type
    Color amountColor;
    Color bgColor;
    IconData icon;
    String typeLabel;

    switch (type) {
      case 'savings_deposit':
        amountColor = Colors.teal[700]!;
        bgColor = Colors.teal.withValues(alpha: 0.08);
        icon = Icons.add_circle_outline;
        typeLabel = 'ฝากออมทอง';
        break;
      case 'savings_withdraw':
        amountColor = Colors.orange[700]!;
        bgColor = Colors.orange.withValues(alpha: 0.08);
        icon = Icons.remove_circle_outline;
        typeLabel = 'ถอนออมทอง';
        break;
      case 'savings_physical_withdraw':
        amountColor = Colors.deepOrange;
        bgColor = Colors.deepOrange.withValues(alpha: 0.08);
        icon = Icons.inventory_2_outlined;
        typeLabel = 'ถอนแท่งทอง';
        break;
      default:
        amountColor = Colors.grey;
        bgColor = Colors.grey.withValues(alpha: 0.08);
        icon = Icons.swap_horiz;
        typeLabel = type;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: bgColor,
              child: Icon(icon, color: amountColor, size: 20),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                              fontSize: 10,
                              color: amountColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
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
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  const SizedBox(height: 6),

                  // Pill row — weight + price per baht
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (weight != null && weight > 0)
                        _Pill(
                          label: '${weight.toStringAsFixed(4)} บาท',
                          bg: Colors.amber.withValues(alpha: 0.1),
                          fg: Colors.amber[800]!,
                        ),
                      if (pricePerBaht != null)
                        _Pill(
                          label:
                              '฿${NumberFormat('#,##0').format(pricePerBaht)}/บาท',
                          bg: Colors.grey[100]!,
                          fg: Colors.grey[600]!,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            if (type != 'savings_physical_withdraw')
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '฿${fmt.format(amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: amountColor,
                    ),
                  ),
                  Text(
                    type == 'savings_deposit' ? 'เงินเข้า' : 'เงินออก',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              )
            else
              // Physical withdrawal — show weight as the key figure
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    weight != null
                        ? '${weight.toStringAsFixed(2)} บาท'
                        : '-',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: amountColor,
                    ),
                  ),
                  Text(
                    'ถอนแท่ง',
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
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, color: fg)),
    );
  }
}
