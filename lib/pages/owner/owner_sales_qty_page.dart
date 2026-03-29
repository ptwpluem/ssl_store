import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/date_formatters.dart';

class OwnerSalesQtyPage extends StatelessWidget {
  final DateTimeRange? dateRange;

  const OwnerSalesQtyPage({super.key, this.dateRange});

  @override
  Widget build(BuildContext context) {
    String title = 'ยอดขายรวม (จำนวน)';
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
            .where('type', isEqualTo: 'buy')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

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

          if (docs.isEmpty) return const Center(child: Text('ไม่พบข้อมูลการขาย'));

          // Sort descending locally to bypass composite index issues
          final sortedDocs = docs.toList()
            ..sort((a, b) {
              final t1 =
                  (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final t2 =
                  (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              if (t1 == null || t2 == null) return 0;
              return t2.compareTo(t1);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDocs.length,
            itemBuilder: (context, index) {
              final doc = sortedDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final details = data['details'] ?? 'ไม่ทราบรายการ';
              final userEmail = data['userEmail'] ?? 'ไม่ทราบผู้ใช้';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

              // We assume 1 transaction = 1 item sold based on our mock logic
              const quantity = 1;

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.shopping_bag, color: Colors.white),
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
                    'จำนวน: $quantity',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
