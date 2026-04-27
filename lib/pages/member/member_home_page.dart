import 'package:flutter/material.dart';
import '../../models/gold_rate.dart';
import '../../services/market_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/gold_rate_card.dart';
import '../../models/news_item.dart';
import '../../widgets/news_card.dart';
import '../../widgets/store_info_card.dart';
import 'package:ssl_store/pages/member/member_catalog_page.dart';
import 'package:ssl_store/pages/member/member_profile_page.dart';
import 'package:ssl_store/pages/member/member_inquiry_page.dart';
import 'package:ssl_store/pages/member/member_trading_page.dart';
import 'package:ssl_store/pages/member/member_notifications_page.dart';
import '../../models/notification_item.dart';
import 'package:ssl_store/pages/member/member_gold_savings_page.dart';
import 'package:ssl_store/pages/member/member_buy_selection_page.dart';

class HomePage extends StatefulWidget {
  // Make the page is interactive such as gold prive updates, notifications, slide banner
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MarketService _marketService = MarketService();
  final NotificationService _notificationService = NotificationService();
  late Stream<GoldRate> _goldRateStream;

  @override
  void initState() {
    // load data for home page when 1st open
    super.initState();
    _goldRateStream = _marketService.getGoldRateStream();
  }

  void _navigateTo(Widget page) {
    // add "back" button on the top left
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override // build UI for home page
  Widget build(BuildContext context) {
    final menuItems = [ // menu items for home page
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

    return Scaffold( // page main frame (top bar, main content, floating button)
      appBar: AppBar(
        title: const Text('ห้างทองสุ้นเซ่งหลี'),
        centerTitle: true,
        actions: [
          StreamBuilder<List<NotificationItem>>( // notification icon with badge
            stream: _notificationService.getNotificationsStream(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                unreadCount = snapshot.data!.where((n) => !n.isRead).length;
              }
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF800000), width: 1.5),
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
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        // Changed to ScrollView to fit banner
        child: Padding(
          padding: const EdgeInsets.all(16), // page margin
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Real-time Gold Rate
              StreamBuilder<GoldRate>(
                stream: _goldRateStream,
                builder: (context, snapshot) {
                  // if has the value then shows, else load
                  if (snapshot.hasData) {
                    return GoldRateCard(rate: snapshot.data!);
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
              const SizedBox(height: 20),

              // Promotional Banner Carousel
              SizedBox(
                height: 140, // Slightly increased height for indicators
                child: _PromotionCarousel(),
              ),
              const SizedBox(height: 24),

              const Text(
                'เมนู',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF800000),
                ),
              ),
              const SizedBox(height: 12),

              ListView.separated( // create a menu list
                shrinkWrap: true, // Important for SingleChildScrollView
                physics: const NeverScrollableScrollPhysics(),
                itemCount: menuItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  final titleParts = (item['title'] as String).split('\n');
                  
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      // When tab, go to new page, or shows "coming soon"
                      if (item['page'] != null) {
                        _navigateTo(item['page'] as Widget);
                      } else {
                        // For placeholder
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF800000),
                            content: Text(
                              'ฟังก์ชัน ${item['title']} กำลังปรับปรุงเร็วๆ นี้!',
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF800000).withValues(alpha: 0.1),
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
                              shape: BoxShape.circle,
                              color: item['color'] as Color? ?? const Color(0xFFFFF8E1),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              size: 28,
                              color: item['iconColor'] as Color? ?? const Color(0xFF800000),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titleParts[0],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF800000),
                                  ),
                                ),
                                if (titleParts.length > 1) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    titleParts[1],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF4A4A4A),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // News Section
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'ข่าวสารและสาระน่ารู้',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF800000),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              StreamBuilder<List<NewsItem>>(
                stream: _marketService.getNewsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
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
                              content: Text('กำลังอ่าน: ${newsList[index].title}'),
                            ), 
                          );
                        },
                      );
                    },
                  );
                },
              ),
              //  Store Info
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'ที่ตั้งร้านของเรา',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF800000),
                  ),
                ),
              ),
              const StoreInfoCard(),

              const SizedBox(
                height: 80,
              ), // Extra padding for FAB (FloatingActionButton)
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Set Chat with Us Line at the bottom right
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กำลังเปิด LINE Official Account...')),
          );
        },
        backgroundColor: const Color(0xFF06C755), // LINE Green
        icon: const Icon(Icons.chat_bubble, color: Colors.white),
        label: const Text(
          'พูดคุยกับเรา',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// Mock Widget for Carousel
class _PromotionCarousel extends StatefulWidget {
  @override
  State<_PromotionCarousel> createState() => _PromotionCarouselState();
}

class _PromotionCarouselState extends State<_PromotionCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final MarketService _marketService = MarketService();

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
              child: PageView.builder( // slide banner
                controller: _pageController, // create slide based on #promotion, change current location
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
                      final category = promo['category'] as String? ?? 'catalog';
                      if (category == 'savings') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const GoldSavingsPage()));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogPage()));
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
                            color: Color(promo['textColor'] as int? ?? 0xFFFFFFFF),
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
                  width: _currentPage == index ? 24 : 8, // Show wide for current
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
