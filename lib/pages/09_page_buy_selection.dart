import 'package:flutter/material.dart';
import '02_page_trading.dart';
import '10_page_catalog.dart';

class BuySelectionPage extends StatelessWidget {
  const BuySelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ซื้อทอง'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'คุณต้องการซื้ออะไร?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF800000),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'เลือกประเภททองคำที่คุณต้องการ',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            // Gold Bar Option
            _SelectionCard(
              title: 'ทองคำแท่ง',
              subtitle: '',
              description: 'ทองคำแท่งบริสุทธิ์เพื่อการลงทุน ซื้อขายตามราคาสมาคมฯ',
              icon: Icons.currency_exchange,
              backgroundColor: const Color(0xFFFFF8E1),
              iconColor: const Color(0xFFF57C00),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TradingPage(initialTabIndex: 0),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Gold Ornament Option
            _SelectionCard(
              title: 'ทองรูปพรรณ',
              subtitle: '',
              description: 'เครื่องประดับทองคำสวยงาม มีให้เลือกทั้งสร้อยคอ แหวน และอื่นๆ',
              icon: Icons.grid_view_rounded,
              backgroundColor: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1976D2),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CatalogPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF800000).withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF800000),
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A4A4A),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
