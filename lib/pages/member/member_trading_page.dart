import 'package:flutter/material.dart';
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

class TradingPage extends StatefulWidget {
  final int initialTabIndex;
  const TradingPage({super.key, this.initialTabIndex = 0});

  @override
  State<TradingPage> createState() => _TradingPageState();
}

class _TradingPageState extends State<TradingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MarketService _marketService = MarketService();
  final UserService _userService = UserService();
  final TradingService _tradingService = TradingService();
  final PawnService _pawnService = PawnService();
  final AuthService _authService = AuthService();
  late Stream<GoldRate> _goldRateStream;
  GoldRate? _currentRate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _goldRateStream = _marketService.getGoldRateStream();
    _goldRateStream.listen((rate) {
      if (mounted) setState(() => _currentRate = rate);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.user,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!authSnapshot.hasData) {
           return Scaffold(
            appBar: AppBar(title: const Text('ซื้อ-ขาย และบริการ')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text('กรุณาเข้าสู่ระบบเพื่อใช้งานส่วนซื้อ-ขาย และบริการ', style: TextStyle(fontSize: 18)),
                   const SizedBox(height: 24),
                   ElevatedButton(
                     onPressed: () => Navigator.pushNamed(context, '/login'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF800000),
                       foregroundColor: Colors.white,
                     ),
                     child: const Text('เข้าสู่ระบบ / สมัครสมาชิก'),
                   )
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('ซื้อ-ขาย และบริการ'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'ซื้อ', icon: Icon(Icons.shopping_cart)),
                Tab(text: 'ขาย', icon: Icon(Icons.sell)),
                Tab(text: 'จำนำ', icon: Icon(Icons.account_balance_wallet)),
              ],
              labelColor: const Color(0xFFFFD700),
              unselectedLabelColor: Colors.white70,
              indicatorColor: const Color(0xFFFFD700),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _currentRate != null 
                  ? GoldRateCard(rate: _currentRate!)
                  : const Center(child: CircularProgressIndicator()),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _BuyTab(userService: _userService, tradingService: _tradingService, currentRate: _currentRate),
                    _SellTab(userService: _userService, tradingService: _tradingService, currentRate: _currentRate),
                    _PawnTab(userService: _userService, tradingService: _tradingService, pawnService: _pawnService, currentRate: _currentRate),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

// -- Buy Tab --
class _BuyTab extends StatefulWidget {
  final UserService userService;
  final TradingService tradingService;
  final GoldRate? currentRate;
  const _BuyTab({required this.userService, required this.tradingService, this.currentRate});

  @override
  State<_BuyTab> createState() => _BuyTabState();
}

class _BuyTabState extends State<_BuyTab> {
  double _weight = 1.0;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.currentRate == null) return const Center(child: CircularProgressIndicator());
    
    double total = _weight * widget.currentRate!.sellPrice;
    final formatter = NumberFormat('#,##0');

    return StreamBuilder<double>(
      stream: widget.userService.getWalletBalanceStream(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0.0;
        final hasEnoughFunds = balance >= total;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wallet Balance Header
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD700)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ยอดเงินในวอลเล็ต:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('฿ ${formatter.format(balance)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                    ],
                  ),
                ),
              ),

          const Text('เลือกน้ำหนัก (บาท)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Slider(
            value: _weight,
            min: 0.25,
            max: 10,
            divisions: 39,
            label: '$_weight บาท',
            activeColor: const Color(0xFF800000),
            onChanged: (val) => setState(() => _weight = val),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$_weight บาท', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF800000))),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF800000).withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Text('สรุปรายการ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF600000))),
                const SizedBox(height: 16),
                _rowItem('ราคาขายออก', '฿ ${formatter.format(widget.currentRate!.sellPrice)} / บาท'),
                const Divider(),
                _rowItem('ยอดรวมทั้งหมด', '฿ ${formatter.format(total)}', isBold: true),
                if (balance >= total)
                  _rowItem('ยอดเงินคงเหลือโดยประมาณ', '฿ ${formatter.format(balance - total)}', isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 48),
          if (!hasEnoughFunds)
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'ยอดเงินไม่เพียงพอ กรุณาเติมเงินที่หน้าโปรไฟล์หรือทองของฉัน',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ElevatedButton(
            onPressed: (_isProcessing || !hasEnoughFunds) ? null : () async {
              setState(() => _isProcessing = true);
                try {
                  String? productId;
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
                    assetName: 'ทองคำแท่ง ($_weight บาท)',
                    weight: _weight,
                    amount: total,
                    category: 'Gold Bar',
                    productId: productId,
                  );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('การสั่งซื้อสำเร็จ!')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isProcessing = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: hasEnoughFunds ? const Color(0xFF800000) : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing 
              ? const CircularProgressIndicator(color: Colors.white) 
              : const Text('ยืนยันการซื้อ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _rowItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// -- Sell Tab --
class _SellTab extends StatefulWidget {
  final UserService userService;
  final TradingService tradingService;
  final GoldRate? currentRate;
  const _SellTab({required this.userService, required this.tradingService, this.currentRate});

  @override
  State<_SellTab> createState() => _SellTabState();
}

class _SellTabState extends State<_SellTab> {
  bool _isProcessing = false;

  void _showSellConfirmation(BuildContext context, GoldAsset asset, double estimatedValue) {
    final formatter = NumberFormat('#,##0');
    showDialog(
      context: context,
      barrierDismissible: !_isProcessing,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
             return AlertDialog(
              title: const Text('ยืนยันการขาย'),
              content: StreamBuilder<double>(
                stream: widget.userService.getWalletBalanceStream(),
                builder: (context, snapshot) {
                  final walletBalance = snapshot.data ?? 0.0;
                  final newBalance = walletBalance + estimatedValue;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('สินค้า: ${asset.name}'),
                      Text('น้ำหนัก: ${asset.weight} บาท'),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('โอนเงินเข้าวอลเล็ต:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('+ ฿ ${formatter.format(estimatedValue)}', style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('ยอดเงินใหม่ในวอลเล็ต:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('฿ ${formatter.format(newBalance)}', style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 16),
                      const Text('คุณแน่ใจหรือไม่ว่าต้องการขายสินค้าชิ้นนี้? ไม่สามารถยกเลิกรายการได้หลังการยืนยัน', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                    setState(() => _isProcessing = true); // Update underlying tab state too (optional, for safety)
                    
                     try {
                       await widget.tradingService.sellAsset(asset: asset, sellPrice: estimatedValue);
                       if (context.mounted) {
                          Navigator.of(context).pop(); // Close dialog
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ขายสินค้าสำเร็จเรียบร้อยแล้ว!')));
                       }
                    } catch (e) {
                      if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการขายสินค้า: $e')));
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
                    : const Text('ยืนยันการขาย', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0');
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('ไม่มีสินค้าที่สามารถขายได้', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            final estimatedValue = asset.weight * (widget.currentRate?.buyPrice ?? 0);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFFD700), child: Icon(Icons.sell, color: Color(0xFF800000))),
                title: Text(asset.name),
                subtitle: Text('${asset.weight} บาท'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('ราคารับซื้อโดยประมาณ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('฿ ${formatter.format(estimatedValue)}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                onTap: _isProcessing ? null : () => _showSellConfirmation(context, asset, estimatedValue),
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
  const _PawnTab({required this.userService, required this.tradingService, required this.pawnService, this.currentRate});

  @override
  State<_PawnTab> createState() => _PawnTabState();
}

class _PawnTabState extends State<_PawnTab> {
  bool _isProcessing = false;

  void _showPawnConfirmation(BuildContext context, GoldAsset asset, double maxLoan) {
    double requestedLoan = maxLoan;
    final formatter = NumberFormat('#,##0');
    final TextEditingController _loanController = TextEditingController(text: maxLoan.toStringAsFixed(0));

    showDialog(
      context: context,
      barrierDismissible: !_isProcessing,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
             bool isValid = requestedLoan > 0 && requestedLoan <= maxLoan;
             
             return AlertDialog(
              title: const Text('ยืนยันการจำนำ'),
              content: StreamBuilder<double>(
                stream: widget.userService.getWalletBalanceStream(),
                builder: (context, snapshot) {
                  final walletBalance = snapshot.data ?? 0.0;
                  final newBalance = walletBalance + (isValid ? requestedLoan : 0);
                  
                  final dueDate = DateTime.now().add(const Duration(days: 30));
                  final formattedDate = '${dueDate.day}/${dueDate.month}/${dueDate.year}';

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('สินค้า: ${asset.name}'),
                        Text('น้ำหนัก: ${asset.weight} บาท'),
                        const SizedBox(height: 12),
                        const Text('ระบุวงเงินที่ต้องการกู้ (บาท):', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _loanController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'วงเงินที่ต้องการ (฿)',
                            border: const OutlineInputBorder(),
                            suffixText: 'กู้ได้สูงสุด: ${formatter.format(maxLoan)}',
                            errorText: (!isValid && _loanController.text.isNotEmpty) ? 'วงเงินต้องอยู่ระหว่าง 1 ถึง ${formatter.format(maxLoan)}' : null,
                          ),
                          onChanged: (val) {
                            setStateDialog(() {
                              requestedLoan = double.tryParse(val) ?? 0.0;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('โอนเงินเข้าวอลเล็ต:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('+ ฿ ${formatter.format(requestedLoan)}', style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('ยอดเงินใหม่ในวอลเล็ต:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('฿ ${formatter.format(newBalance)}', style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.orange[50],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ครบกำหนดชำระ: $formattedDate (30 วัน)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                              const Text('อัตราดอกเบี้ย 1.25% ต่อเดือน. หากชำระล่าช้าจะมีค่าปรับ 2% ต่อเดือน.', style: TextStyle(fontSize: 10, color: Colors.black87)),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                }
              ),
              actions: [
                TextButton(
                  onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: (_isProcessing || !isValid) ? null : () async {
                    setStateDialog(() => _isProcessing = true);
                    setState(() => _isProcessing = true);
                    
                    try {
                       await widget.pawnService.pawnAsset(asset: asset, loanAmount: requestedLoan);
                       if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('จำนำสินค้าสำเร็จ! เพิ่มเงิน ฿${formatter.format(requestedLoan)} เข้าวอลเล็ตแล้ว')));
                       }
                    } catch (e) {
                      if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error pawning asset: $e')));
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
                    : const Text('ยืนยันการจำนำ', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFFFF8E1),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF800000)),
              SizedBox(width: 12),
              Expanded(child: Text('อัตราดอกเบี้ย: 1.25% ต่อเดือน. กู้ได้สูงสุด 85% ของราคารับซื้อ.', style: TextStyle(fontSize: 12))),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<GoldAsset>>(
            stream: widget.tradingService.getMemberAssetsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final allAssets = snapshot.data ?? [];
              final ownedAssets = allAssets.where((a) => a.status == 'owned').toList();

              if (ownedAssets.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('คุณไม่มีทรัพย์สินที่เป็นเจ้าของเต็มจำนวนที่สามารถนำมาจำนำได้', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ownedAssets.length,
                itemBuilder: (context, index) {
                  final asset = ownedAssets[index];
                  final currentVal = asset.weight * (widget.currentRate?.buyPrice ?? 0);
                  final maxLoan = widget.pawnService.calculatePawnLoan(asset.weight, widget.currentRate?.buyPrice ?? 0);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFFFF8E1), child: Icon(Icons.shield, color: Color(0xFF800000))),
                      title: Text(asset.name),
                      subtitle: Text('${asset.weight} บาท • ประเมินราคาที่ ฿${currentVal.toInt()}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('วงเงินสูงสุด:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text('฿ ${formatter.format(maxLoan)}', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                        ],
                      ),
                      onTap: _isProcessing ? null : () => _showPawnConfirmation(context, asset, maxLoan),
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
