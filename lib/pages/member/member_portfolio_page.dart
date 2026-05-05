// lib/pages/member/member_portfolio_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/market_service.dart';
import '../../services/user_service.dart';
import '../../services/trading_service.dart';
import '../../services/savings_service.dart';
import '../../services/pawn_service.dart';
import '../../models/gold_asset.dart';
import '../../models/gold_savings.dart';
import '../../models/gold_transaction.dart';
import '../../models/gold_rate.dart';
import 'member_gold_savings_page.dart';

// Shared formatter — avoids per-build and per-dialog construction
final _portFmt = NumberFormat('#,##0');

// ─── Design tokens (matches owner dashboard) ──────────────────────────────────
const Color _portPrimary     = Color(0xFF800000);
const Color _portPrimaryDark = Color(0xFF5C0000);
const Color _portGold        = Color(0xFFFFD700);
const Color _portBg          = Color(0xFFF5F7FA);

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  final MarketService _marketService = MarketService();
  final UserService _userService = UserService();
  final TradingService _tradingService = TradingService();
  final SavingsService _savingsService = SavingsService();
  final AuthService _authService = AuthService();
  StreamSubscription<GoldRate>? _rateSub;
  GoldRate? _currentRate;

  // All streams initialised ONCE in initState() so build() always receives the
  // same stream object.  Calling getXxxStream() inside build() creates a brand-
  // new Firestore listener every time setState() triggers a rebuild; StreamBuilder
  // then cancels the old listener while Firestore delivers its last event into a
  // widget being deactivated → '_dependents.isEmpty' assertion crash.
  late final Stream<User?> _authStream;
  late final Stream<GoldSavingsAccount> _savingsAccountStream;
  late final Stream<List<GoldAsset>> _assetsStream;
  late final Stream<double> _walletStream;
  late final Stream<List<GoldTransaction>> _transactionStream;

  @override
  void initState() {
    super.initState();
    _authStream           = _authService.user;
    _savingsAccountStream = _savingsService.getGoldSavingsAccountStream();
    _assetsStream         = _tradingService.getMemberAssetsStream();
    _walletStream         = _userService.getWalletBalanceStream();
    _transactionStream    = _userService.getTransactionHistoryStream();

    _rateSub = _marketService.getGoldRateStream().listen((rate) {
      if (mounted) setState(() => _currentRate = rate);
    });
  }

  @override
  void dispose() {
    _rateSub?.cancel();
    super.dispose();
  }

  void _showTopUpDialog(BuildContext context) {
    // The controller is owned by _AmountDialog's State, so its lifecycle
    // is tied to the dialog widget. dispose() runs only AFTER the dialog's
    // exit animation finishes and the widget is fully unmounted — which
    // prevents the "TextEditingController used after being disposed" crash.
    showDialog(
      context: context,
      builder: (_) => _AmountDialog(
        title: 'เติมเงิน',
        labelText: 'จำนวนเงิน (฿)',
        confirmLabel: 'ยืนยัน',
        onConfirm: (amount) async {
          if (amount > 0) {
            await _userService.addFunds(amount);
            return true; // close the dialog
          }
          return false;
        },
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, double maxBalance) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (_) => _AmountDialog(
        title: 'ถอนเงิน',
        labelText: 'จำนวนเงิน (สูงสุด: ฿${_portFmt.format(maxBalance)})',
        confirmLabel: 'ยืนยัน',
        onConfirm: (amount) async {
          if (amount > 0 && amount <= maxBalance) {
            await _userService.withdrawFunds(amount);
            return true;
          }
          if (amount > maxBalance) {
            messenger.showSnackBar(const SnackBar(content: Text('ยอดเงินไม่เพียงพอ')));
          }
          return false;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _portBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleSpacing: 16,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_portPrimary, _portPrimaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: _portGold, size: 17),
              ),
              const SizedBox(width: 10),
              const Text('พอร์ตทองของฉัน',
                  style: TextStyle(color: _portPrimary, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _portPrimary),
              onPressed: () => setState(() {}),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: const Color(0xFFE9EAEC), height: 1),
          ),
        ),
      body: StreamBuilder<User?>(
        stream: _authStream,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _portPrimary));
          }
          if (!authSnapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(Icons.lock_rounded, size: 52, color: _portPrimary),
                  ),
                  const SizedBox(height: 24),
                  const Text('กรุณาเข้าสู่ระบบ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _portPrimary)),
                  const SizedBox(height: 8),
                  Text('เพื่อดูพอร์ตทองของคุณ', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _portPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('เข้าสู่ระบบ / สมัครสมาชิก', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<GoldSavingsAccount>(
            stream: _savingsAccountStream,
            builder: (context, savingsSnapshot) {
              if (savingsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final savingsAccount = savingsSnapshot.data ?? GoldSavingsAccount(totalWeightSaved: 0, totalAmountInvested: 0, lastUpdated: DateTime.now());

              return StreamBuilder<List<GoldAsset>>(
                stream: _assetsStream,
                builder: (context, assetSnapshot) {
                  if (assetSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final assets = assetSnapshot.data ?? [];
                  final totalWeight = assets.fold(0.0, (sum, item) => sum + item.weight) + savingsAccount.totalWeightSaved;
                  final totalValue = totalWeight * (_currentRate?.buyPrice ?? 0);
                  
                  // Calculate Profit/Loss
                  final assetsCost = assets.fold(0.0, (sum, item) => sum + item.acquisitionPrice);
                  final totalCost = assetsCost + savingsAccount.totalAmountInvested;
                  
                  final double pnl = totalValue - totalCost;
                  final double pnlPercentage = totalCost > 0 ? (pnl / totalCost) * 100 : 0.0;
                  
                  final bool isProfit = pnl >= 0;
                  final Color pnlColor = isProfit ? const Color(0xFF00C853) : const Color(0xFFD32F2F);
                  final String pnlSign = isProfit ? '+' : '';

                  return StreamBuilder<double>(
                    stream: _walletStream,
                    builder: (context, walletSnapshot) {
                  final walletBalance = walletSnapshot.data ?? 0.0;
                  
                  // Asset List preparation
                  final ownedAssets = assets.where((a) => a.status == 'owned' || a.status == 'pickup_scheduled').toList();
                  final pawnedAssets = assets.where((a) => a.status == 'pawned').toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Wallet card ───────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6))
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 16),
                                  const SizedBox(width: 6),
                                  Text('ยอดเงินในวอลเล็ต', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('฿ ${_portFmt.format(walletBalance)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _showTopUpDialog(context),
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('เติมเงิน'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF2E7D32),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: () => _showWithdrawDialog(context, walletBalance),
                                    icon: const Icon(Icons.remove_rounded, size: 16),
                                    label: const Text('ถอนเงิน'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Gold summary card ─────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_portPrimary, _portPrimaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6))
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.scale_rounded, color: Colors.white70, size: 16),
                                  const SizedBox(width: 6),
                                  Text('น้ำหนักทองสะสมรวม', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${totalWeight.toStringAsFixed(2)} บาท',
                                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              const Divider(color: Colors.white24, height: 28),
                              Text('มูลค่าประเมินรวม', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                              const SizedBox(height: 6),
                              Text('฿ ${_portFmt.format(totalValue)}',
                                  style: const TextStyle(color: _portGold, fontSize: 26, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: pnlColor, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${isProfit ? 'กำไร' : 'ขาดทุน'}: $pnlSign฿${_portFmt.format(pnl.abs())} ($pnlSign${pnlPercentage.toStringAsFixed(2)}%)',
                                      style: TextStyle(color: pnlColor, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                    
                    if (assets.isEmpty && savingsAccount.totalWeightSaved == 0) ...[
                      const _SectionHeader(title: 'สินทรัพย์ของฉัน (0)'),
                      const SizedBox(height: 12),
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('ยังไม่มีสินทรัพย์ทอง\nเริ่มซื้อเพื่อสร้างพอร์ตของคุณ!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ))
                    ] else ...[
                      if (savingsAccount.totalWeightSaved > 0) ...[
                        const _SectionHeader(title: 'รายการออมทอง'),
                        const SizedBox(height: 12),
                        _buildSavingsAssetCard(savingsAccount, _currentRate?.buyPrice ?? 40000.0),
                        const SizedBox(height: 16),
                      ],
                      if (ownedAssets.isNotEmpty) ...[
                        _SectionHeader(title: 'ทองที่เป็นเจ้าของ (${ownedAssets.length})'),
                        const SizedBox(height: 12),
                        ...ownedAssets.map((asset) => _AssetCard(asset: asset, currentRate: _currentRate)),
                      ],
                      if (pawnedAssets.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionHeader(title: 'ทองที่จำนำไว้ (${pawnedAssets.length})'),
                        const SizedBox(height: 12),
                        ...pawnedAssets.map((asset) => _AssetCard(asset: asset, currentRate: _currentRate)),
                      ],
                    ],

                    const SizedBox(height: 32),
                    
                    // Transaction History
                    const _SectionHeader(title: 'รายการล่าสุด'),
                    const SizedBox(height: 12),
                    
                    StreamBuilder<List<GoldTransaction>>(
                      stream: _transactionStream,
                      builder: (context, txSnapshot) {
                        if (txSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final transactions = txSnapshot.data ?? [];
                        if (transactions.isEmpty) {
                          return const Center(child: Text('No recent transactions', style: TextStyle(color: Colors.grey)));
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            final isBuy = tx.type == TransactionType.buy;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isBuy ? Colors.green[50] : Colors.red[50], 
                                  shape: BoxShape.circle
                                ),
                                child: Icon(
                                  isBuy ? Icons.add : Icons.remove, 
                                  color: isBuy ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                              ),
                              title: Text(tx.details),
                              subtitle: Text('${tx.timestamp.day}/${tx.timestamp.month}/${tx.timestamp.year}'),
                              trailing: Text(
                                '฿ ${tx.amount.toInt()}', 
                                style: TextStyle(fontWeight: FontWeight.bold, color: isBuy ? Colors.green : Colors.red)
                              ),
                            );
                          },
                        );
                      }
                    ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );
    },
  ),
      ),
    );
  }

  Widget _buildSavingsAssetCard(GoldSavingsAccount account, double currentBuyPrice) {
    double currentVal = account.totalWeightSaved * currentBuyPrice;
    double profit = currentVal - account.totalAmountInvested;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GoldSavingsPage()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5), // Light purple for savings
                  borderRadius: BorderRadius.circular(10)
                ),
                child: const Icon(
                  Icons.savings, 
                  color: Color(0xFF8E24AA), // Deep purple
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ออมทองปันส่วน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${account.totalWeightSaved.toStringAsFixed(4)} บาท • ลงทุนแล้ว ฿${_portFmt.format(account.totalAmountInvested)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('฿ ${currentVal.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '${profit >= 0 ? "+" : ""}฿ ${profit.toInt()}', 
                    style: TextStyle(fontSize: 12, color: profit >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable amount-entry dialog used by the top-up / withdraw flows.
///
/// The TextEditingController is owned by this State (created in initState,
/// disposed in dispose), so Flutter only releases it AFTER the dialog's
/// exit animation completes and the widget is fully unmounted. This avoids
/// the "TextEditingController was used after being disposed" assertion that
/// occurs when disposing the controller in `showDialog().then(...)` — the
/// Future there fires the moment Navigator.pop() is called, which is too
/// early.
class _AmountDialog extends StatefulWidget {
  final String title;
  final String labelText;
  final String confirmLabel;

  /// Returns true if the dialog should be popped after the action succeeds.
  final Future<bool> Function(double amount) onConfirm;

  const _AmountDialog({
    required this.title,
    required this.labelText,
    required this.confirmLabel,
    required this.onConfirm,
  });

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_isProcessing) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    // Capture Navigator before the async gap.
    final nav = Navigator.of(context);
    setState(() => _isProcessing = true);
    try {
      final shouldPop = await widget.onConfirm(amount);
      if (!mounted) return;
      if (shouldPop) {
        nav.pop();
        return; // Don't touch state after pop — widget is being unmounted.
      }
    } catch (_) {
      // Errors surface via the parent (SnackBar etc.); fall through to reset state.
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        enabled: !_isProcessing,
        decoration: InputDecoration(
          labelText: widget.labelText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _handleConfirm,
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(color: _portGold, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _portPrimary),
        ),
      ],
    );
  }
}

class _AssetCard extends StatefulWidget {
  final GoldAsset asset;
  final GoldRate? currentRate;
  const _AssetCard({required this.asset, this.currentRate});

  @override
  State<_AssetCard> createState() => _AssetCardState();
}

class _AssetCardState extends State<_AssetCard> {
  final UserService _userService = UserService();
  final TradingService _tradingService = TradingService();
  final PawnService _pawnService = PawnService();
  bool _isProcessing = false;

  // Stable stream — created once so dialog StreamBuilders don't get new
  // listener objects on every StatefulBuilder rebuild.
  late final Stream<double> _walletStream;

  @override
  void initState() {
    super.initState();
    _walletStream = _userService.getWalletBalanceStream();
  }

  void _showRedeemConfirmation(BuildContext context, double principal, double interest, double penalty, double totalOwed) {
    // Capture Navigator + Messenger BEFORE showDialog so they remain valid
    // after the await inside the confirm callback, even if the StreamBuilder
    // inside the dialog has triggered a rebuild that deactivates its context.
    final nav       = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: !_isProcessing,
      builder: (BuildContext dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            return AlertDialog(
              title: const Text('ไถ่ถอนทองจำนำ'),
              content: StreamBuilder<double>(
                stream: _walletStream,
                builder: (_, snapshot) {
                  final walletBalance = snapshot.data ?? 0.0;
                  final newBalance    = walletBalance - totalOwed;
                  final hasEnoughFunds = walletBalance >= totalOwed;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('สินค้า: ${widget.asset.name}'),
                      Text('น้ำหนัก: ${widget.asset.weight} บาท'),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('เงินต้น:'),
                        Text('฿ ${_portFmt.format(principal)}'),
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('ดอกเบี้ยปกติ:'),
                        Text('฿ ${_portFmt.format(interest)}'),
                      ]),
                      if (penalty > 0)
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('ค่าปรับล่าช้า:', style: TextStyle(color: Colors.red)),
                          Text('฿ ${_portFmt.format(penalty)}', style: const TextStyle(color: Colors.red)),
                        ]),
                      const Divider(),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('ยอดชำระรวม:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('฿ ${_portFmt.format(totalOwed)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 16),
                      if (hasEnoughFunds) ...[
                        const Text('ยอดเงินใหม่โดยประมาณ:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('฿ ${_portFmt.format(newBalance)}', style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
                      ] else
                        const Text(
                          'ยอดเงินในวอลเล็ตไม่เพียงพอสำหรับการไถ่ถอน กรุณาเติมเงิน',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                    ],
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: _isProcessing ? null : () => nav.pop(),
                  child: const Text('ยกเลิก'),
                ),
                StreamBuilder<double>(
                  stream: _walletStream,
                  builder: (_, snapshot) {
                    final hasEnoughFunds = (snapshot.data ?? 0.0) >= totalOwed;
                    return ElevatedButton(
                      onPressed: (_isProcessing || !hasEnoughFunds) ? null : () async {
                        setStateDialog(() => _isProcessing = true);
                        setState(() => _isProcessing = true);
                        bool success = false;
                        try {
                          await _pawnService.redeemAsset(asset: widget.asset, totalOwed: totalOwed);
                          success = true;
                          nav.pop();
                          messenger.showSnackBar(const SnackBar(content: Text('ไถ่ถอนสำเร็จ!')));
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
                        } finally {
                          // Only reset state on failure — on success the widget is
                          // already unmounting after nav.pop(), so calling
                          // setStateDialog() there would crash the app.
                          if (!success && mounted) {
                            setStateDialog(() => _isProcessing = false);
                            setState(() => _isProcessing = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800000)),
                      child: _isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('ยืนยันการไถ่ถอน', style: TextStyle(color: Colors.white)),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSellConfirmation(BuildContext context, double estimatedValue) {
    final nav       = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: !_isProcessing,
      builder: (BuildContext dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            return AlertDialog(
              title: const Text('ยืนยันการขาย'),
              content: StreamBuilder<double>(
                stream: _walletStream,
                builder: (_, snapshot) {
                  final walletBalance = snapshot.data ?? 0.0;
                  final newBalance    = walletBalance + estimatedValue;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('สินค้า: ${widget.asset.name}'),
                      Text('น้ำหนัก: ${widget.asset.weight} บาท'),
                      const SizedBox(height: 12),
                      const Text('มูลค่าประเมิน:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('+ ฿ ${_portFmt.format(estimatedValue)}', style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('ยอดเงินใหม่โดยประมาณ:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('฿ ${_portFmt.format(newBalance)}', style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text('คุณแน่ใจหรือไม่? ไม่สามารถยกเลิกได้หลังยืนยัน', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: _isProcessing ? null : () => nav.pop(),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: _isProcessing ? null : () async {
                    setStateDialog(() => _isProcessing = true);
                    setState(() => _isProcessing = true);
                    bool success = false;
                    try {
                      await _tradingService.sellAsset(asset: widget.asset, sellPrice: estimatedValue);
                      success = true;
                      nav.pop();
                      messenger.showSnackBar(const SnackBar(content: Text('ขายสินทรัพย์สำเร็จ!')));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
                    } finally {
                      // Only reset state on failure — on success the widget is
                      // already unmounting after nav.pop(), so calling
                      // setStateDialog() there would crash the app.
                      if (!success && mounted) {
                        setStateDialog(() => _isProcessing = false);
                        setState(() => _isProcessing = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: _isProcessing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('ยืนยันการขาย', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOwnedAssetOptions(BuildContext context, double currentVal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                // Gold accent stripe
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_portPrimary, _portGold],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                // Option 1: นัดรับทองที่ร้าน
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _portPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: _portPrimary, size: 22),
                  ),
                  title: const Text(
                    'นัดรับทองที่หน้าร้าน',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _portPrimary),
                  ),
                  subtitle: const Text(
                    'จัดการตารางนัดหมายเพื่อรับทองคำที่หน้าร้าน',
                    style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: _portPrimary),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/appointment', arguments: widget.asset);
                  },
                ),
                const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF0F0F0)),
                // Option 2: ขายสินทรัพย์ทอง
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sell_rounded, color: Color(0xFF2E7D32), size: 22),
                  ),
                  title: const Text(
                    'ขายสินทรัพย์ทองดิจิทัล',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2E7D32)),
                  ),
                  subtitle: Text(
                    'ราคาประเมิน: ฿ ${_portFmt.format(currentVal.toInt())}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF2E7D32)),
                  onTap: () {
                    Navigator.pop(context);
                    _showSellConfirmation(context, currentVal);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPawned = widget.asset.status == 'pawned';
    bool isScheduled = widget.asset.status == 'pickup_scheduled';
    double currentVal = widget.asset.weight * (widget.currentRate?.buyPrice ?? 0);
    double profit = currentVal - widget.asset.acquisitionPrice;

    // Pawn Calculations
    double principal = widget.asset.loanAmount ?? 0.0;
    DateTime pawnDate = widget.asset.pawnDate ?? DateTime.now();
    DateTime dueDate = widget.asset.dueDate ?? DateTime.now().add(const Duration(days: 30));
    double rate = widget.asset.interestRate ?? 0.0125;
    
    final owedData = _pawnService.calculatePawnOwed(principal, pawnDate, dueDate, rate);
    double totalOwed = owedData['totalOwed']!;
    double interest = owedData['standardInterest']!;
    double penalty = owedData['penaltyInterest']!;
    
    bool isOverdue = penalty > 0;
    int daysUntilDue = dueDate.difference(DateTime.now()).inDays;
    
    Color pawnColor = isOverdue ? Colors.red : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPawned ? BorderSide(color: pawnColor, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: _isProcessing 
           ? null 
           : (isPawned 
               ? () => _showRedeemConfirmation(context, principal, interest, penalty, totalOwed)
               : (isScheduled 
                    ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This asset is locked for a scheduled pickup.')))
                    : () => _showOwnedAssetOptions(context, currentVal))),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPawned ? pawnColor.withValues(alpha: 0.1) : const Color(0xFFFFF8E1), 
                  borderRadius: BorderRadius.circular(10)
                ),
                child: Icon(
                  isPawned ? (isOverdue ? Icons.warning_amber_rounded : Icons.shield) : Icons.workspace_premium, 
                  color: isPawned ? pawnColor : const Color(0xFF800000),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.asset.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (isPawned) ...[
                      if (isOverdue)
                        Text('ค้างชำระ (${-daysUntilDue} วัน)', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold))
                      else
                        Text('ครบกำหนดใน $daysUntilDue วัน', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                    ] else if (isScheduled) ...[
                      const Text('นัดรับที่ร้านแล้ว', style: TextStyle(fontSize: 12, color: Color(0xFF800000), fontWeight: FontWeight.bold)),
                    ] else
                      Text('${widget.asset.weight} บาท • ราคาขณะซื้อ ฿ ${widget.asset.acquisitionPrice.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isPawned) ...[
                    const Text('ยอดคงค้างทั้งหมด', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text('฿ ${totalOwed.toInt()}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: pawnColor)),
                  ] else ...[
                    Text('฿ ${currentVal.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '${profit >= 0 ? "+" : ""}฿ ${profit.toInt()}', 
                      style: TextStyle(fontSize: 12, color: profit >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
                    ),
                  ],
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
