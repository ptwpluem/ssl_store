// lib/pages/member/member_portfolio_page.dart
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
  late Stream<GoldRate> _goldRateStream;
  GoldRate? _currentRate;

  @override
  void initState() {
    super.initState();
    _goldRateStream = _marketService.getGoldRateStream();
    _goldRateStream.listen((rate) {
      if (mounted) setState(() => _currentRate = rate);
    });
  }

  void _showTopUpDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('เติมเงิน'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'จำนวนเงิน (฿)', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0) {
                  await _userService.addFunds(amount);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      }
    );
  }

  void _showWithdrawDialog(BuildContext context, double maxBalance) {
    final TextEditingController amountController = TextEditingController();
    final formatter = NumberFormat('#,##0');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ถอนเงิน'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'จำนวนเงิน (สูงสุด: ฿${formatter.format(maxBalance)})', border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0 && amount <= maxBalance) {
                  await _userService.withdrawFunds(amount);
                  if (context.mounted) Navigator.pop(context);
                } else if (amount > maxBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยอดเงินไม่เพียงพอ')));
                }
              },
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      }
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
        stream: _authService.user,
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
            stream: _savingsService.getGoldSavingsAccountStream(),
            builder: (context, savingsSnapshot) {
              if (savingsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final savingsAccount = savingsSnapshot.data ?? GoldSavingsAccount(totalWeightSaved: 0, totalAmountInvested: 0, lastUpdated: DateTime.now());

              return StreamBuilder<List<GoldAsset>>(
                stream: _tradingService.getMemberAssetsStream(),
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
                  final Color pnlColor = isProfit ? const Color(0xFF00C853) : const Color(0xFFD32F2F); // High contrast Green/Red
                  final Color pnlBgColor = Colors.white; // Solid white pill background for maximum legibility
                  final String pnlSign = isProfit ? '+' : '';
                  final formatter = NumberFormat('#,##0');

                  return StreamBuilder<double>(
                    stream: _userService.getWalletBalanceStream(),
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
                              Text('฿ ${formatter.format(walletBalance)}',
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
                              Text('฿ ${formatter.format(totalValue)}',
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
                                      '${isProfit ? 'กำไร' : 'ขาดทุน'}: $pnlSign฿${formatter.format(pnl.abs())} ($pnlSign${pnlPercentage.toStringAsFixed(2)}%)',
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
                      stream: _userService.getTransactionHistoryStream(),
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
    final formatter = NumberFormat('#,##0');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
            // Navigate directly to the Savings Page if they tap this
            Navigator.pushNamed(context, '/'); // Quick hack to jump, but preferably route to GoldSavingsPage
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('จัดการที่หน้าออมทอง')));
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
                    Text('${account.totalWeightSaved.toStringAsFixed(4)} บาท • ลงทุนแล้ว ฿${formatter.format(account.totalAmountInvested)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  void _showRedeemConfirmation(BuildContext context, double principal, double interest, double penalty, double totalOwed) {
    final formatter = NumberFormat('#,##0');
    showDialog(
      context: context,
      barrierDismissible: !_isProcessing,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
             return AlertDialog(
              title: const Text('ไถ่ถอนทองจำนำ'),
              content: StreamBuilder<double>(
                stream: _userService.getWalletBalanceStream(),
                builder: (context, snapshot) {
                  final walletBalance = snapshot.data ?? 0.0;
                  final newBalance = walletBalance - totalOwed;
                  final hasEnoughFunds = walletBalance >= totalOwed;

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
                          const Text('เงินต้น:'),
                          Text('฿ ${formatter.format(principal)}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ดอกเบี้ยปกติ:'),
                          Text('฿ ${formatter.format(interest)}'),
                        ],
                      ),
                      if (penalty > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('ค่าปรับล่าช้า:', style: TextStyle(color: Colors.red)),
                            Text('฿ ${formatter.format(penalty)}', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ],
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ยอดชำระรวม:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('฿ ${formatter.format(totalOwed)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (hasEnoughFunds) ...[
                        const Text('ยอดเงินใหม่โดยประมาณ:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('฿ ${formatter.format(newBalance)}', style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
                      ] else ...[
                        const Text(
                          'ยอดเงินในวอลเล็ตไม่เพียงพอสำหรับการไถ่ถอน กรุณาเติมเงิน',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ],
                  );
                }
              ),
              actions: [
                TextButton(
                  onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                StreamBuilder<double>(
                  stream: _userService.getWalletBalanceStream(),
                  builder: (context, snapshot) {
                    final balance = snapshot.data ?? 0.0;
                    final hasEnoughFunds = balance >= totalOwed;
                    
                    return ElevatedButton(
                      onPressed: (_isProcessing || !hasEnoughFunds) ? null : () async {
                        setStateDialog(() => _isProcessing = true);
                        setState(() => _isProcessing = true);
                        
                        try {
                           await _pawnService.redeemAsset(asset: widget.asset, totalOwed: totalOwed);
                           if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไถ่ถอนสำเร็จ!')));
                           }
                        } catch (e) {
                          if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error redeeming asset: $e')));
                          }
                        } finally {
                           if (mounted) {
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
                  }
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showSellConfirmation(BuildContext context, double estimatedValue) {
    showDialog(
      context: context,
      barrierDismissible: !_isProcessing,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
             return AlertDialog(
              title: const Text('Confirm Sale'),
              content: StreamBuilder<double>(
                stream: _userService.getWalletBalanceStream(),
                builder: (context, snapshot) {
                  final walletBalance = snapshot.data ?? 0.0;
                  final newBalance = walletBalance + estimatedValue;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Asset: ${widget.asset.name}'),
                      Text('Weight: ${widget.asset.weight} Baht'),
                      const SizedBox(height: 12),
                      const Text('Estimated Value:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('+ ฿ ${estimatedValue.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('Estimated New Balance:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('฿ ${newBalance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text('Are you sure you want to sell this asset? This action cannot be undone.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  );
                }
              ),
              actions: [
                TextButton(
                  onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isProcessing ? null : () async {
                    setStateDialog(() => _isProcessing = true);
                    setState(() => _isProcessing = true);
                    
                    try {
                       await _tradingService.sellAsset(asset: widget.asset, sellPrice: estimatedValue);
                       if (context.mounted) {
                          Navigator.of(context).pop(); // Close dialog
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asset Sold Successfully!')));
                       }
                    } catch (e) {
                      if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error selling asset: $e')));
                      }
                    } finally {
                       if (mounted) {
                          setStateDialog(() => _isProcessing = false);
                          setState(() => _isProcessing = false);
                       }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: _isProcessing 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Sell', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showOwnedAssetOptions(BuildContext context, double currentVal) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 8, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: const Icon(Icons.storefront, color: Color(0xFF800000)),
                title: const Text('Pick Up Physical Gold In-Store', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Schedule an appointment to collect your gold.'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/appointment', arguments: widget.asset);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.sell, color: Colors.green),
                title: const Text('Sell Digital Gold Asset', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Estimated value: ฿ ${currentVal.toInt()}'),
                onTap: () {
                  Navigator.pop(context);
                  _showSellConfirmation(context, currentVal);
                },
              ),
              const SizedBox(height: 16),
            ],
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
