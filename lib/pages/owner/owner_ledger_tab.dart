import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/date_formatters.dart';

class OwnerLedgerTab extends StatefulWidget {
  const OwnerLedgerTab({super.key});

  @override
  State<OwnerLedgerTab> createState() => _OwnerLedgerTabState();
}

class _OwnerLedgerTabState extends State<OwnerLedgerTab> {
  String _filter = 'all'; // 'all', 'buy', 'sell', 'pawn', 'redeem'

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          width: double.infinity,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'สมุดบัญชีรายการธุรกรรมทั้งหมด',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF800000),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ทั้งหมด', 'all'),
                    _buildFilterChip('รายการซื้อจากร้าน', 'buy'),
                    _buildFilterChip('รายการขายคืน', 'sell'),
                    _buildFilterChip('รายการจำนำ', 'pawn'),
                    _buildFilterChip('รายการไถ่ถอน', 'redeem'),
                    _buildFilterChip('รายการออมทอง', 'savings'),
                    _buildFilterChip('เติมเงิน', 'deposit'),
                    _buildFilterChip('ถอนเงิน', 'withdrawal'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildTransactionsList()),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (bool selected) {
          setState(() {
            _filter = value;
          });
        },
        selectedColor: const Color(0xFF800000),
        labelStyle: TextStyle(
          color: _filter == value ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    Query query = FirebaseFirestore.instance.collection('transactions');

    if (_filter == 'all') {
      query = query.orderBy('timestamp', descending: true);
    } else if (_filter == 'savings') {
      query = query.where(
        'type',
        whereIn: ['savings_deposit', 'savings_withdraw'],
      );
    } else if (_filter == 'deposit') {
      query = query.where('type', isEqualTo: 'deposit');
    } else if (_filter == 'withdrawal') {
      query = query.where('type', isEqualTo: 'withdrawal');
    } else {
      query = query.where('type', isEqualTo: _filter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('ไม่พบรายการธุรกรรม'));
        }

        final formatter = NumberFormat('#,##0.00');

        var docs = snapshot.data!.docs;

        if (_filter != 'all') {
          docs = docs.toList();
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final tsA = dataA['timestamp'] as Timestamp?;
            final tsB = dataB['timestamp'] as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return tsB.compareTo(tsA);
          });
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final typeStr = data['type'] as String? ?? 'unknown';
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final email = data['userEmail'] as String? ?? 'ไม่ทราบผู้ใช้';
            final details = data['details'] as String? ?? '';
            final category = data['category'] as String? ?? 'ทั่วไป';
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            IconData icon;
            Color iconColor;

            if (typeStr == 'buy') {
              icon = Icons.shopping_cart;
              iconColor = Colors.green;
            } else if (typeStr == 'sell') {
              icon = Icons.storefront;
              iconColor = Colors.red;
            } else if (typeStr == 'pawn') {
              icon = Icons.real_estate_agent;
              iconColor = Colors.orange;
            } else if (typeStr == 'redeem') {
              icon = Icons.assignment_return;
              iconColor = Colors.blue;
            } else if (typeStr == 'savings_deposit' ||
                typeStr == 'savings_withdraw') {
              icon = Icons.savings;
              iconColor = Colors.teal;
            } else {
              icon = Icons.receipt;
              iconColor = Colors.grey;
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: iconColor.withOpacity(0.1),
                  child: Icon(icon, color: iconColor),
                ),
                title: Text(
                  details,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ผู้ใช้งาน: $email'),
                    Text('หมวดหมู่: $category'),
                    if (timestamp != null)
                      Text(
                        FormatterUtils.formatThaiDateTime(timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                trailing: Text(
                  '฿${formatter.format(amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: (typeStr == 'buy' ||
                            typeStr == 'redeem' ||
                            typeStr == 'savings_deposit' ||
                            typeStr == 'deposit')
                        ? Colors.green[700]
                        : Colors.red[700],
                  ),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
