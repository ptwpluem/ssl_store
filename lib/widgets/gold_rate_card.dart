import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gold_rate.dart';

class GoldRateCard extends StatelessWidget {
  final GoldRate rate; // รับ Rate มาจาก Parent

  const GoldRateCard({super.key, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF800000), // Deep Red
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700),
          width: 3,
        ), // Gold Border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFFFD700), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ราคาทองวันนี้ (96.5%)',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier', // Monospace for digital look
                  ),
                ),
              ],
            ),
          ),

          // Prices
          Row(
            children: [
              Expanded(
                child: _buildPriceColumn('ราคารับซื้อ', rate.buyPrice),
              ), // ราคาซื้อรับค่ามาจาก model_gold_rate
              Container(width: 2, height: 60, color: const Color(0xFFFFD700)),
              Expanded(
                child: _buildPriceColumn('ราคาขายออก', rate.sellPrice),
              ), // ราคาขายรับค่ามาจาก model_gold_rate
            ],
          ),

          const SizedBox(height: 12),
          Text(
            'อัปเดตล่าสุด: ${DateFormat('HH:mm').format(rate.timestamp)} น.',
            style: const TextStyle(color: Color(0xFFFFE0B2), fontSize: 14),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildPriceColumn(String label, double price) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          NumberFormat('#,##0').format(price),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier', // LED style
            letterSpacing: 2,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Color(0xFFFFD700),
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
