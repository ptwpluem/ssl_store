// lib/pages/owner/owner_overview_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../../services/market_service.dart';
import '../../widgets/owner_metric_card.dart';
import '../../widgets/low_stock_banner.dart';
import '../../utils/app_logger.dart';
import '../../utils/owner_alerts.dart';
import '../../utils/owner_metrics.dart';
import '../../utils/date_formatters.dart';

class OwnerOverviewTab extends StatefulWidget {
  const OwnerOverviewTab({super.key});

  @override
  State<OwnerOverviewTab> createState() => _OwnerOverviewTabState();
}

class _OwnerOverviewTabState extends State<OwnerOverviewTab> {
  DateTimeRange? _selectedDateRange;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Non-date-dependent streams (created once; never reassigned) ───────────
  // Keeping these stable means StreamBuilders / OwnerMetricCards never receive
  // a new stream object on unrelated setState() calls, preventing the listener
  // churn that triggers '_dependents.isEmpty' assertion crashes.
  late final Stream<DocumentSnapshot> _goldRateDocStream;
  late final Stream<List<Map<String, dynamic>>> _rateHistoryStream;
  late final Stream<QuerySnapshot> _recentActivityStream;
  late final Stream<String> _walletTotalStream;
  late final Stream<String> _stockValueStream;
  late final Stream<String> _stockInvestmentStream;
  late final Stream<String> _productCountStream;
  late final Stream<String> _savingsLiabilityStream;
  late final Stream<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>
      _stockAlertStream;

  // ── Date-filtered streams (recreated in _rebuildFilteredStreams()) ─────────
  // These must be NEW objects whenever _selectedDateRange changes so that
  // OwnerMetricCard StreamBuilders cancel and resubscribe with the updated
  // filter. Using late (non-final) fields allows reassignment.
  late Stream<String> _profitStream;
  late Stream<String> _revenueStream;
  late Stream<String> _costStream;
  late Stream<String> _buyCountStream;
  late Stream<String> _sellCountStream;
  late Stream<String> _pawnCountStream;
  late Stream<String> _savingsCountStream;

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
    TradingService().repairAllTransactions().catchError((Object e, StackTrace s) {
      AppLogger.warning('Background repairAllTransactions failed',
          error: e, stackTrace: s);
    });

    // ── Non-date streams ─────────────────────────────────────────────────────
    _goldRateDocStream = FirebaseFirestore.instance
        .collection('market')
        .doc('gold_rate')
        .snapshots();

    _rateHistoryStream = MarketService().getGoldRateHistoryStream(limit: 5);

    _recentActivityStream = FirebaseFirestore.instance
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();

    _walletTotalStream = FirebaseFirestore.instance 
        .collection('wallets')
        .snapshots()
        .map((snap) => _formatCurrency(
              // [1] ยอดเงินใน Wallet ลูกค้า
              OwnerMetrics.walletTotal(snap.docs.map((d) => d.data())),
            ));

    _stockValueStream = FirebaseFirestore.instance
        .collection('market')
        .doc('gold_rate')
        .snapshots()
        .asyncMap((rateDoc) async {
      final data = rateDoc.data();
      final sellRate = (data?['sellPrice'] as num?)?.toDouble() ?? 42000.0;
      final productSnap =
          await FirebaseFirestore.instance.collection('products').get();
      // [2] คำนวณมูลค่าสต็อก
      return _formatCurrency(
        OwnerMetrics.stockValue(productSnap.docs.map((d) => d.data()), sellRate),
      );
    });

    _stockInvestmentStream = FirebaseFirestore.instance
        .collection('products')
        .snapshots()
        .map((productSnap) => _formatCurrency(
              // [3] เงินลงทุนในสต็อก
              OwnerMetrics.stockInvestment(productSnap.docs.map((d) => d.data())),
            ));

    _productCountStream = FirebaseFirestore.instance
        .collection('products')
        .where('stock', isGreaterThan: 0)
        .snapshots()
        .map((snap) => snap.docs.length.toString()); // [4] ประเภทสินค้า ที่มี Stock > 0

    // Restock alerts: low-stock + out-of-stock products for the dashboard banner.
    _stockAlertStream = FirebaseFirestore.instance
        .collection('products')
        .snapshots()
        .map((snap) {
      final products = snap.docs.map((d) => d.data()).toList();
      return (OwnerAlerts.lowStock(products), OwnerAlerts.outOfStock(products));
    });

    _savingsLiabilityStream = FirebaseFirestore.instance
        .collectionGroup('savings')
        .snapshots()
        .asyncMap((snap) async {
      final totalWeight = OwnerMetrics.savingsWeight(
        snap.docs.where((d) => d.id == 'account').map((d) => d.data()),
      );
      final rateDoc = await FirebaseFirestore.instance
          .collection('market')
          .doc('gold_rate')
          .get();
      final sellPrice =
          (rateDoc.data()?['sellPrice'] as num?)?.toDouble() ?? 40000.0;
      return _formatCurrency(totalWeight * sellPrice); // [6] หนี้สินออมทอง (ถ้าทุกคนออมทองวันนี้ ร้านต้องจ่าย XXX บาท)
    });

    // ── Date-filtered streams (initial build) ────────────────────────────────
    _rebuildFilteredStreams();
  }

  /// Recreates all date-filtered metric streams. Call inside any [setState]
  /// that mutates [_selectedDateRange] so that OwnerMetricCard StreamBuilders
  /// receive a new stream object and resubscribe with the updated filter.
  void _rebuildFilteredStreams() {
    _profitStream = FirebaseFirestore.instance
        .collection('transactions')
        .where('type', whereIn: ['buy', 'redeem'])
        .snapshots()
        .map((snap) => _formatCurrency(
              OwnerMetrics.profit(
                snap.docs.map((d) => d.data()),
                _selectedDateRange,
              ),
            ));

    _revenueStream = FirebaseFirestore.instance
        .collection('transactions')
        .where('type', whereIn: ['buy', 'redeem'])
        .snapshots()
        .map((snap) => _formatCurrency(
              OwnerMetrics.revenue(
                snap.docs.map((d) => d.data()),
                _selectedDateRange,
              ),
            ));

    _costStream = FirebaseFirestore.instance
        .collection('transactions')
        .where('type', whereIn: ['buy', 'redeem'])
        .snapshots()
        .map((snap) => _formatCurrency(
              OwnerMetrics.cost(
                snap.docs.map((d) => d.data()),
                _selectedDateRange,
              ),
            ));

    _buyCountStream  = _getTypeCountStream(['buy']).map((c) => c.toString());
    _sellCountStream = _getTypeCountStream(['sell']).map((c) => c.toString());
    _pawnCountStream = _getTypeCountStream(['pawn']).map((c) => c.toString()); // [5] ดูจำนวนทองที่จำนำ
    _savingsCountStream = _getTypeCountStream(
            ['savings_deposit', 'savings_withdraw'])
        .map((c) => c.toString());
  }

  // ─── Date range helpers ───────────────────────────────────────────────────

  // ─── Data helpers ─────────────────────────────────────────────────────────

  Stream<int> _getTypeCountStream(List<String> types) {
    return _firestore
        .collection('transactions')
        .where('type', whereIn: types)
        .snapshots()
        .map((snap) => OwnerMetrics.countInRange(
              snap.docs.map((d) => d.data()),
              _selectedDateRange,
            ));
  }

  String _formatCurrency(double amount) => OwnerMetrics.formatCurrency(amount);

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
                StreamBuilder<
                    (List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
                  stream: _stockAlertStream,
                  builder: (context, snap) {
                    final (low, out) = snap.data ??
                        (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
                    return LowStockBanner(lowStock: low, outOfStock: out);
                  },
                ),
                _buildGoldRateCard(),
                const SizedBox(height: 14),
                _buildRateHistoryCard(),
                const SizedBox(height: 24),
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
                  _rebuildFilteredStreams();
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
                      onTap: () => setState(() {
                        _selectedDateRange = null;
                        _rebuildFilteredStreams();
                      }),
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

  // ─── Gold Rate Card ───────────────────────────────────────────────────────

  Widget _buildGoldRateCard() {
    final numFmt = NumberFormat('#,##0');
    return StreamBuilder<DocumentSnapshot>(
      stream: _goldRateDocStream,
      builder: (context, snapshot) {
        double buyPrice = 0;
        double sellPrice = 0;
        String trend = 'stable';
        DateTime? updatedAt;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          buyPrice = (data['buyPrice'] as num?)?.toDouble() ?? 0;
          sellPrice = (data['sellPrice'] as num?)?.toDouble() ?? 0;
          trend = data['trend'] as String? ?? 'stable';
          updatedAt = (data['timestamp'] as Timestamp?)?.toDate();
        }

        final trendIcon = trend == 'up'
            ? Icons.trending_up_rounded
            : trend == 'down'
                ? Icons.trending_down_rounded
                : Icons.trending_flat_rounded;
        final trendColor = trend == 'up'
            ? const Color(0xFF2E7D32)
            : trend == 'down'
                ? const Color(0xFFC62828)
                : const Color(0xFF757575);

        final timeLabel = updatedAt != null
            ? 'อัปเดต ${DateFormat('d MMM HH:mm').format(updatedAt)}'
            : 'ยังไม่มีข้อมูลราคา';

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6D1A1A), Color(0xFF800000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF800000).withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'ราคาทองวันนี้',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(trendIcon, color: trendColor, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Price row
                Row(
                  children: [
                    // Buy price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ราคารับซื้อ',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            buyPrice > 0
                                ? '฿${numFmt.format(buyPrice)}'
                                : '—',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Text(
                            'ต่อบาทน้ำหนัก',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      width: 1,
                      height: 48,
                      color: Colors.white24,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    // Sell price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ราคาขาย',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sellPrice > 0
                                ? '฿${numFmt.format(sellPrice)}'
                                : '—',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Text(
                            'ต่อบาทน้ำหนัก',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Update button
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _showGoldRateUpdateDialog(
                        context, buyPrice, sellPrice),
                    icon: const Icon(Icons.edit_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'อัปเดตราคาทอง',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.30)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Gold Rate Update Dialog ──────────────────────────────────────────────

  Future<void> _showGoldRateUpdateDialog(
      BuildContext context, double currentBuy, double currentSell) async {
    final formKey = GlobalKey<FormState>();
    final buyCtrl = TextEditingController(
        text: currentBuy > 0 ? currentBuy.toStringAsFixed(0) : '');
    final sellCtrl = TextEditingController(
        text: currentSell > 0 ? currentSell.toStringAsFixed(0) : '');

    bool isLoading = false;
    final numFmt = NumberFormat('#,##0');

    await showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // Live spread — recomputed every rebuild triggered by onChanged
            final buyVal   = double.tryParse(buyCtrl.text)  ?? 0.0;
            final sellVal  = double.tryParse(sellCtrl.text) ?? 0.0;
            final spread   = sellVal - buyVal;
            final showSpread = buyVal > 0 && sellVal > 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: _primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'อัปเดตราคาทอง',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ราคาต่อบาทน้ำหนัก (บาท)',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 14),
                    // Buy price field
                    TextFormField(
                      controller: buyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'ราคารับซื้อ (บาท)',
                        prefixIcon: const Icon(Icons.arrow_downward_rounded,
                            color: Color(0xFF2E7D32), size: 20),
                        prefixText: '฿ ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: _primary, width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'กรุณาใส่ราคารับซื้อ';
                        }
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) {
                          return 'ราคาต้องมากกว่า 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Sell price field
                    TextFormField(
                      controller: sellCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'ราคาขาย (บาท)',
                        prefixIcon: const Icon(Icons.arrow_upward_rounded,
                            color: Color(0xFF800000), size: 20),
                        prefixText: '฿ ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: _primary, width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'กรุณาใส่ราคาขาย';
                        }
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) {
                          return 'ราคาต้องมากกว่า 0';
                        }
                        final buyVal = double.tryParse(buyCtrl.text) ?? 0;
                        if (val < buyVal) {
                          return 'ราคาขายต้องไม่ต่ำกว่าราคารับซื้อ';
                        }
                        return null;
                      },
                    ),
                    // ── Live spread indicator ──────────────────────────────
                    if (showSpread) ...[
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: spread >= 0
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: spread >= 0
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFFCA5A5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swap_vert_rounded,
                              size: 16,
                              color: spread >= 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ส่วนต่าง (Spread)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '฿${numFmt.format(spread.abs())}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: spread >= 0
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('ยกเลิก',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isLoading = true);

                          try {
                            final uid = FirebaseAuth
                                    .instance.currentUser?.uid ??
                                'unknown';
                            await MarketService().updateGoldRate(
                              buyPrice:
                                  double.parse(buyCtrl.text),
                              sellPrice:
                                  double.parse(sellCtrl.text),
                              updatedByUid: uid,
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '✅ อัปเดตราคาทองสำเร็จ'),
                                  backgroundColor:
                                      Color(0xFF2E7D32),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '❌ เกิดข้อผิดพลาด: $e'),
                                  backgroundColor:
                                      const Color(0xFFC62828),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('บันทึก',
                          style: TextStyle(
                              fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    buyCtrl.dispose();
    sellCtrl.dispose();
  }

  // ─── Rate History Card ────────────────────────────────────────────────────

  Widget _buildRateHistoryCard() {
    final numFmt = NumberFormat('#,##0');
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _rateHistoryStream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F1F3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.history_rounded,
                          color: _primary, size: 15),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ประวัติอัตราล่าสุด',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length} รายการล่าสุด',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF0F1F3)),

              // History rows
              ...List.generate(items.length, (index) {
                final item    = items[index];
                final buy     = (item['buyPrice']  as num?)?.toDouble() ?? 0;
                final sell    = (item['sellPrice'] as num?)?.toDouble() ?? 0;
                final trend   = item['trend'] as String? ?? 'stable';
                final ts      = item['timestamp'] as DateTime? ?? DateTime.now();

                final trendIcon  = trend == 'up'
                    ? Icons.trending_up_rounded
                    : trend == 'down'
                        ? Icons.trending_down_rounded
                        : Icons.trending_flat_rounded;
                final trendColor = trend == 'up'
                    ? const Color(0xFF16A34A)
                    : trend == 'down'
                        ? const Color(0xFFDC2626)
                        : Colors.grey;

                final isLast = index == items.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          // Trend icon
                          Icon(trendIcon, size: 16, color: trendColor),
                          const SizedBox(width: 10),

                          // Timestamp
                          Expanded(
                            child: Text(
                              DateFormat('d MMM HH:mm').format(ts),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),

                          // Buy
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '฿${numFmt.format(buy)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textDark,
                                ),
                              ),
                              Text('รับซื้อ',
                                  style: TextStyle(
                                      fontSize: 9, color: Colors.grey[400])),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: const Color(0xFFE9EAEC),
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                          ),

                          // Sell
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '฿${numFmt.format(sell)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF800000),
                                ),
                              ),
                              Text('ขาย',
                                  style: TextStyle(
                                      fontSize: 9, color: Colors.grey[400])),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                          height: 1,
                          indent: 42,
                          color: Color(0xFFF5F5F5)),
                  ],
                );
              }),

              const SizedBox(height: 4),
            ],
          ),
        );
      },
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
                  stream: _profitStream,
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
                  stream: _revenueStream,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OwnerMetricCard(
                  title: 'เงินต้น/ทุน',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFFC62828),
                  isHero: true,
                  stream: _costStream,
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
              stream: _buyCountStream,
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
              stream: _sellCountStream,
            ),
            OwnerMetricCard(
              title: 'รายการจำนำ',
              icon: Icons.real_estate_agent_rounded,
              color: const Color(0xFFE65100),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OwnerPawnsPage()),
              ),
              stream: _pawnCountStream,
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
              stream: _savingsCountStream,
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
              stream: _walletTotalStream,
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
              stream: _stockValueStream,
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
              stream: _stockInvestmentStream,
            ),
            OwnerMetricCard(
              title: 'ประเภทสินค้า',
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF2E7D32),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OwnerProductsPage()),
              ),
              stream: _productCountStream,
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
              stream: _pawnCountStream,
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
              stream: _savingsLiabilityStream,
            ),
          ],
        ),
      ],
    );
  }

  // ─── Recent Activity List ─────────────────────────────────────────────────

  Widget _buildRecentActivityList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _recentActivityStream,
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
