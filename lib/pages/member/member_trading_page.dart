// lib/pages/member/member_trading_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../models/gold_asset.dart';
import '../../models/gold_rate.dart';
import '../../services/market_service.dart';
import '../../services/user_service.dart';
import '../../services/trading_service.dart';
import '../../services/pawn_service.dart';
import '../../widgets/gold_rate_card.dart';

// [1] ประกาศนอก Class เพื่อให้ทุก Class ใช้เหมือนกัน ไม่ต้องทำซ้ำ
final _fmt = NumberFormat('#,##0');
// Snap a slider double to the nearest 0.25 multiple and format it cleanly
// (e.g. 6.5000000000000001 → "6.5",  7.9999999999999999 → "8")
double _snapWeight(double val) => (val * 4).round() / 4.0;
String _fmtWeight(double w) {
  final s = w.toStringAsFixed(2);
  return s.replaceAll(RegExp(r'\.?0+$'), ''); // "8.00" → "8", "6.50" → "6.5"
}

// ─── Design tokens (matches owner dashboard) ──────────────────────────────────
const Color _primary = Color(0xFF800000);
const Color _primaryDark = Color(0xFF5C0000);
const Color _gold = Color(0xFFFFD700);
const Color _bgColor = Color(0xFFF5F7FA);

class TradingPage extends StatefulWidget {
  final int initialTabIndex;
  const TradingPage({super.key, this.initialTabIndex = 0});

  @override
  State<TradingPage> createState() => _TradingPageState();
}

class _TradingPageState extends State<TradingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MarketService _marketService = MarketService();
  final UserService _userService = UserService();
  final TradingService _tradingService = TradingService();
  final PawnService _pawnService = PawnService();
  final AuthService _authService = AuthService();
  StreamSubscription<GoldRate>? _rateSub;
  GoldRate? _currentRate;

  @override
  void initState() {
    // [3] เตรียม 2 อย่างก่อนวาด UI??
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _rateSub = _marketService.getGoldRateStream().listen((rate) {
      if (mounted) setState(() => _currentRate = rate);
    });
  }

  @override // [4] คืน Resource 2 อย่าง??
  void dispose() {
    _tabController.dispose();
    _rateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // [5] Check Log-in ถ้ายังไม่ Login Route ไปหน้า Login
      stream: _authService.user,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!authSnapshot.hasData) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
            child: Scaffold(
              backgroundColor: _bgColor,
              appBar: _buildAppBar(),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 52,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'กรุณาเข้าสู่ระบบ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'เพื่อใช้งานส่วนซื้อ-ขาย และบริการ',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'เข้าสู่ระบบ / สมัครสมาชิก',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: Scaffold(
            backgroundColor: _bgColor,
            appBar: _buildAppBar(),
            body: Column(
              children: [
                // ── Gold rate card ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _currentRate != null
                      ? GoldRateCard(rate: _currentRate!)
                      : const Center(
                          child: CircularProgressIndicator(color: _primary),
                        ),
                ),
                // ── Tab bar ───────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    padding: const EdgeInsets.all(5),
                    tabs: const [
                      Tab(
                        text: 'ซื้อ',
                        icon: Icon(Icons.shopping_cart_rounded, size: 18),
                      ),
                      Tab(
                        text: 'ขาย',
                        icon: Icon(Icons.sell_rounded, size: 18),
                      ),
                      Tab(
                        text: 'จำนำ',
                        icon: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ── Tab content ───────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController, // [7] TabBar + TarBarView
                    children: [
                      _BuyTab(
                        userService: _userService,
                        tradingService: _tradingService,
                        currentRate: _currentRate,
                      ),
                      _SellTab(
                        userService: _userService,
                        tradingService: _tradingService,
                        currentRate: _currentRate,
                      ),
                      _PawnTab(
                        userService: _userService,
                        tradingService: _tradingService,
                        pawnService: _pawnService,
                        currentRate: _currentRate,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // [6] ปุ่มย้อนกลับแบบ Dynamic
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _primary,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      titleSpacing: Navigator.canPop(context) ? 0 : 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, _primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.show_chart_rounded, color: _gold, size: 17),
          ),
          const SizedBox(width: 10),
          const Text(
            'ซื้อ-ขาย และบริการ',
            style: TextStyle(
              color: _primary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE9EAEC), height: 1),
      ),
    );
  }
}

// -- Buy Tab --
class _BuyTab extends StatefulWidget {
  final UserService userService;
  final TradingService tradingService;
  final GoldRate? currentRate;
  const _BuyTab({
    required this.userService,
    required this.tradingService,
    this.currentRate,
  });

  @override // [8] คำนวณราคาและ Slider
  State<_BuyTab> createState() => _BuyTabState();
}

class _BuyTabState extends State<_BuyTab> {
  double _weight = 1.0;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.currentRate == null)
      return const Center(child: CircularProgressIndicator());

    double total = _weight * widget.currentRate!.sellPrice;

    return StreamBuilder<double>(
      // [9]ดึงยอด Wallet แบบ Real-Time
      stream: widget.userService.getWalletBalanceStream(),
      builder: (streamContext, snapshot) {
        final balance = snapshot.data ?? 0.0;
        final hasEnoughFunds =
            balance >=
            total; // [10] สร้าง UI 3 จุด กล่อง Wallet, กล่อง Warning, ปุ่มยืนยัน

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Wallet balance card ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFF2E7D32),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ยอดเงินในวอลเล็ต',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          Text(
                            '฿ ${_fmt.format(balance)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!hasEnoughFunds)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ไม่เพียงพอ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Weight selector ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'เลือกน้ำหนัก (บาท)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _primary,
                        inactiveTrackColor: _primary.withValues(alpha: 0.15),
                        thumbColor: _primary,
                        overlayColor: _primary.withValues(alpha: 0.12),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _weight,
                        min: 0.25,
                        max: 10,
                        divisions: 39,
                        label: '${_fmtWeight(_weight)} บาท',
                        onChanged: (val) =>
                            setState(() => _weight = _snapWeight(val)),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_fmtWeight(_weight)} บาท',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Summary card ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _primary.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'สรุปรายการ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _rowItem(
                      'ราคาขายออก',
                      '฿ ${_fmt.format(widget.currentRate!.sellPrice)} / บาท',
                    ),
                    const Divider(height: 20),
                    _rowItem(
                      'ยอดรวมทั้งหมด',
                      '฿ ${_fmt.format(total)}',
                      isBold: true,
                    ),
                    if (balance >= total) ...[
                      const SizedBox(height: 4),
                      _rowItem(
                        'ยอดเงินคงเหลือโดยประมาณ',
                        '฿ ${_fmt.format(balance - total)}',
                        isBold: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Confirm button ──────────────────────────────────────────
              if (!hasEnoughFunds)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ยอดเงินไม่เพียงพอ กรุณาเติมเงินที่หน้าโปรไฟล์หรือทองของฉัน',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ElevatedButton(
                // [11] ปุ่มยืนยันการซื้อ
                onPressed: (_isProcessing || !hasEnoughFunds)
                    ? null
                    : () async {
                        setState(() => _isProcessing = true);
                        try {
                          String? productId; // Recheck do we need product_id?
                          if (_weight == 0.25) {
                            productId = 'p_bar_025';
                          } else if (_weight == 0.5) {
                            productId = 'p_bar_05';
                          } else if (_weight == 1.0) {
                            productId = 'p_bar_1';
                          } else if (_weight == 2.0) {
                            productId = 'p_bar_2';
                          } else if (_weight == 5.0) {
                            productId = 'p_bar_5';
                          } else if (_weight == 10.0) {
                            productId = 'p_bar_10';
                          }

                          await widget.tradingService.createBuyTransaction(
                            assetName: 'ทองคำแท่ง (${_fmtWeight(_weight)} บาท)',
                            weight: _weight,
                            amount: total,
                            category: 'Gold Bar',
                            productId: productId,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('การสั่งซื้อสำเร็จ!'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceAll('Exception: ', ''),
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasEnoughFunds ? _primary : Colors.grey[400],
                  foregroundColor: Colors.white,
                  elevation: hasEnoughFunds ? 3 : 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'ยืนยันการซื้อ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rowItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isBold ? const Color(0xFF1A1A2E) : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pawn Confirmation Dialog ─────────────────────────────────────────────────
// Uses a proper StatefulWidget so dispose() and mounted are correctly handled,
// preventing "TextEditingController used after disposed" and
// "build dirty widget in wrong scope" crashes.
class _PawnConfirmationDialog extends StatefulWidget {
  final GoldAsset asset;
  final double maxLoan;
  final UserService userService;
  final PawnService pawnService;

  const _PawnConfirmationDialog({
    required this.asset,
    required this.maxLoan,
    required this.userService,
    required this.pawnService,
  });

  @override
  State<_PawnConfirmationDialog> createState() =>
      _PawnConfirmationDialogState();
}

class _PawnConfirmationDialogState extends State<_PawnConfirmationDialog> {
  late final TextEditingController _loanController;
  double _requestedLoan = 0;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _requestedLoan = widget.maxLoan;
    _loanController = TextEditingController(
      text: widget.maxLoan.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _loanController.dispose();
    super.dispose();
  }

  bool get _isValid => _requestedLoan > 0 && _requestedLoan <= widget.maxLoan;

  Future<void> _confirm() async {
    if (!_isValid) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await widget.pawnService.pawnAsset(
        asset: widget.asset,
        loanAmount: _requestedLoan,
      );
      if (mounted) Navigator.of(context).pop(true); // ← pop BEFORE any setState
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText =
              'เกิดข้อผิดพลาดในการจำนำ: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
    // No finally setState — success already popped, error is handled above
  }

  @override
  Widget build(BuildContext context) {
    final dueDate = DateTime.now().add(const Duration(days: 30));
    final formattedDate = '${dueDate.day}/${dueDate.month}/${dueDate.year}';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('ยืนยันการจำนำ'),
      content: StreamBuilder<double>(
        stream: widget.userService.getWalletBalanceStream(),
        builder: (_, snapshot) {
          final walletBalance = snapshot.data ?? 0.0;
          final newBalance = walletBalance + (_isValid ? _requestedLoan : 0);

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('สินค้า: ${widget.asset.name}'),
                Text('น้ำหนัก: ${widget.asset.weight} บาท'),
                const SizedBox(height: 12),
                const Text(
                  'ระบุวงเงินที่ต้องการกู้ (บาท):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _loanController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'วงเงินที่ต้องการ (฿)',
                    border: const OutlineInputBorder(),
                    suffixText: 'กู้ได้สูงสุด: ${_fmt.format(widget.maxLoan)}',
                    errorText: (!_isValid && _loanController.text.isNotEmpty)
                        ? 'วงเงินต้องอยู่ระหว่าง 1 ถึง ${_fmt.format(widget.maxLoan)}'
                        : null,
                  ),
                  onChanged: (val) => setState(() {
                    _requestedLoan = double.tryParse(val) ?? 0.0;
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'โอนเงินเข้าวอลเล็ต:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '+ ฿ ${_fmt.format(_requestedLoan)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ยอดเงินใหม่ในวอลเล็ต:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '฿ ${_fmt.format(newBalance)}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ครบกำหนดชำระ: $formattedDate (30 วัน)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                      const Text(
                        'อัตราดอกเบี้ย 1.25% ต่อเดือน. หากชำระล่าช้าจะมีค่าปรับ 2% ต่อเดือน.',
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: (_isLoading || !_isValid) ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF800000),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'ยืนยันการจำนำ',
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}

// ─── Sell Confirmation Dialog ─────────────────────────────────────────────────
class _SellConfirmationDialog extends StatefulWidget {
  final GoldAsset asset;
  final double estimatedValue;
  final UserService userService;
  final TradingService tradingService;

  const _SellConfirmationDialog({
    required this.asset,
    required this.estimatedValue,
    required this.userService,
    required this.tradingService,
  });

  @override
  State<_SellConfirmationDialog> createState() =>
      _SellConfirmationDialogState();
}

class _SellConfirmationDialogState extends State<_SellConfirmationDialog> {
  bool _isLoading = false;
  String? _errorText;

  Future<void> _confirm() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await widget.tradingService.sellAsset(
        asset: widget.asset,
        sellPrice: widget.estimatedValue,
      );
      if (mounted) Navigator.of(context).pop(true); // ← pop BEFORE any setState
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText =
              'เกิดข้อผิดพลาดในการขายสินค้า: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('ยืนยันการขาย'),
      content: StreamBuilder<double>(
        stream: widget.userService.getWalletBalanceStream(),
        builder: (_, snapshot) {
          final walletBalance = snapshot.data ?? 0.0;
          final newBalance = walletBalance + widget.estimatedValue;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('สินค้า: ${widget.asset.name}'),
              Text('น้ำหนัก: ${widget.asset.weight} บาท'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'โอนเงินเข้าวอลเล็ต:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '+ ฿ ${_fmt.format(widget.estimatedValue)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ยอดเงินใหม่ในวอลเล็ต:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '฿ ${_fmt.format(newBalance)}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'คุณแน่ใจหรือไม่ว่าต้องการขายสินค้าชิ้นนี้? ไม่สามารถยกเลิกรายการได้หลังการยืนยัน',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _confirm,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'ยืนยันการขาย',
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}

// -- Sell Tab --
class _SellTab extends StatefulWidget {
  final UserService userService;
  final TradingService tradingService;
  final GoldRate? currentRate;
  const _SellTab({
    required this.userService,
    required this.tradingService,
    this.currentRate,
  });

  @override
  State<_SellTab> createState() => _SellTabState();
}

class _SellTabState extends State<_SellTab> {
  void _showSellConfirmation(
    BuildContext context,
    GoldAsset asset,
    double estimatedValue,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SellConfirmationDialog(
        asset: asset,
        estimatedValue: estimatedValue,
        userService: widget.userService,
        tradingService: widget.tradingService,
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('ขายสินค้าสำเร็จเรียบร้อยแล้ว!')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GoldAsset>>(
      stream: widget.tradingService.getMemberAssetsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final assets = snapshot.data ?? [];
        if (assets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sell_rounded,
                    size: 40,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ไม่มีสินค้าที่สามารถขายได้',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _primary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ซื้อทองก่อน แล้วกลับมาขายได้ที่นี่',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            final estimatedValue =
                asset.weight * (widget.currentRate?.buyPrice ?? 0);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sell_rounded,
                    color: _primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  asset.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                subtitle: Text(
                  '${asset.weight} บาท',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'ราคารับซื้อ',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                    Text(
                      '฿ ${_fmt.format(estimatedValue)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                onTap: () =>
                    _showSellConfirmation(context, asset, estimatedValue),
              ),
            );
          },
        );
      },
    );
  }
}

class _PawnTab extends StatefulWidget {
  final UserService userService;
  final TradingService tradingService;
  final PawnService pawnService;
  final GoldRate? currentRate;
  const _PawnTab({
    required this.userService,
    required this.tradingService,
    required this.pawnService,
    this.currentRate,
  });

  @override
  State<_PawnTab> createState() => _PawnTabState();
}

class _PawnTabState extends State<_PawnTab> {
  void _showPawnConfirmation(
    BuildContext context,
    GoldAsset asset,
    double maxLoan,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PawnConfirmationDialog(
        asset: asset,
        maxLoan: maxLoan,
        userService: widget.userService,
        pawnService: widget.pawnService,
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('จำนำสินค้าสำเร็จ! ยอดเงินถูกโอนเข้าวอลเล็ตแล้ว'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Info banner ───────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_rounded, color: _primary, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'อัตราดอกเบี้ย: 1.25% ต่อเดือน  •  กู้ได้สูงสุด 85% ของราคารับซื้อ',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF555555),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // ── Asset list ────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<GoldAsset>>(
            stream: widget.tradingService.getMemberAssetsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _primary),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final allAssets = snapshot.data ?? [];
              final ownedAssets = allAssets
                  .where((a) => a.status == 'owned')
                  .toList();

              if (ownedAssets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          size: 40,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ไม่มีทรัพย์สินสำหรับจำนำ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _primary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ซื้อทองก่อน แล้วกลับมาจำนำได้ที่นี่',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: ownedAssets.length,
                itemBuilder: (context, index) {
                  final asset = ownedAssets[index];
                  final currentVal =
                      asset.weight * (widget.currentRate?.buyPrice ?? 0);
                  final maxLoan = widget.pawnService.calculatePawnLoan(
                    asset.weight,
                    widget.currentRate?.buyPrice ?? 0,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: _primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        asset.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      subtitle: Text(
                        '${asset.weight} บาท  •  ประเมินราคา ฿${_fmt.format(currentVal)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'วงเงินสูงสุด',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '฿ ${_fmt.format(maxLoan)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                      onTap: () =>
                          _showPawnConfirmation(context, asset, maxLoan),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
