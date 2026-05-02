// lib/pages/owner/owner_overview_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'owner_wallets_page.dart';
import 'owner_pawns_page.dart';
import 'owner_products_page.dart';
import 'owner_savings_page.dart';
import 'owner_sales_thb_page.dart';
import 'owner_inventory_cost_page.dart';
import 'owner_sell_transactions_page.dart';
import 'owner_savings_transactions_page.dart';
import '../../services/trading_service.dart';
import '../../widgets/owner_metric_card.dart';
import '../../utils/date_formatters.dart';

class OwnerOverviewTab extends StatefulWidget {
  const OwnerOverviewTab({super.key});

  @override
  State<OwnerOverviewTab> createState() => _OwnerOverviewTabState();
}

class _OwnerOverviewTabState extends State<OwnerOverviewTab> {
  DateTimeRange? _selectedDateRange;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Design tokens
  static const Color _primary = Color(0xFF800000);
  static const Color _textDark = Color(0xFF1A1A2E);

  // Thai date helpers
  static const List<String> _thaiDays = [
    'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'
  ];
  static const List<String> _thaiMonths = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];

  @override
  void initState() {
    super.initState();
    TradingService().repairAllTransactions().catchError((_) {});
  }

  // ─── Date range helpers ───────────────────────────────────────────────────

  /// Returns true if [timestamp] falls within [_selectedDateRange] (inclusive
  /// of the full start day through the last millisecond of the end day).
  /// Always returns true when no date range is selected.
  bool _inRange(DateTime? timestamp) {
    if (_selectedDateRange == null || timestamp == null) return true;
    final startDay = DateTime(
      _selectedDateRange!.start.year,
      _selectedDateRange!.start.month,
      _selectedDateRange!.start.day,
    );
    final endDay = DateTime(
      _selectedDateRange!.end.year,
      _selectedDateRange!.end.month,
      _selectedDateRange!.end.day,
      23, 59, 59, 999,
    );
    return !timestamp.isBefore(startDay) && !timestamp.isAfter(endDay);
  }

  // ─── Data helpers ─────────────────────────────────────────────────────────

  Stream<int> _getTypeCountStream(List<String> types) {
    return _firestore
        .collection('transactions')
        .where('type', whereIn: types)
        .snapshots()
        .map((snap) {
      int count = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (!_inRange(timestamp)) continue;
        count++;
      }
      return count;
    });
  }

  String _formatCurrency(double amount) {
    bool isNegative = amount < 0;
    double absAmount = amount.abs();
    String prefix = isNegative ? '-฿' : '฿';
    if (absAmount >= 1000000) {
      return '$prefix${(absAmount / 1000000).toStringAsFixed(1)}M';
    } else if (absAmount >= 1000) {
      return '$prefix${(absAmount / 1000).toStringAsFixed(1)}k';
    }
    return '$prefix${absAmount.toStringAsFixed(0)}';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricsGrid(context),
                const SizedBox(height: 28),
                _sectionHeader('ความเคลื่อนไหวล่าสุด',
                    icon: Icons.history_rounded),
                const SizedBox(height: 12),
                _buildRecentActivityList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header Banner ────────────────────────────────────────────────────────

  Widget _buildHeaderBanner() {
    final now = DateTime.now();
    final dateLabel =
        'วัน${_thaiDays[now.weekday - 1]} ${now.day} ${_thaiMonths[now.month - 1]} ${now.year + 543}';

    String dateRangeText = 'ทั้งหมด';
    if (_selectedDateRange != null) {
      dateRangeText =
          '${FormatterUtils.formatThaiDateShort(_selectedDateRange!.start)} – '
          '${FormatterUtils.formatThaiDateShort(_selectedDateRange!.end)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF800000), Color(0xFF5C0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: title + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ภาพรวมธุรกิจ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.65)),
                    const SizedBox(width: 5),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right: date range filter pill
          GestureDetector(
            onTap: () async {
              final result = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _selectedDateRange,
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme:
                        const ColorScheme.light(primary: Color(0xFF800000)),
                  ),
                  child: child!,
                ),
              );
              if (result != null) {
                setState(() {
                  _selectedDateRange = DateTimeRange(
                    start: result.start,
                    end: DateTime(result.end.year, result.end.month,
                        result.end.day, 23, 59, 59, 59),
                  );
                });
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.90)),
                  const SizedBox(width: 5),
                  Text(
                    dateRangeText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.90),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_selectedDateRange != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _selectedDateRange = null),
                      child: Icon(Icons.close_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.80)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Header ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title, {IconData? icon}) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        if (icon != null) ...[
          Icon(icon, size: 17, color: _primary),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textDark,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // ─── Metrics Grid (data logic unchanged) ──────────────────────────────────

  Widget _buildMetricsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── HERO: KPIs ────────────────────────────────────────────────────
        _sectionHeader('สรุปผลประกอบการ', icon: Icons.bar_chart_rounded),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            children: [
              Expanded(
                child: OwnerMetricCard(
                  title: 'กำไร',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF2E7D32),
                  isHero: true,
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('type', whereIn: ['buy', 'redeem'])
                      .snapshots()
                      .map((snap) {
                    double total = 0.0;
                    for (var doc in snap.docs) {
                      final data = doc.data();
                      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                      if (!_inRange(timestamp)) continue;
                      total += (data['profit'] as num?)?.toDouble() ?? 0.0;
                    }
                    return _formatCurrency(total);
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OwnerMetricCard(
                  title: 'รายได้',
                  icon: Icons.monetization_on_rounded,
                  color: const Color(0xFF1A237E),
                  isHero: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OwnerSalesThbPage(dateRange: _selectedDateRange),
                    ),
                  ),
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('type', whereIn: ['buy', 'redeem'])
                      .snapshots()
                      .map((snap) {
                    double total = 0.0;
                    for (var doc in snap.docs) {
                      final data = doc.data();
                      final type = data['type'] as String?;
                      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                      if (!_inRange(timestamp)) continue;
                      if (type == 'buy') {
                        total += (data['amount'] as num?)?.toDouble() ?? 0.0;
                      } else if (type == 'redeem') {
                        total += (data['profit'] as num?)?.toDouble() ?? 0.0;
                      }
                    }
                    return _formatCurrency(total);
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OwnerMetricCard(
                  title: 'เงินต้น/ทุน',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFFC62828),
                  isHero: true,
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('type', whereIn: ['buy', 'redeem'])
                      .snapshots()
                      .map((snap) {
                    double total = 0.0;
                    for (var doc in snap.docs) {
                      final data = doc.data();
                      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                      if (!_inRange(timestamp)) continue;
                      total += (data['cost'] as num?)?.toDouble() ?? 0.0;
                    }
                    return _formatCurrency(total);
                  }),
                ),
              ),
            ],
          ),
        ),

        // ── TRANSACTION ACTIVITY ──────────────────────────────────────────
        const SizedBox(height: 28),
        _sectionHeader('กิจกรรมรายการ', icon: Icons.swap_horiz_rounded),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.7,
          children: [
            OwnerMetricCard(
              title: 'รายการซื้อ',
              icon: Icons.shopping_bag_rounded,
              color: const Color(0xFF1976D2),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      OwnerSalesThbPage(dateRange: _selectedDateRange),
                ),
              ),
              stream:
                  _getTypeCountStream(['buy']).map((c) => c.toString()),
            ),
            OwnerMetricCard(
              title: 'รายการขาย',
              icon: Icons.storefront_rounded,
              color: const Color(0xFFC62828),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OwnerSellTransactionsPage(
                      dateRange: _selectedDateRange),
                ),
              ),
              stream:
                  _getTypeCountStream(['sell']).map((c) => c.toString()),
            ),
            OwnerMetricCard(
              title: 'รายการจำนำ',
              icon: Icons.real_estate_agent_rounded,
              color: const Color(0xFFE65100),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OwnerPawnsPage()),
              ),
              stream:
                  _getTypeCountStream(['pawn']).map((c) => c.toString()),
            ),
            OwnerMetricCard(
              title: 'รายการออมทอง',
              icon: Icons.savings_rounded,
              color: const Color(0xFF00695C),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OwnerSavingsTransactionsPage(
                      dateRange: _selectedDateRange),
                ),
              ),
              stream: _getTypeCountStream(
                      ['savings_deposit', 'savings_withdraw'])
                  .map((c) => c.toString()),
            ),
          ],
        ),

        // ── STORE EQUITY ──────────────────────────────────────────────────
        const SizedBox(height: 28),
        _sectionHeader('สินทรัพย์และเงินหมุนเวียน',
            icon: Icons.account_balance_rounded),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.7,
          children: [
            OwnerMetricCard(
              title: 'ยอดเงินในวอลเล็ตลูกค้า',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF6A1B9A),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OwnerWalletsPage()),
              ),
              stream: FirebaseFirestore.instance
                  .collection('wallets')
                  .snapshots()
                  .map((snap) {
                double total = 0.0;
                for (var doc in snap.docs) {
                  total +=
                      (doc.data()['balance'] as num?)?.toDouble() ?? 0.0;
                }
                return _formatCurrency(total);
              }),
            ),
            OwnerMetricCard(
              title: 'มูลค่าสต็อก (ราคาขาย)',
              icon: Icons.auto_graph_rounded,
              color: const Color(0xFFEF6C00),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const OwnerInventoryCostPage()),
              ),
              stream: FirebaseFirestore.instance
                  .collection('market')
                  .doc('gold_rate')
                  .snapshots()
                  .asyncMap((rateDoc) async {
                final data = rateDoc.data();
                final sellRate =
                    (data?['sellPrice'] as num?)?.toDouble() ?? 42000.0;
                final productSnap = await FirebaseFirestore.instance
                    .collection('products')
                    .get();
                double totalValue = 0.0;
                for (var doc in productSnap.docs) {
                  final pData = doc.data();
                  final stock = (pData['stock'] as num?)?.toInt() ?? 0;
                  final weight =
                      (pData['weight'] as num?)?.toDouble() ?? 0.0;
                  final laborFee =
                      (pData['laborFee'] as num?)?.toDouble() ?? 0.0;
                  totalValue += stock * ((weight * sellRate) + laborFee);
                }
                return _formatCurrency(totalValue);
              }),
            ),
            OwnerMetricCard(
              title: 'เงินลงทุนในสต็อก',
              icon: Icons.inventory_rounded,
              color: const Color(0xFF4E342E),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const OwnerInventoryCostPage()),
              ),
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .snapshots()
                  .map((productSnap) {
                double totalInvestment = 0.0;
                for (var doc in productSnap.docs) {
                  final pData = doc.data();
                  final stock = (pData['stock'] as num?)?.toInt() ?? 0;
                  final costBasis =
                      (pData['costBasis'] as num?)?.toDouble() ?? 0.0;
                  totalInvestment += stock * costBasis;
                }
                return _formatCurrency(totalInvestment);
              }),
            ),
            OwnerMetricCard(
              title: 'ประเภทสินค้า',
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF2E7D32),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OwnerProductsPage()),
              ),
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('stock', isGreaterThan: 0)
                  .snapshots()
                  .map((snap) => snap.docs.length.toString()),
            ),
          ],
        ),

        // ── LIABILITIES ───────────────────────────────────────────────────
        const SizedBox(height: 28),
        _sectionHeader('หนี้สิน/ภาระผูกพัน',
            icon: Icons.account_balance_wallet_outlined),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.7,
          children: [
            OwnerMetricCard(
              title: 'ทองรับจำนำ (ใช้งาน)',
              icon: Icons.real_estate_agent_rounded,
              color: const Color(0xFFE65100),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OwnerPawnsPage()),
              ),
              stream:
                  _getTypeCountStream(['pawn']).map((c) => c.toString()),
            ),
            OwnerMetricCard(
              title: 'หนี้สินออมทอง',
              icon: Icons.savings_rounded,
              color: const Color(0xFF00695C),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const OwnerSavingsPage()),
              ),
              stream: FirebaseFirestore.instance
                  .collectionGroup('savings')
                  .snapshots()
                  .asyncMap((snap) async {
                double totalWeight = 0.0;
                for (var doc in snap.docs) {
                  if (doc.id == 'account') {
                    final data = doc.data();
                    totalWeight +=
                        (data['totalWeightSaved'] as num?)?.toDouble() ?? 0.0;
                  }
                }
                final rateDoc = await FirebaseFirestore.instance
                    .collection('market')
                    .doc('gold_rate')
                    .get();
                final sellPrice =
                    (rateDoc.data()?['sellPrice'] as num?)?.toDouble() ??
                        40000.0;
                return _formatCurrency(totalWeight * sellPrice);
              }),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Recent Activity List ─────────────────────────────────────────────────

  Widget _buildRecentActivityList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  color: _primary, strokeWidth: 2.5),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F1F3)),
            ),
            child: const Center(
              child: Text('ไม่พบกิจกรรมล่าสุด',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final formatter = NumberFormat('#,##0.00');
        const typeLabels = <String, String>{
          'buy': 'ซื้อ',
          'sell': 'ขาย',
          'pawn': 'จำนำ',
          'redeem': 'ไถ่ถอน',
          'savings_deposit': 'ออมทอง',
          'savings_withdraw': 'ถอนออมทอง',
          'deposit': 'เติมเงิน',
          'withdrawal': 'ถอนเงิน',
        };

        final docs = snapshot.data!.docs;

        return Column(
          children: List.generate(docs.length, (index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final typeStr = data['type'] as String? ?? 'unknown';
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final email = data['userEmail'] as String? ?? 'Unknown User';
            final details = data['details'] as String? ?? '';
            final purity = (data['purity'] as num?)?.toDouble();

            final isIncoming = [
              'buy', 'redeem', 'savings_deposit', 'deposit'
            ].contains(typeStr);

            final accentColor = isIncoming
                ? const Color(0xFF059669)
                : const Color(0xFFDC2626);

            final typeLabel = typeLabels[typeStr] ?? typeStr;

            return Container(
              margin: EdgeInsets.only(bottom: index < docs.length - 1 ? 10 : 0),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Direction icon circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIncoming
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: accentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            details.isNotEmpty ? details : typeLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      accentColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Amount + purity
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isIncoming ? '+' : '-'}฿${formatter.format(amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: accentColor,
                          ),
                        ),
                        if (purity != null)
                          Text(
                            purity == 0.9999 ? '99.99%' : '96.5%',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
