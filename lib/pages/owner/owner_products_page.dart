// lib/pages/owner/owner_products_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/id_generator_service.dart';
import '../../utils/product_pricing.dart';

/// Owner catalog view — shows all products grouped by category.
///
/// Per product:
///   • Stock on hand
///   • Cost basis per unit (weighted average of owner's actual purchase price)
///   • Sell price per unit  = (weight × current market sell rate) + laborFee
///   • Margin per unit      = sell price − cost basis
///   • Total cost investment in current stock = stock × costBasis
///
/// Unlike OwnerInventoryCostPage (financial analysis), this page is for
/// catalog management — the owner can see all products including zero-stock
/// items and track cost basis changes over time.
class OwnerProductsPage extends StatelessWidget {
  const OwnerProductsPage({super.key});

  static void _openAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AddProductDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สินค้าในร้าน')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddProductDialog(context),
        backgroundColor: const Color(0xFF800000),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'เพิ่มสินค้าใหม่',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Fetch live market rate once at the top
        stream: FirebaseFirestore.instance
            .collection('market')
            .doc('gold_rate')
            .snapshots(),
        builder: (context, rateSnap) {
          final rateData = rateSnap.data?.data() as Map<String, dynamic>?;
          final sellRate =
              (rateData?['sellPrice'] as num?)?.toDouble() ?? 42000.0;

          return StreamBuilder<QuerySnapshot>(
            // Fetch all products ordered by category, then name
            stream: FirebaseFirestore.instance
                .collection('products')
                .orderBy('category')
                .snapshots(),
            builder: (context, productSnap) {
              if (productSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = productSnap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('ไม่พบสินค้า'));
              }

              // Build product stats
              final List<_ProductItem> items = docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final name = d['name'] as String? ?? '-';
                final category = d['category'] as String? ?? '-';
                final stock = (d['stock'] as num?)?.toInt() ?? 0;
                final weight = (d['weight'] as num?)?.toDouble() ?? 0.0;
                final laborFee =
                    (d['laborFee'] as num?)?.toDouble() ??
                    0.0; // [8] Labor Fee ดึงจาก Firestore
                final costBasis = (d['costBasis'] as num?)?.toDouble() ?? 0.0;

                final sellPrice = ProductPricing.unitSellPrice(
                    weight, sellRate, laborFee); // [4] ราคาขายต่อชิ้น
                final marginPerUnit = ProductPricing.marginPerUnit(
                    sellPrice, costBasis); // [5] กำรต่อชิ้น
                final marginPct = ProductPricing.marginPct(
                    marginPerUnit, costBasis); // [6] กำไรต่อชิ้น %
                final stockInvestment = ProductPricing.stockInvestment(
                    stock, costBasis); // [7] ทุนในสต็อก

                return _ProductItem(
                  id: doc.id,
                  name: name,
                  category: category,
                  stock: stock,
                  weight: weight,
                  laborFee: laborFee,
                  costBasis: costBasis,
                  sellPrice: sellPrice,
                  marginPerUnit: marginPerUnit,
                  marginPct: marginPct,
                  stockInvestment: stockInvestment,
                );
              }).toList();

              // Grand totals
              int totalInStock = 0;
              double totalInvestment = 0;
              double totalRetailValue = 0;
              for (final item in items) {
                if (item.stock > 0) {
                  totalInStock++; // [1] ประเภทที่มีในสต็อก
                  totalInvestment += item.stockInvestment; // [2] ทุนในสต็อก
                  totalRetailValue +=
                      item.stock * item.sellPrice; // [3] มูลค่าตามราคาขาย
                }
              }

              // Group by category
              final Map<String, List<_ProductItem>> grouped = {};
              for (final item in items) {
                grouped.putIfAbsent(item.category, () => []).add(item);
              }

              return Column(
                children: [
                  _SummaryBar(
                    productTypesWithStock: totalInStock,
                    totalProducts: items.length,
                    totalInvestment: totalInvestment,
                    totalRetailValue: totalRetailValue,
                    sellRate: sellRate,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        for (final category in grouped.keys) ...[
                          _CategoryHeader(
                            category: category,
                            items: grouped[category]!,
                          ),
                          for (final item in grouped[category]!)
                            _ProductCard(item: item),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _ProductItem {
  final String id;
  final String name;
  final String category;
  final int stock;
  final double weight;
  final double laborFee;
  final double costBasis;
  final double sellPrice;
  final double marginPerUnit;
  final double marginPct;
  final double stockInvestment;

  const _ProductItem({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.weight,
    required this.laborFee,
    required this.costBasis,
    required this.sellPrice,
    required this.marginPerUnit,
    required this.marginPct,
    required this.stockInvestment,
  });
}

// ─── Summary bar ─────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int productTypesWithStock;
  final int totalProducts;
  final double totalInvestment;
  final double totalRetailValue;
  final double sellRate;

  const _SummaryBar({
    required this.productTypesWithStock,
    required this.totalProducts,
    required this.totalInvestment,
    required this.totalRetailValue,
    required this.sellRate,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Container(
      color: const Color(0xFF2E7D32).withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              _Cell(
                label: 'ประเภทที่มีสต็อก',
                value: '$productTypesWithStock / $totalProducts ประเภท',
                color: Colors.grey[700]!,
              ),
              const SizedBox(width: 8),
              _Cell(
                label: 'ทุนในสต็อก',
                value: '฿${fmt.format(totalInvestment)}',
                color: const Color(0xFF4E342E),
                bold: true,
              ),
              const SizedBox(width: 8),
              _Cell(
                label: 'มูลค่าตามราคาขาย',
                value: '฿${fmt.format(totalRetailValue)}',
                color: const Color(0xFFEF6C00),
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.show_chart, size: 12, color: Colors.amber[700]),
              const SizedBox(width: 4),
              Text(
                'ราคาทองขาย: ฿${fmt.format(sellRate)}/บาท',
                style: TextStyle(fontSize: 11, color: Colors.amber[800]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _Cell({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Category header ──────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String category;
  final List<_ProductItem> items;

  const _CategoryHeader({required this.category, required this.items});

  @override
  Widget build(BuildContext context) {
    final inStock = items.where((i) => i.stock > 0).length;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF800000),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            category,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF800000),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($inStock/${items.length} ประเภทมีสต็อก)',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ─── Product card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final _ProductItem item;

  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final fmtShort = NumberFormat('#,##0');
    final hasStock = item.stock > 0;
    final marginColor = item.marginPerUnit >= 0
        ? const Color(0xFF2E7D32)
        : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasStock ? Colors.grey[200]! : Colors.grey[100]!,
        ),
      ),
      elevation: hasStock ? 1 : 0,
      color: hasStock ? Colors.white : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + stock badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: hasStock ? Colors.black87 : Colors.grey[400],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasStock
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasStock ? '${item.stock} ชิ้น' : 'หมดสต็อก',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasStock ? Colors.green[700] : Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Info pills
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Pill(
                  '${item.weight.toStringAsFixed(3)} บาท/ชิ้น',
                  Colors.amber.withValues(alpha: 0.12),
                  Colors.amber[800]!,
                ),
                _Pill(
                  'กำเหน็จ ฿${fmtShort.format(item.laborFee)}',
                  Colors.blue.withValues(alpha: 0.08),
                  Colors.blue[700]!,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Price comparison: cost vs sell
            // costBasis = 0 means product was just created and not yet restocked
            if (item.costBasis == 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ยังไม่มีต้นทุน — กรุณาเพิ่มสต็อกเพื่อบันทึกราคาซื้อ',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _PriceBox(
                      label: 'ต้นทุน/ชิ้น',
                      value: '฿${fmtShort.format(item.costBasis)}',
                      color: const Color(0xFF4E342E),
                      bg: Colors.brown.withValues(alpha: 0.06),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PriceBox(
                      label: 'ราคาขาย/ชิ้น',
                      value: '฿${fmtShort.format(item.sellPrice)}',
                      color: const Color(0xFFEF6C00),
                      bg: Colors.orange.withValues(alpha: 0.06),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PriceBox(
                      label:
                          'กำไร/ชิ้น (${item.marginPct >= 0 ? '+' : ''}${item.marginPct.toStringAsFixed(1)}%)',
                      value:
                          '${item.marginPerUnit >= 0 ? '+' : ''}฿${fmtShort.format(item.marginPerUnit)}',
                      color: marginColor,
                      bg: marginColor.withValues(alpha: 0.06),
                      bold: true,
                    ),
                  ),
                ],
              ),

            // Stock investment total (only if in stock)
            if (hasStock) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'ทุนในสต็อก: ฿${fmt.format(item.stockInvestment)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final bool bold;

  const _PriceBox({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Pill(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}

// ─── Add Product Dialog ───────────────────────────────────────────────────────

class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog();

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ids = IdGeneratorService();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _laborFeeCtrl = TextEditingController();
  final _customUrlCtrl = TextEditingController();

  String? _selectedCategory;
  double? _selectedWeight;
  String? _selectedImage;
  bool _useCustomUrl = false;
  bool _isSaving = false;

  static const _categories = ['สร้อยคอ', 'แหวน', 'สร้อยข้อมือ', 'ต่างหู'];
  static const _weights = [0.125, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0];

  // Generic fallback image per category (shown as first tile)
  static const _genericImages = <String, String>{
    'สร้อยคอ': 'assets/images/prod_necklace_si_sao.png',
    'แหวน': 'assets/images/prod_ring_plain.png',
    'สร้อยข้อมือ': 'assets/images/prod_bracelet_meena.png',
    'ต่างหู': 'assets/images/prod_earring_hoop.png',
  };

  // Images grouped by category
  static const _imagesByCategory = <String, List<(String, String)>>{
    'สร้อยคอ': [
      ('assets/images/prod_necklace_si_sao.png', 'สี่เสา'),
      ('assets/images/prod_necklace_benz.png', 'เบนซ์'),
      ('assets/images/prod_necklace_kod_grit.png', 'คดกริช'),
    ],
    'แหวน': [
      ('assets/images/prod_ring_dragon.png', 'มังกร'),
      ('assets/images/prod_ring_plain.png', 'เกลี้ยง'),
      ('assets/images/prod_ring_heart.png', 'หัวใจ'),
    ],
    'สร้อยข้อมือ': [
      ('assets/images/prod_bracelet_meena.png', 'มีนา'),
      ('assets/images/prod_bracelet_pikul.png', 'พิกุล'),
      ('assets/images/prod_bracelet_plain_bangle.png', 'กำไลเกลี้ยง'),
    ],
    'ต่างหู': [
      ('assets/images/prod_earring_pikul.png', 'พิกุล'),
      ('assets/images/prod_earring_hoop.png', 'ห่วงกลม'),
      ('assets/images/prod_earring_heart.png', 'หัวใจ'),
    ],
  };

  // Effective image URL to save — custom URL takes priority
  String? get _effectiveImageUrl {
    if (_useCustomUrl) {
      final url = _customUrlCtrl.text.trim();
      return url.isEmpty ? null : url;
    }
    return _selectedImage;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _laborFeeCtrl.dispose();
    _customUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_effectiveImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกรูปภาพหรือใส่ URL รูปภาพ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final id = await _ids.generateId('products');
      await FirebaseFirestore.instance.collection('products').doc(id).set({
        'id': id,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _selectedCategory,
        'weight': _selectedWeight,
        'laborFee': double.parse(_laborFeeCtrl.text),
        'costBasis': 0.0, // Set to 0 — first Restock will write the real cost
        'imageUrl': _effectiveImageUrl,
        'stock': 0,
        'inStock': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ เพิ่ม "${_nameCtrl.text.trim()}" สำเร็จ (ID: $id)',
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF800000),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_box_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'เพิ่มสินค้าใหม่',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Text(
                    'ต้นทุนจะกำหนดเมื่อเพิ่มสต็อก',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),

            // ── Form ────────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      _label('ชื่อสินค้า *'),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _deco('เช่น สร้อยคอทองคำ ลายดอกไม้'),
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'กรุณาใส่ชื่อสินค้า'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Description
                      _label('คำอธิบาย *'),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: _deco(
                          'เช่น ทองคำแท้ 96.5% ลายดอกไม้ งานละเอียด',
                        ),
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'กรุณาใส่คำอธิบาย'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Category + Weight
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('หมวดหมู่ *'),
                                DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: _deco('เลือก'),
                                  isExpanded: true,
                                  items: _categories
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            c,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _selectedCategory = v;
                                    _selectedImage =
                                        null; // reset image when category changes
                                  }),
                                  validator: (v) =>
                                      v == null ? 'เลือกหมวดหมู่' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('น้ำหนัก (บาท) *'),
                                DropdownButtonFormField<double>(
                                  value: _selectedWeight,
                                  decoration: _deco('เลือก'),
                                  isExpanded: true,
                                  items: _weights
                                      .map(
                                        (w) => DropdownMenuItem(
                                          value: w,
                                          child: Text(
                                            w == w.truncateToDouble()
                                                ? '${w.toInt()} บาท'
                                                : '$w บาท',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _selectedWeight = v;
                                  }),
                                  validator: (v) =>
                                      v == null ? 'เลือกน้ำหนัก' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Labor fee
                      _label('ค่ากำเหน็จ (฿) *'),
                      TextFormField(
                        controller: _laborFeeCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _deco('เช่น 1500', prefixText: '฿ '),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'กรุณาใส่ค่ากำเหน็จ';
                          }
                          final val = double.tryParse(v);
                          if (val == null || val < 0) {
                            return 'ค่ากำเหน็จต้องมากกว่าหรือเท่ากับ 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Image section header ───────────────────────────
                      Row(
                        children: [
                          _label('รูปภาพสินค้า *'),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() {
                              _useCustomUrl = !_useCustomUrl;
                              // Clear selections when switching modes
                              if (_useCustomUrl) {
                                _selectedImage = null;
                              } else {
                                _customUrlCtrl.clear();
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _useCustomUrl
                                    ? const Color(0xFF800000)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _useCustomUrl
                                      ? const Color(0xFF800000)
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: Text(
                                _useCustomUrl
                                    ? '← เลือกจากรูปที่มี'
                                    : 'ใช้ URL แทน →',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _useCustomUrl
                                      ? Colors.white
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (_useCustomUrl) ...[
                        // ── Custom URL input ─────────────────────────────
                        TextFormField(
                          controller: _customUrlCtrl,
                          decoration: _deco(
                            'https://... หรือ assets/images/prod_xxx.png',
                          ),
                          validator: (v) {
                            if (!_useCustomUrl) return null;
                            if (v == null || v.trim().isEmpty) {
                              return 'กรุณาใส่ URL รูปภาพ';
                            }
                            return null;
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            'ใส่ URL จากอินเทอร์เน็ต หรือ path ของไฟล์ใน assets',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ] else ...[
                        // ── Category-filtered image picker ───────────────
                        if (_selectedCategory == null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              'เลือกหมวดหมู่ก่อนเพื่อดูรูปภาพที่เหมาะสม',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 84,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                // Generic tile (first)
                                _buildImageTile(
                                  path: _genericImages[_selectedCategory]!,
                                  label: 'ทั่วไป',
                                  isGeneric: true,
                                ),
                                const SizedBox(width: 8),
                                // Category-specific tiles
                                ...(_imagesByCategory[_selectedCategory] ?? [])
                                    .map((entry) {
                                      final (path, lbl) = entry;
                                      return Row(
                                        children: [
                                          _buildImageTile(
                                            path: path,
                                            label: lbl,
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      );
                                    }),
                              ],
                            ),
                          ),
                        if (_selectedImage == null && _selectedCategory != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'กรุณาเลือกรูปภาพ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),

            // ── Actions ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF800000),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'บันทึกสินค้า',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTile({
    required String path,
    required String label,
    bool isGeneric = false,
  }) {
    final isSelected = _selectedImage == path;
    final isAsset = path.startsWith('assets/');

    return GestureDetector(
      onTap: () => setState(() => _selectedImage = path),
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF800000) : Colors.grey[200]!,
            width: isSelected ? 2.5 : 1,
          ),
          color: isSelected
              ? const Color(0xFF800000).withValues(alpha: 0.05)
              : Colors.grey[50],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image or generic icon
            if (isGeneric && !isSelected)
              Icon(Icons.image_outlined, size: 30, color: Colors.grey[400])
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: isAsset
                    ? Image.asset(
                        path,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          size: 30,
                          color: Colors.grey[400],
                        ),
                      )
                    : Image.network(
                        path,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          size: 30,
                          color: Colors.grey[400],
                        ),
                      ),
              ),
            const SizedBox(height: 4),
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF800000)
                    : isGeneric
                    ? Colors.grey[500]
                    : Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A2E),
      ),
    ),
  );

  InputDecoration _deco(String hint, {String? prefixText}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
    prefixText: prefixText,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF800000), width: 2),
    ),
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}
