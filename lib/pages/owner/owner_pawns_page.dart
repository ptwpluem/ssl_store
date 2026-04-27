import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OwnerPawnsPage extends StatefulWidget {
  const OwnerPawnsPage({super.key});

  @override
  State<OwnerPawnsPage> createState() => _OwnerPawnsPageState();
}

class _OwnerPawnsPageState extends State<OwnerPawnsPage> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการรับจำนำทั้งหมด'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['ทั้งหมด', 'เกินกำหนด', 'ใกล้ครบกำหนด'].map((f) {
                final isSelected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _filter = f),
                    selectedColor: Colors.orange.withValues(alpha: 0.2),
                    checkmarkColor: Colors.orange,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('assets')
            .where('status', isEqualTo: 'pawned')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final soonThresholdDay = today.add(const Duration(days: 7));
          
          List<Map<String, dynamic>> items = [];
          
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            items = snapshot.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();
            return _buildList(context, items, now, today, soonThresholdDay);
          } else {
            // Fallback: Query transactions if no assets found
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('type', isEqualTo: 'pawn')
                  .snapshots(),
              builder: (context, txSnapshot) {
                if (txSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!txSnapshot.hasData || txSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('ไม่พบรายการรับจำนำที่เปิดอยู่'));
                }
                
                final txDocs = txSnapshot.data!.docs.toList();
                // Map transactions to pseudo-assets
                return _buildList(context, txDocs.map((tx) {
                  final data = tx.data() as Map<String, dynamic>;
                  final timestamp = (data['timestamp'] as Timestamp?) ?? Timestamp.now();
                  return {
                    'name': data['details']?.toString().split(':').last.trim() ?? 'Pawned Item',
                    'weight': (data['weight'] as num?)?.toDouble() ?? 0.0,
                    'loanAmount': (data['amount'] as num?)?.toDouble() ?? 0.0,
                    'pawnDate': timestamp,
                    'dueDate': Timestamp.fromDate(timestamp.toDate().add(const Duration(days: 30))),
                    'status': 'pawned',
                  };
                }).toList(), now, today, soonThresholdDay);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Map<String, dynamic>> items, DateTime now, DateTime today, DateTime soonThresholdDay) {
    var filteredItems = items;

    // Apply Filter
    if (_filter == 'เกินกำหนด') {
      filteredItems = filteredItems.where((data) {
        final dueDateRaw = data['dueDate'] as Timestamp?;
        if (dueDateRaw == null) return false;
        final d = dueDateRaw.toDate();
        final dueDateDay = DateTime(d.year, d.month, d.day);
        return dueDateDay.isBefore(today);
      }).toList();
    } else if (_filter == 'ใกล้ครบกำหนด') {
      filteredItems = filteredItems.where((data) {
        final dueDateRaw = data['dueDate'] as Timestamp?;
        if (dueDateRaw == null) return false;
        final d = dueDateRaw.toDate();
        final dueDateDay = DateTime(d.year, d.month, d.day);
        
        bool isOverdue = dueDateDay.isBefore(today);
        bool isWithinThreshold = dueDateDay.isBefore(soonThresholdDay) || dueDateDay.isAtSameMomentAs(soonThresholdDay);
        
        return !isOverdue && isWithinThreshold;
      }).toList();
    }

    // Sort descending by pawnDate
    filteredItems.sort((a, b) {
      final t1 = a['pawnDate'] as Timestamp?;
      final t2 = b['pawnDate'] as Timestamp?;
      return (t2 ?? Timestamp(0, 0)).compareTo(t1 ?? Timestamp(0, 0));
    });

    if (filteredItems.isEmpty) {
      return Center(child: Text('ไม่พบรายการรับจำนำในหมวด $_filter'));
    }

    final formatter = NumberFormat('#,##0.00');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final data = filteredItems[index];
        final name = data['name'] ?? 'Unknown Item';
        final weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
        final loanAmount = (data['loanAmount'] as num?)?.toDouble() ?? 0.0;
        final pawnDate = (data['pawnDate'] as Timestamp?)?.toDate();
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();

        final dueDateRaw = data['dueDate'] as Timestamp?;
        bool isOverdue = false;
        bool isDueSoon = false;
        
        if (dueDateRaw != null) {
          final d = dueDateRaw.toDate();
          final dueDateDay = DateTime(d.year, d.month, d.day);
          isOverdue = dueDateDay.isBefore(today);
          isDueSoon = !isOverdue && (dueDateDay.isBefore(soonThresholdDay) || dueDateDay.isAtSameMomentAs(soonThresholdDay));
        }

        Color statusColor = Colors.grey;
        String statusLabel = 'ปกติ';
        if (isOverdue) {
          statusColor = Colors.red;
          statusLabel = 'เกินกำหนด';
        } else if (isDueSoon) {
          statusColor = Colors.orange;
          statusLabel = 'ใกล้ครบกำหนด';
        }

        return Card(
          elevation: isOverdue ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: statusColor.withValues(alpha: 0.3),
              width: isOverdue ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.1),
              child: Icon(Icons.real_estate_agent, color: statusColor),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('น้ำหนัก: ${weight.toStringAsFixed(2)} บาท'),
                Text(
                  'วันที่เริ่มจำนำ: ${pawnDate != null ? DateFormat('dd/MM/yyyy').format(pawnDate) : '-'}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'วันครบกำหนด: ${dueDate != null ? DateFormat('dd/MM/yyyy').format(dueDate) : '-'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isOverdue || isDueSoon ? FontWeight.bold : FontWeight.normal,
                    color: statusColor == Colors.grey ? Colors.black54 : statusColor,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'ยอดเงินกู้',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  '฿${formatter.format(loanAmount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: statusColor == Colors.red ? Colors.red : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
