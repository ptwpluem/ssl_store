import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/date_formatters.dart';

class OwnerSavingsTransactionsPage extends StatelessWidget {
  final DateTimeRange? dateRange;

  const OwnerSavingsTransactionsPage({super.key, this.dateRange});

  @override
  Widget build(BuildContext context) {
    String title = 'รายรับรายจ่ายออมทอง';
    if (dateRange != null) {
      final startLabel = FormatterUtils.formatThaiDateShort(dateRange!.start);
      final endLabel = FormatterUtils.formatThaiDateShort(dateRange!.end);
      title += ' ($startLabel - $endLabel)';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('type', whereIn: ['savings_deposit', 'savings_withdraw'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data?.docs ?? [];

          if (dateRange != null) {
            docs = docs.where((doc) {
              final timestamp =
                  (doc.data() as Map<String, dynamic>)['timestamp']
                      as Timestamp?;
              if (timestamp == null) return false;
              final date = timestamp.toDate();
              return date.isAfter(dateRange!.start) &&
                  date.isBefore(dateRange!.end);
            }).toList();
          }

          if (docs.isEmpty) return const Center(child: Text('ไม่พบประวัติการทำรายการออมทอง'));

          final sortedDocs = docs.toList()
            ..sort((a, b) {
              final t1 =
                  (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final t2 =
                  (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              if (t1 == null || t2 == null) return 0;
              return t2.compareTo(t1);
            });

          final formatter = NumberFormat('#,##0.00');

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDocs.length,
            itemBuilder: (context, index) {
              final doc = sortedDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'] as String? ?? 'unknown';
              final details = data['details'] ?? 'รายการออมทอง';
              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final userEmail = data['userEmail'] ?? 'ไม่ทราบผู้ใช้';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

              Color amountColor = type == 'savings_deposit' ? Colors.teal : Colors.orange;
              IconData icon = type == 'savings_deposit' ? Icons.add_circle_outline : Icons.remove_circle_outline;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: amountColor.withOpacity(0.1),
                    child: Icon(icon, color: amountColor, size: 20),
                  ),
                  title: Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$userEmail\n${timestamp != null ? FormatterUtils.formatThaiDateShort(timestamp) : ''}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    '฿${formatter.format(amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: amountColor,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
