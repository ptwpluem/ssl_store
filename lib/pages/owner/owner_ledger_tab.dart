// lib/pages/owner/owner_ledger_tab.dart
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
  String _filter = 'all';

  static const Color _primary = Color(0xFF800000);
  static const Color _textDark = Color(0xFF1A1A2E);

  // Filter chip config: value → (label, icon, color)
  static const List<_FilterOption> _filters = [
    _FilterOption('all', 'ทั้งหมด', Icons.list_rounded, Color(0xFF475569)),
    _FilterOption('buy', 'ซื้อจากร้าน', Icons.shopping_bag_rounded,
        Color(0xFF1976D2)),
    _FilterOption('sell', 'ขายคืน', Icons.storefront_rounded,
        Color(0xFFDC2626)),
    _FilterOption('pawn', 'จำนำ', Icons.real_estate_agent_rounded,
        Color(0xFFEA580C)),
    _FilterOption('redeem', 'ไถ่ถอน', Icons.assignment_return_rounded,
        Color(0xFF2563EB)),
    _FilterOption('savings', 'ออมทอง', Icons.savings_rounded,
        Color(0xFF059669)),
    _FilterOption('deposit', 'เติมเงิน', Icons.add_card_rounded,
        Color(0xFF7C3AED)),
    _FilterOption('withdrawal', 'ถอนเงิน', Icons.money_off_rounded,
        Color(0xFF9F1239)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildTransactionsList()),
      ],
    );
  }

  // ─── Header + Filter Chips ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.receipt_long_rounded,
                    size: 18, color: _primary),
                const SizedBox(width: 8),
                const Text(
                  'สมุดบัญชีรายการธุรกรรม',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Filter chips scrollable row
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final opt = _filters[index];
                final isSelected = _filter == opt.value;
                return GestureDetector(
                  onTap: () => setState(() => _filter = opt.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 0),
                    decoration: BoxDecoration(
                      color: isSelected ? opt.color : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? opt.color
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          opt.icon,
                          size: 13,
                          color: isSelected ? Colors.white : Colors.grey[500],
                        ),
                        const SizedBox(width: 5),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ─── Transactions List ────────────────────────────────────────────────────

  Widget _buildTransactionsList() {
    Query query =
        FirebaseFirestore.instance.collection('transactions');

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
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: _primary, strokeWidth: 2.5),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('ไม่พบรายการธุรกรรม',
                    style:
                        TextStyle(color: Colors.grey[400], fontSize: 15)),
              ],
            ),
          );
        }

        final formatter = NumberFormat('#,##0.00');
        var docs = snapshot.data!.docs;

        // Sort if not 'all' (all is already sorted by Firestore)
        if (_filter != 'all') {
          docs = docs.toList()
            ..sort((a, b) {
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

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildTransactionRow(data, formatter);
          },
        );
      },
    );
  }

  // ─── Single Transaction Row ───────────────────────────────────────────────
  //
  // NOTE: Flutter does not allow a non-uniform Border (different widths per
  // side) combined with borderRadius. Doing so causes child widgets to
  // silently disappear at paint time. The left accent strip is instead
  // implemented as an inner Container inside a ClipRRect + IntrinsicHeight Row.

  Widget _buildTransactionRow(
      Map<String, dynamic> data, NumberFormat formatter) {
    final typeStr = data['type'] as String? ?? 'unknown';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final email = data['userEmail'] as String? ?? 'ไม่ทราบผู้ใช้';
    final details = data['details'] as String? ?? '';
    final category = data['category'] as String? ?? '';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    // ── Type config ──────────────────────────────────────────────────────
    final IconData typeIcon;
    final Color typeColor;
    final String typeLabel;

    switch (typeStr) {
      case 'buy':
        typeIcon = Icons.shopping_bag_rounded;
        typeColor = const Color(0xFF1976D2);
        typeLabel = 'ซื้อ';
        break;
      case 'sell':
        typeIcon = Icons.storefront_rounded;
        typeColor = const Color(0xFFDC2626);
        typeLabel = 'ขาย';
        break;
      case 'pawn':
        typeIcon = Icons.real_estate_agent_rounded;
        typeColor = const Color(0xFFEA580C);
        typeLabel = 'จำนำ';
        break;
      case 'redeem':
        typeIcon = Icons.assignment_return_rounded;
        typeColor = const Color(0xFF2563EB);
        typeLabel = 'ไถ่ถอน';
        break;
      case 'savings_deposit':
      case 'savings_withdraw':
        typeIcon = Icons.savings_rounded;
        typeColor = const Color(0xFF059669);
        typeLabel = typeStr == 'savings_deposit' ? 'ออมทอง' : 'ถอนออมทอง';
        break;
      case 'deposit':
        typeIcon = Icons.add_card_rounded;
        typeColor = const Color(0xFF7C3AED);
        typeLabel = 'เติมเงิน';
        break;
      case 'withdrawal':
        typeIcon = Icons.money_off_rounded;
        typeColor = const Color(0xFF9F1239);
        typeLabel = 'ถอนเงิน';
        break;
      default:
        typeIcon = Icons.receipt_rounded;
        typeColor = Colors.grey;
        typeLabel = typeStr;
    }

    final isIncoming = ['buy', 'redeem', 'savings_deposit', 'deposit']
        .contains(typeStr);
    final amountColor =
        isIncoming ? const Color(0xFF059669) : const Color(0xFFDC2626);

    // ── Card shell ────────────────────────────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F1F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left accent strip ────────────────────────────────────
              Container(width: 4, color: typeColor),

              // ── Content area ─────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 13, 13, 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type icon circle
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 18),
                      ),
                      const SizedBox(width: 12),

                      // Details column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + type badge row
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    details.isNotEmpty ? details : typeLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    typeLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: typeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // User email
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    size: 11, color: Colors.grey[400]),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    email,
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[500]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            // Category
                            if (category.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.label_outline_rounded,
                                      size: 11, color: Colors.grey[400]),
                                  const SizedBox(width: 3),
                                  Text(
                                    category,
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ],

                            // Timestamp
                            if (timestamp != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded,
                                      size: 11, color: Colors.grey[400]),
                                  const SizedBox(width: 3),
                                  Text(
                                    FormatterUtils.formatThaiDateTime(timestamp),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Amount
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${isIncoming ? '+' : '-'}฿${formatter.format(amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: amountColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter Option Model ───────────────────────────────────────────────────────

class _FilterOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _FilterOption(this.value, this.label, this.icon, this.color);
}
