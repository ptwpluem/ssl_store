// lib/pages/member/member_buy_selection_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'member_trading_page.dart';
import 'member_catalog_page.dart';

// ─── Design tokens (matches owner dashboard) ──────────────────────────────────
const Color _primary     = Color(0xFF800000);
const Color _primaryDark = Color(0xFF5C0000);
const Color _gold        = Color(0xFFFFD700);
const Color _bgColor     = Color(0xFFF5F7FA);

class BuySelectionPage extends StatelessWidget {
  const BuySelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: _buildAppBar(context),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Gold Bar card ──────────────────────────────────────
                    _SelectionCard(
                      title: 'ทองคำแท่ง',
                      description: 'ทองคำแท่งบริสุทธิ์เพื่อการลงทุน\nซื้อขายตามราคาสมาคมฯ',
                      badge: 'ทอง 96.5%',
                      icon: Icons.currency_exchange_rounded,
                      accentColor: const Color(0xFFF57C00),
                      accentBg: const Color(0xFFFFF3E0),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TradingPage(initialTabIndex: 0),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Gold Ornament card ─────────────────────────────────
                    _SelectionCard(
                      title: 'ทองรูปพรรณ',
                      description: 'เครื่องประดับทองคำสวยงาม\nสร้อยคอ แหวน กำไล และอื่นๆ',
                      badge: 'เครื่องประดับ',
                      icon: Icons.auto_awesome_rounded,
                      accentColor: _primary,
                      accentBg: const Color(0xFFFCE8E8),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CatalogPage()),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Info footer ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _gold.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded, color: _primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'ราคาทองอ้างอิงจากสมาคมค้าทองคำ และอัปเดตแบบเรียลไทม์',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF555555), height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'ซื้อทอง',
        style: TextStyle(
          color: _primary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE9EAEC), height: 1),
      ),
    );
  }

  // ─── Decorative header banner ─────────────────────────────────────────────
  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_bag_rounded, color: _gold, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'คุณต้องการซื้ออะไร?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'เลือกประเภททองคำที่คุณต้องการ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Selection Card ───────────────────────────────────────────────────────────
class _SelectionCard extends StatelessWidget {
  final String title;
  final String description;
  final String badge;
  final IconData icon;
  final Color accentColor;
  final Color accentBg;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.description,
    required this.badge,
    required this.icon,
    required this.accentColor,
    required this.accentBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: accentColor.withValues(alpha: 0.06),
        highlightColor: accentColor.withValues(alpha: 0.03),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8E8E8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left gold accent stripe
              Container(
                width: 5,
                height: 100,
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                ),
              ),
              const SizedBox(width: 18),

              // Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 30, color: accentColor),
              ),
              const SizedBox(width: 16),

              // Text block
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7A5800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF888888),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: accentColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
