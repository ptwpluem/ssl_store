import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/gold_rate.dart';
import '../../services/catalog_service.dart';
import '../../services/market_service.dart';
import '../../widgets/product_card.dart';
import 'member_product_detail_page.dart';

// ─── Design tokens (matches owner dashboard) ──────────────────────────────────
const Color _primary     = Color(0xFF800000);
const Color _primaryDark = Color(0xFF5C0000);
const Color _gold        = Color(0xFFFFD700);
const Color _bgColor     = Color(0xFFF5F7FA);

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final CatalogService _catalogService = CatalogService();
  final MarketService _marketService = MarketService();
  StreamSubscription<GoldRate>? _rateSub;
  late Stream<List<Product>> _productsStream;
  GoldRate? _currentRate;

  String _searchQuery = '';
  String _selectedCategory = 'ทั้งหมด';
  final Map<String, String> _categories = {
    'ทั้งหมด': 'All',
    'สร้อยคอ': 'สร้อยคอ',
    'แหวน': 'แหวน',
    'สร้อยข้อมือ': 'สร้อยข้อมือ',
    'ต่างหู': 'ต่างหู',
    'ทองคำแท่ง': 'ทองคำแท่ง',
  };

  @override
  void initState() {
    super.initState();
    _productsStream = _catalogService.getProductsStream();
    _rateSub = _marketService.getGoldRateStream().listen((rate) {
      if (mounted) setState(() => _currentRate = rate);
    });
  }

  @override
  void dispose() {
    _rateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildCategoryChips(),
            Expanded(child: _buildProductGrid()),
          ],
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
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
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, _primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.storefront_rounded, color: _gold, size: 17),
          ),
          const SizedBox(width: 10),
          const Text(
            'ร้านทอง',
            style: TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      actions: [
        if (_currentRate != null)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, color: Color(0xFF2E7D32), size: 7),
                const SizedBox(width: 5),
                Text(
                  '฿${(_currentRate!.sellPrice / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7A5800),
                  ),
                ),
              ],
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE9EAEC), height: 1),
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'ค้นหาเครื่องประดับ...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: _primary, size: 20),
          filled: true,
          fillColor: _bgColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ─── Category chips ───────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return Container(
      color: Colors.white,
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final label = _categories.keys.elementAt(index);
          final isSelected = _selectedCategory == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _primary : Colors.grey.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : const Color(0xFF555555),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Product grid ─────────────────────────────────────────────────────────
  Widget _buildProductGrid() {
    return StreamBuilder<List<Product>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allCloudProducts = snapshot.data ?? [];
        final query = _searchQuery.toLowerCase();
        final backendCategory = _categories[_selectedCategory];
        final productsToShow = allCloudProducts.where((p) {
          final matchesSearch = p.name.toLowerCase().contains(query);
          final matchesCategory =
              backendCategory == 'All' || p.category == backendCategory;
          return matchesSearch && matchesCategory;
        }).toList();

        if (productsToShow.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.search_off_rounded, size: 48, color: _primary),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ไม่พบสินค้าที่ตรงกัน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary),
                ),
                const SizedBox(height: 6),
                Text(
                  'ลองเปลี่ยนคำค้นหาหรือหมวดหมู่',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: productsToShow.length,
          itemBuilder: (context, index) {
            return ProductCard(
              product: productsToShow[index],
              currentRate: _currentRate,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(
                      product: productsToShow[index],
                      currentRate: _currentRate,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
