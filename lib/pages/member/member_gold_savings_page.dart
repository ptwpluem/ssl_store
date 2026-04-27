import 'package:flutter/material.dart'; // UI components
import 'package:intl/intl.dart'; // format number
import 'package:firebase_auth/firebase_auth.dart'; // authentication
import '../../services/auth_service.dart'; // authentication service
import '../../models/gold_rate.dart'; // gold rate model
import '../../models/gold_savings.dart'; // gold savings model
import '../../services/market_service.dart';
import '../../services/user_service.dart';
import '../../services/savings_service.dart';
import '../../models/gold_asset.dart';
import 'member_appointment_page.dart';

class GoldSavingsPage extends StatefulWidget {
  const GoldSavingsPage({super.key});

  @override
  State<GoldSavingsPage> createState() => _GoldSavingsPageState();
}

class _GoldSavingsPageState extends State<GoldSavingsPage> {
  final MarketService _marketService = MarketService();
  final UserService _userService = UserService();
  final SavingsService _savingsService = SavingsService();
  final AuthService _authService = AuthService();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  void _deposit(double currentBuyPrice, double amount) async { // deposit gold to savings
    if (amount <= 0) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _savingsService.depositToGoldSavings(amount, currentBuyPrice);
      
      if (!mounted) return;
      
      _amountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ออมทองสำเร็จ จำนวน ฿${NumberFormat('#,##0').format(amount)}!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _withdraw(double currentSellPrice, double weightToSell) async { // withdraw gold from savings
    if (weightToSell <= 0) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _savingsService.sellFromGoldSavings(weightToSell, currentSellPrice);
      
      if (!mounted) return;
      
      _amountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ขายทองสำเร็จ จำนวน ${weightToSell.toStringAsFixed(4)} บาท',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _withdrawPhysical(double currentBuyPrice, double weightToWithdraw) async {
    final premiumFee = weightToWithdraw * 300; // Example: 300 THB per Baht for premium
    
    setState(() {
      _isLoading = true;
    });

    try {
      final assetId = await _savingsService.withdrawPhysicalGoldBar(weightToWithdraw, currentBuyPrice, premiumFee);
      
      if (!mounted) return;

      // Create a temporary asset object to pass to the scheduling page
      final newAsset = GoldAsset(
        id: assetId,
        name: 'ทองคำแท่ง ($weightToWithdraw บาท)',
        weight: weightToWithdraw,
        category: 'ทองคำแท่ง',
        acquisitionDate: DateTime.now(),
        acquisitionPrice: weightToWithdraw * currentBuyPrice,
        status: 'owned',
        purity: 0.965,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ถอนทองแท่ง ${weightToWithdraw.toStringAsFixed(4)} บาท สำเร็จ! กำลังพาไปหน้านัดหมาย...',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Wait a bit for the snackbar to be seen
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AppointmentPage(),
          settings: RouteSettings(arguments: newAsset),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDepositSheet(double currentBuyPrice) { // show deposit sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ออมทองเพิ่ม',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF800000),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ราคาทองวันนี้: ฿${NumberFormat('#,##0').format(currentBuyPrice)} / บาท',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextField( // input amount to deposit
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'ระบุจำนวนเงิน (บาท)',
                        prefixIcon: const Icon(
                          Icons.account_balance_wallet,
                          color: Color(0xFF800000),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF800000),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF800000),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (val) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildQuickAmountButton(100, setSheetState),
                        const SizedBox(width: 8),
                        _buildQuickAmountButton(500, setSheetState),
                        const SizedBox(width: 8),
                        _buildQuickAmountButton(1000, setSheetState),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Calculation preview
                    Builder(
                      builder: (context) {
                        final val =
                            double.tryParse(
                              _amountController.text.replaceAll(',', ''),
                            ) ??
                            0;
                        final weight = val / currentBuyPrice;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Est. Weight Gained:'),
                              Text(
                                '${weight.toStringAsFixed(4)} Baht',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF800000),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF800000),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              final amount =
                                  double.tryParse(
                                    _amountController.text.replaceAll(',', ''),
                                  ) ??
                                  0;
                              if (amount > 0) {
                                Navigator.pop(context); // close sheet
                                _deposit(currentBuyPrice, amount);
                              }
                            },
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'ยืนยันการออม',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickAmountButton(double amount, StateSetter setSheetState) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF800000),
          side: const BorderSide(color: Color(0xFF800000)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          setSheetState(() {
            // Assuming 'amount' here is always a fixed value like 100, 500, 1000
            // If 'amount' could be double.infinity for a 'MAX' button,
            // you would need to fetch the actual max balance here.
            // For now, we'll just apply the NumberFormat to the existing logic.
            final currentVal =
                double.tryParse(_amountController.text.replaceAll(',', '')) ??
                0.0;
            _amountController.text = NumberFormat(
              '#,##0',
            ).format(currentVal + amount);
          });
        },
        child: Text('+฿${NumberFormat('#,##0').format(amount)}'),
      ),
    );
  }

  void _showWithdrawSheet(double currentSellPrice, double currentSavedWeight) { // show withdraw sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ขายทองที่สะสม',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5), // Blue for sell
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ราคารับซื้อคืน: ฿${NumberFormat('#,##0').format(currentSellPrice)} / บาท',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ทองที่ถอนได้: ${currentSavedWeight.toStringAsFixed(4)} บาท',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'น้ำหนักทองที่ต้องการขาย (บาท)',
                        prefixIcon: const Icon(
                          Icons.fitness_center,
                          color: Color(0xFF1E88E5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1E88E5),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (val) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildQuickWeightButton(0.25, setSheetState),
                        const SizedBox(width: 8),
                        _buildQuickWeightButton(0.5, setSheetState),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E88E5),
                              side: const BorderSide(color: Color(0xFF1E88E5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              setSheetState(() {
                                _amountController.text = currentSavedWeight
                                    .toString();
                              });
                            },
                            child: const Text('MAX'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Calculation preview
                    Builder(
                      builder: (context) {
                        final val =
                            double.tryParse(
                              _amountController.text.replaceAll(',', ''),
                            ) ??
                            0;
                        final cash = val * currentSellPrice;
                        final isOverLimit = val > currentSavedWeight;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isOverLimit
                                ? Colors.red.shade50
                                : const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isOverLimit
                                  ? Colors.red
                                  : const Color(0xFF64B5F6).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isOverLimit
                                    ? 'Exceeds balance'
                                    : 'Est. Cash Returned:',
                              ),
                              if (!isOverLimit)
                                Text(
                                  '+฿${NumberFormat('#,##0.00').format(cash)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E88E5),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              final val =
                                  double.tryParse(
                                    _amountController.text.replaceAll(',', ''),
                                  ) ??
                                  0;
                              if (val > 0 && val <= currentSavedWeight) {
                                Navigator.pop(context); // close sheet
                                _withdraw(currentSellPrice, val);
                              } else if (val > currentSavedWeight && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'ไม่สามารถขายเกินจำนวนทองที่มีได้',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'ยืนยันการขาย',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickWeightButton(double weight, StateSetter setSheetState) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1E88E5),
          side: const BorderSide(color: Color(0xFF1E88E5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          setSheetState(() {
            _amountController.text = weight.toString();
          });
        },
        child: Text('${weight}B'),
      ),
    );
  }

  void _showPhysicalWithdrawSheet(double currentBuyPrice, double currentSavedWeight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ถอนทองแท่ง (รับทองจริง)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100), // Orange/Gold for physical
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'คุณมีทองสะสมทั้งหมด: ${currentSavedWeight.toStringAsFixed(4)} บาท',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '* สามารถถอนได้เป็นทวีคูณของ 0.25 บาท',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              
              // Withdrawal Options
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [0.25, 0.5, 1.0, 2.0].where((w) => w <= currentSavedWeight).map((w) {
                  final fee = w * 300;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _withdrawPhysical(currentBuyPrice, w);
                    },
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 60) / 2,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE65100)),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFFFF3E0),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$w บาท',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ค่าธรรมเนียม: ฿${NumberFormat('#,##0').format(fee)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (currentSavedWeight < 0.25)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'ยอดสะสมของคุณยังไม่ถึงเกณฑ์ขั้นต่ำ (0.25 บาท)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  @override // build UI for gold savings page
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('บัญชีออมทอง'),
        actions: [
          StreamBuilder<double>(
            stream: _userService.getWalletBalanceStream(),
            builder: (context, snapshot) {
              final balance = snapshot.data ?? 0.0;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    '฿${NumberFormat('#,##0.00').format(balance)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF800000),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: StreamBuilder<User?>( // check user login
        stream: _authService.user,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!authSnapshot.hasData) {
            return Container(
              color: const Color(0xFFFFF8E1),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'กรุณาเข้าสู่ระบบเพื่อใช้งานบัญชีออมทอง',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF800000),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('เข้าสู่ระบบ / สมัครสมาชิก'),
                    ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: StreamBuilder<GoldRate>(
                  stream: _marketService.getGoldRateStream(),
                  builder: (context, rateSnapshot) {
                    return StreamBuilder<GoldSavingsAccount>(
                      stream: _savingsService.getGoldSavingsAccountStream(),
                      builder: (context, accountSnapshot) {
                        final currentBuyPrice =
                            rateSnapshot.data?.buyPrice ?? 40000.0;
                        final currentSellPrice =
                            rateSnapshot.data?.sellPrice ?? 39900.0;
                        final account =
                            accountSnapshot.data ??
                            GoldSavingsAccount(
                              totalWeightSaved: 0,
                              totalAmountInvested: 0,
                              lastUpdated: DateTime.now(),
                            );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDashboardHeader(account, currentBuyPrice),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF800000,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        elevation: 4,
                                        shadowColor: const Color(
                                          0xFF800000,
                                        ).withValues(alpha: 0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      label: const Text(
                                        'เริ่มออมทอง',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showDepositSheet(currentBuyPrice),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(
                                          0xFF1E88E5,
                                        ), // Blue for sell
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        elevation: 4,
                                        shadowColor: Colors.black.withValues(alpha: 
                                          0.1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          side: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      label: const Text(
                                        'ขายทองสะสม',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () => _showWithdrawSheet(
                                        currentSellPrice,
                                        account.totalWeightSaved,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // New Withdrawal Button
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE65100), // Physical gold color
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.inventory_2_outlined),
                                label: const Text(
                                  'รับทองจริง (ถอนทองแท่ง)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: account.totalWeightSaved >= 0.25
                                    ? () => _showPhysicalWithdrawSheet(currentBuyPrice, account.totalWeightSaved)
                                    : null,
                              ),
                            ),

                            // Stats Card
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      'ยอดเงินสะสม',
                                      '฿${NumberFormat('#,##0').format(account.totalAmountInvested)}',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStatCard(
                                      'มูลค่าทองปัจจุบัน',
                                      '฿${NumberFormat('#,##0').format(account.totalWeightSaved * currentBuyPrice)}',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.only(
                                left: 24,
                                top: 32,
                                bottom: 12,
                              ),
                              child: Text(
                                'TRANSACTION HISTORY',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              StreamBuilder<List<GoldSavingsTransaction>>(
                stream: _savingsService.getGoldSavingsTransactionsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final txs = snapshot.data ?? [];

                  if (txs.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.savings_outlined,
                              size: 64,
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'ยังไม่มีประวัติการออมทอง',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final tx = txs[index];
                        final isDeposit = tx.amountInvested > 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDeposit
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isDeposit
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isDeposit
                                      ? const Color(0xFF388E3C)
                                      : const Color(0xFFF57C00),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDeposit ? 'ออมทอง' : 'ขายทอง',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy, HH:mm',
                                      ).format(tx.timestamp),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isDeposit ? '+' : ''}${tx.weightGained.toStringAsFixed(4)} บาท',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDeposit
                                          ? const Color(0xFF388E3C)
                                          : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${isDeposit ? '-' : '+'}฿${NumberFormat('#,##0').format(tx.amountInvested.abs())}',
                                    style: TextStyle(
                                      color: isDeposit
                                          ? Colors.grey
                                          : const Color(0xFF1E88E5),
                                      fontWeight: isDeposit
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }, childCount: txs.length),
                    ),
                  );
                },
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardHeader(
    GoldSavingsAccount account,
    double currentBuyPrice,
  ) {
    // Goal logic: Target is 1 Baht
    const double targetWeight = 1.0;
    final double progress = (account.totalWeightSaved / targetWeight).clamp(
      0.0,
      1.0,
    );

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF800000).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'ทองที่สะสมได้',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: const Color(0xFFF0F0F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFD700),
                  ), // Gold
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    account.totalWeightSaved.toStringAsFixed(4),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF800000),
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'บาท',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% ของเป้าหมาย 1 บาท',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF800000),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF800000),
            ),
          ),
        ],
      ),
    );
  }
}
