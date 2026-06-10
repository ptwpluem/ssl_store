// lib/pages/member/member_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/gold_rate.dart';
import '../../services/market_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/gold_rate_card.dart';
import '../../models/news_item.dart';
import '../../widgets/news_card.dart';
import '../../widgets/store_info_card.dart';
import 'package:ssl_store/pages/member/member_catalog_page.dart';
import 'package:ssl_store/pages/member/member_trading_page.dart';
import 'package:ssl_store/pages/member/member_notifications_page.dart';
import '../../models/notification_item.dart';
import 'package:ssl_store/pages/member/member_gold_savings_page.dart';
import 'package:ssl_store/pages/member/member_buy_selection_page.dart';

// [1] Import Tools เพื่เอาไว้ใช้

// [2] กำหนดสีเอาไว้คุม Theme
const Color _homePrimary = Color(0xFF800000);
const Color _homePrimaryDark = Color(0xFF5C0000);
const Color _homeGold = Color(0xFFFFD700);
const Color _homeBg = Color(0xFFF5F7FA);

// [3] กำหนดให้เป็น StatefulWidget เพราะหน้านี้ต้องแสดงข้อมูล real-time (ราคาทอง, ข่าว)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  // [4] createState(): สร้าง State object ที่จะเก็บตัวแปรและ logic ทั้งหมด
  @override
  State<HomePage> createState() => _HomePageState();
}

// [5] ประกาศตัวแปร (instance variables)
class _HomePageState extends State<HomePage> {
  final MarketService _marketService =
      MarketService(); // final = กำหนดค่าครั้งเดียว ไม่เปลี่ยนอีก
  final NotificationService _notificationService = NotificationService();
  late Stream<GoldRate>
  _goldRateStream; // Stream<GoldRate> = "ท่อน้ำ" รอรับราคาทองแบบ real-time จาก Firestore
  late final List<Map<String, Object>>
  _menuItems; // List<Map<String, Object>> = รายการเมนู แต่ละเมนูเก็บเป็น Map (key → value)

  // [6] initState(): ทำงานครั้งเดียวตอน widget "เกิดใหม่" ก่อนวาด UI
  @override
  void initState() {
    super.initState();
    _goldRateStream = _marketService
        .getGoldRateStream(); // _menuItems = List<Map<String, Object>>: รายการเมนู 4 อัน
    _menuItems = [
      {
        'title': 'ซื้อทองจากร้าน',
        'icon': Icons.shopping_bag_outlined,
        'page': const BuySelectionPage(),
        'color': const Color(0xFFE3F2FD),
        'iconColor': const Color(0xFF1976D2),
      },
      {
        'title': 'ขายทองคืนร้าน',
        'icon': Icons.sell_outlined,
        'page': const TradingPage(initialTabIndex: 1),
        'color': const Color(0xFFE8F5E9),
        'iconColor': const Color(0xFF388E3C),
      },
      {
        'title': 'จำนำทองกับร้าน',
        'icon': Icons.account_balance_outlined,
        'page': const TradingPage(initialTabIndex: 2),
        'color': const Color(0xFFFFF3E0),
        'iconColor': const Color(0xFFF57C00),
      },
      {
        'title': 'ออมทองกับร้าน',
        'icon': Icons.savings_outlined,
        'page': const GoldSavingsPage(),
        'color': const Color(0xFFF3E5F5),
        'iconColor': const Color(0xFF8E24AA),
      },
    ];
  }

  void _navigateTo(Widget page) {
    // add "back" button on the top left
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // [10] ควบคุมสีของ status bar (แถบที่แสดงเวลา/แบตบนสุดโทรศัพท์)
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _homeBg,
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          // [12] SingleChildScrollView = ทำให้ scroll ได้ เพราะเนื้อหายาวกว่าหน้าจอ
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Gold rate card ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: StreamBuilder<GoldRate>(
                  // [13] widget พิเศษที่ "นั่งรอ" ข้อมูลจาก stream
                  stream: _goldRateStream, // ท่อข้อมูลที่เปิดไว้ใน initState
                  builder: (context, snapshot) {
                    // ทุกครั้งที่มีข้อมูลใหม่มา → Flutter เรียก builder นี้วาด UI ใหม่
                    if (snapshot.hasData) {
                      return GoldRateCard(rate: snapshot.data!);
                    }
                    return const Center(
                      child: CircularProgressIndicator(color: _homePrimary),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── Promotional banner carousel ───────────────────────────────
              SizedBox(
                height: 148,
                child: _PromotionCarousel(),
              ), // [15] _PromotionCarousel(): เรียก class ที่ 2 ที่อยู่ด้านล่างของไฟล์นี้
              const SizedBox(height: 24),

              // ── Section header: Menu ──────────────────────────────────────
              _buildSectionHeader('บริการของเรา', Icons.apps_rounded),
              const SizedBox(height: 12),

              // ── Menu cards ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _menuItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    final iconColor =
                        item['iconColor'] as Color? ?? _homePrimary;
                    final bgColor =
                        item['color'] as Color? ?? const Color(0xFFFFF8E1);

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        splashColor: _homePrimary.withValues(alpha: 0.05),
                        onTap: () {
                          // [20] ตรวจว่า item['page'] มีค่าหรือเปล่า ถ้าไม่มี (null) → แสดง SnackBar "กำลังปรับปรุง" แทน
                          if (item['page'] != null) {
                            _navigateTo(item['page'] as Widget);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: _homePrimary,
                                content: Text(
                                  'ฟังก์ชัน ${item['title']} กำลังปรับปรุงเร็วๆ นี้!',
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
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
                          child: Row(
                            children: [
                              // Left gold stripe
                              Container(
                                width: 5,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: _homeGold,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Icon
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  size: 24,
                                  color: iconColor,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Text
                              Expanded(
                                child: Text(
                                  item['title'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: _homePrimary,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Section header: News ──────────────────────────────────────
              const SizedBox(height: 28),
              _buildSectionHeader(
                'ข่าวสารและสาระน่ารู้',
                Icons.newspaper_rounded,
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StreamBuilder<List<NewsItem>>(
                  stream: _marketService.getNewsStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: _homePrimary),
                      );
                    }
                    final newsList = snapshot.data!;
                    if (newsList.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('ไม่มีข่าวสารในขณะนี้'),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: newsList.length,
                      itemBuilder: (context, index) {
                        return NewsCard(
                          newsItem: newsList[index],
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'กำลังอ่าน: ${newsList[index].title}',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Section header: Store info ────────────────────────────────
              const SizedBox(height: 28),
              _buildSectionHeader(
                'ที่ตั้งร้านของเรา',
                Icons.location_on_rounded,
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: StoreInfoCard(),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('กำลังเปิด LINE Official Account...'),
              ),
            );
          },
          backgroundColor: const Color(0xFF06C755),
          elevation: 4,
          icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
          label: const Text(
            'พูดคุยกับเรา',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    // [23] เป็นตัวช่วย Design App Bar เพราะเขียนยาวมาก
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_homePrimary, _homePrimaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_rounded, color: _homeGold, size: 19),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ห้างทองซุ่นเซ่งหลี',
                style: TextStyle(
                  color: _homePrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  height: 1.25,
                ),
              ),
              Text(
                'ทองคำบริสุทธิ์ 96.5%',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        StreamBuilder<List<NotificationItem>>(
          // [24] ดึง List<NotificationItem> แบบ real-time
          stream: _notificationService.getNotificationsStream(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.hasData
                ? snapshot.data!
                      .where((n) => !n.isRead)
                      .length // นับเฉพาะที่ยังไม่ได้อ่าน
                : 0;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_rounded,
                      color: _homePrimary,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE9EAEC), height: 1),
      ),
    );
  }

  // ─── Section header helper ────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: _homeGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: _homePrimary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _homePrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// Mock Widget for Carousel
class _PromotionCarousel extends StatefulWidget {
  // [27] ต้องเป็น StatefulWidget เพราะต้องเก็บ _currentPage (อยู่หน้า slide ที่เท่าไหร่)
  @override
  State<_PromotionCarousel> createState() => _PromotionCarouselState();
}

class _PromotionCarouselState extends State<_PromotionCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final MarketService _marketService = MarketService();

  @override // [29] dispose(): ให้ Carousel กลับมาอยู่หน้าแรกหลังจากปิด App
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _marketService.getPromotionsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final promotions = snapshot.data!;

        // Safety check to reset current page if promotions list shrinks
        if (_currentPage >= promotions.length && promotions.isNotEmpty) {
          _currentPage = promotions.length - 1;
        }

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                // slide banner
                controller:
                    _pageController, // create slide based on #promotion, change current location
                itemCount: promotions.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final promo = promotions[index];
                  return GestureDetector(
                    onTap: () {
                      final category =
                          promo['category'] as String? ?? 'catalog';
                      if (category == 'savings') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GoldSavingsPage(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CatalogPage(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Color(promo['color'] as int? ?? 0xFF800000),
                        image: promo['image'] != null
                            ? DecorationImage(
                                image: NetworkImage(promo['image'] as String),
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withValues(alpha: 0.3),
                                  BlendMode.darken,
                                ),
                              )
                            : null,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          promo['title'] as String? ?? '',
                          style: TextStyle(
                            color: Color(
                              promo['textColor'] as int? ?? 0xFFFFFFFF,
                            ),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            shadows: [
                              const Shadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(promotions.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index
                      ? 24
                      : 8, // Show wide for current
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color(0xFF800000)
                        : Colors.grey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
