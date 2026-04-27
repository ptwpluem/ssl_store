import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/user_service.dart';
import '../../models/gold_transaction.dart';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('ประวัติการทำรายการ'),
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<GoldTransaction>>(
        stream: UserService().getTransactionHistoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF800000)),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final transactions = snapshot.data ?? [];
          if (transactions.isEmpty) {
            return const Center(
              child: Text(
                'ไม่พบประวัติการทำรายการ',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _buildTransactionCard(tx);
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(GoldTransaction tx) {
    Color iconColor;
    IconData iconData;
    String amountPrefix = '';
    Color amountColor = Colors.black;

    switch (tx.type) {
      case TransactionType.buy:
        iconColor = Colors.green.shade600;
        iconData = Icons.call_received;
        amountPrefix = '-';
        amountColor = Colors.red.shade700; // Deducted from wallet
        break;
      case TransactionType.sell:
        iconColor = Colors.blue.shade600;
        iconData = Icons.call_made;
        amountPrefix = '+';
        amountColor = Colors.green.shade700; // Added to wallet
        break;
      case TransactionType.pawn:
        iconColor = Colors.orange.shade600;
        iconData = Icons.account_balance;
        amountPrefix = '+';
        amountColor = Colors.green.shade700; // Loan added to wallet
        break;
      case TransactionType.redeem:
        iconColor = Colors.purple.shade600;
        iconData = Icons.payments;
        amountPrefix = '-';
        amountColor = Colors.red.shade700; // Cash paid to redeem
        break;
      case TransactionType.savings_deposit:
        iconColor = Colors.teal.shade600;
        iconData = Icons.savings;
        amountPrefix = '-';
        amountColor = Colors.red.shade700; // Deducted from wallet
        break;
      case TransactionType.savings_withdraw:
        iconColor = Colors.teal.shade600;
        iconData = Icons.savings;
        amountPrefix = '+';
        amountColor = Colors.green.shade700; // Added to wallet
        break;
      case TransactionType.savings_physical_withdraw:
        iconColor = Colors.orange.shade800;
        iconData = Icons.inventory_2;
        amountPrefix = '-';
        amountColor = Colors.red.shade700; // Deducted fee from wallet
        break;
    }

    final dateFormat = DateFormat('dd MMM yyyy • HH:mm น.');
    final currencyFormat = NumberFormat.currency(locale: 'th_TH', symbol: '฿');

    String typeLabel = '';
    switch (tx.type) {
      case TransactionType.buy: typeLabel = 'ซื้อทอง'; break;
      case TransactionType.sell: typeLabel = 'ขายคืน'; break;
      case TransactionType.pawn: typeLabel = 'จำนำ'; break;
      case TransactionType.redeem: typeLabel = 'ไถ่ถอน'; break;
      case TransactionType.savings_deposit: typeLabel = 'ออมทอง (ฝาก)'; break;
      case TransactionType.savings_withdraw: typeLabel = 'ออมทอง (ถอน)'; break;
      case TransactionType.savings_physical_withdraw: typeLabel = 'ถอนทองแท่ง'; break;
    }

    return Container(
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
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tx.details,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(tx.timestamp),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$amountPrefix${currencyFormat.format(tx.amount)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
