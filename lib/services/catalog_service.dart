import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';
import 'id_generator_service.dart';
import 'inventory_lot_service.dart';
import 'price_calculation_service.dart';

/// Manages the gold product catalog (ornaments and gold bars).
/// Also handles owner-only operations: restocking and data repair.
class CatalogService {
  static final CatalogService _instance = CatalogService._internal();
  factory CatalogService() => _instance;
  CatalogService._internal();

  final IdGeneratorService _ids = IdGeneratorService();
  final InventoryLotService _lots = InventoryLotService();
  bool _isGenerating = false;

  // ─── Products Stream ──────────────────────────────────────────────────────

  /// Returns a live stream of ornament products (gold bars are excluded from
  /// the customer-facing catalog — they are bought via TradingService).
  Stream<List<Product>> getProductsStream() {
    final collection = FirebaseFirestore.instance.collection('products');
    _ensureProductsPopulated(collection);
    return collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) {
            final data = doc.data();
            return Product(
              id: doc.id,
              name: data['name'] ?? 'ไม่ทราบชื่อสินค้า',
              description: data['description'] ?? '',
              price: (data['price'] ?? 0 as num).toDouble(),
              weight: (data['weight'] ?? 0 as num).toDouble(),
              laborFee: (data['laborFee'] ?? 0 as num).toDouble(),
              costBasis: (data['costBasis'] ?? 0 as num).toDouble(),
              stock: data['stock'] ?? 0,
              imageUrl: data['imageUrl'] ?? '',
              category: data['category'] ?? 'ทั่วไป',
            );
          })
          .where((p) => p.category != 'ทองคำแท่ง')
          .toList(),
    );
  }

  List<Product> filterProducts(List<Product> products, String query) {
    if (query.isEmpty) return products;
    final q = query.toLowerCase();
    return products
        .where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q))
        .toList();
  }

  // ─── Restock (owner) ──────────────────────────────────────────────────────

  Future<void> restockProduct({
    required String productId,
    required String productName,
    required int quantity,
    required double totalCost,
    String? note,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    // Generate IDs before the transaction (async work must happen outside).
    final restockTxId = await _ids.generateId('transactions', prefixOverride: 'RSK');
    final lotId = await _ids.generateId('inventory_lots', prefixOverride: 'LOT');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
      final productDoc = await tx.get(productRef);
      if (!productDoc.exists) throw Exception('Product not found');

      final currentStock = (productDoc.data() as Map<String, dynamic>)['stock'] ?? 0;
      final currentCostBasis =
          ((productDoc.data() as Map<String, dynamic>)['costBasis'] as num?)?.toDouble() ?? 0.0;
      final newTotalStock = currentStock + quantity;
      final unitCost = totalCost / quantity;

      // Keep the weighted-average costBasis on the product for display purposes.
      // Actual per-sale cost resolution uses the inventory_lots FIFO subcollection.
      final newCostBasis =
          ((currentStock * currentCostBasis) + (quantity * unitCost)) / newTotalStock;

      tx.update(productRef, {
        'stock': newTotalStock,
        'costBasis': newCostBasis,
        'inStock': true,
      });

      // ── Create per-lot record ─────────────────────────────────────────────
      // Each restock creates an immutable lot so FIFO cost resolution is
      // possible at the time of customer purchase.
      _lots.createLotWithTx(
        transaction: tx,
        lotId: lotId,
        productId: productId,
        productName: productName,
        quantity: quantity,
        unitCost: unitCost,
        restockTransactionId: restockTxId,
        note: note,
      );

      tx.set(
        FirebaseFirestore.instance.collection('transactions').doc(restockTxId),
        {
          'type': 'restock',
          'amount': totalCost,
          'quantity': quantity,
          'unitCost': unitCost,
          'lotId': lotId,
          'productId': productId,
          'timestamp': FieldValue.serverTimestamp(),
          'details': 'เพิ่มสต็อก: $productName ($quantity ชิ้น @ ฿${unitCost.toStringAsFixed(0)}/ชิ้น)',
          'userId': uid,
          'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'Owner',
          if (note != null) 'note': note,
        },
      );
    });
  }

  // ─── Data repair ──────────────────────────────────────────────────────────

  Future<void> repairProductsData() async {
    final snap = await FirebaseFirestore.instance.collection('products').get();
    final batch = FirebaseFirestore.instance.batch();
    bool needed = false;
    for (var doc in snap.docs) {
      final data = doc.data();
      if (data['costBasis'] == null) {
        final price = (data['price'] as num?)?.toDouble() ?? 0.0;
        final weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
        final cost = (weight > 0 && price == 0) ? weight * 40000.0 : price * 0.9;
        batch.update(doc.reference, {'costBasis': cost});
        needed = true;
      }
    }
    if (needed) await batch.commit();
  }

  // ─── Seeding (private) ────────────────────────────────────────────────────

  Future<void> _ensureProductsPopulated(CollectionReference collection) async {
    if (_isGenerating) return;
    final snapshot = await collection.get();

    bool needsReset = false;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name'] as String? ?? '';
      final category = data['category'] as String? ?? '';
      final imageUrl = data['imageUrl'] as String?;
      if (name.contains('Gold Earring') || name.contains('Gold Ring') ||
          name.contains('Gold Bracelet') || name.contains('Gold Necklace') ||
          category.toLowerCase().contains('amulet') ||
          imageUrl?.contains('somsrimanee') == true) {
        needsReset = true;
        break;
      }
    }

    if (snapshot.docs.isEmpty || needsReset) {
      _isGenerating = true;
      try {
        for (var doc in snapshot.docs) { await doc.reference.delete(); }
        await _seedProducts();
      } finally {
        _isGenerating = false;
      }
    }
  }

  Future<void> _seedProducts() async {
    final ref = FirebaseFirestore.instance.collection('products');
    final items = [
      // สร้อยคอ
      {'name': 'สร้อยคอทองคำ ลายสี่เสา', 'description': 'สร้อยคอทองคำแท้ 96.5% ลายสี่เสา ดีไซน์คลาสสิก', 'price': 42000.0, 'weight': 1.0, 'costBasis': 40000.0, 'stock': 15, 'imageUrl': 'assets/images/prod_necklace_si_sao.png', 'category': 'สร้อยคอ'},
      {'name': 'สร้อยคอทองคำ ลายเบนซ์', 'description': 'สร้อยคอทองคำแท้ 96.5% ลายเบนซ์ เรียบหรู', 'price': 21500.0, 'weight': 0.5, 'costBasis': 20000.0, 'stock': 10, 'imageUrl': 'assets/images/prod_necklace_benz.png', 'category': 'สร้อยคอ'},
      {'name': 'สร้อยคอทองคำ ลายคดกริช', 'description': 'สร้อยคอทองคำแท้ 96.5% ลายคดกริช งานละเอียด', 'price': 11000.0, 'weight': 0.25, 'costBasis': 10000.0, 'stock': 20, 'imageUrl': 'assets/images/prod_necklace_kod_grit.png', 'category': 'สร้อยคอ'},
      // แหวน
      {'name': 'แหวนทองคำ ลายมังกร', 'description': 'แหวนทองคำแท้ 96.5% แกะสลักลายมังกร', 'price': 21500.0, 'weight': 0.5, 'costBasis': 20000.0, 'stock': 8, 'imageUrl': 'assets/images/prod_ring_dragon.png', 'category': 'แหวน'},
      {'name': 'แหวนทองคำ ลายเกลี้ยง', 'description': 'แหวนทองคำแท้ 96.5% แบบเรียบเกลี้ยง', 'price': 10800.0, 'weight': 0.25, 'costBasis': 10000.0, 'stock': 25, 'imageUrl': 'assets/images/prod_ring_plain.png', 'category': 'แหวน'},
      {'name': 'แหวนทองคำ ลายหัวใจ', 'description': 'แหวนทองคำแท้ 96.5% รูปหัวใจ น่ารัก', 'price': 6500.0, 'weight': 0.125, 'costBasis': 5500.0, 'stock': 30, 'imageUrl': 'assets/images/prod_ring_heart.png', 'category': 'แหวน'},
      // สร้อยข้อมือ
      {'name': 'สร้อยข้อมือ ลายมีนา', 'description': 'สร้อยข้อมือทองคำแท้ 96.5% ลายมีนา', 'price': 42500.0, 'weight': 1.0, 'costBasis': 40000.0, 'stock': 12, 'imageUrl': 'assets/images/prod_bracelet_meena.png', 'category': 'สร้อยข้อมือ'},
      {'name': 'สร้อยข้อมือ ลายพิกุล', 'description': 'สร้อยข้อมือทองคำแท้ 96.5% ลายพิกุล งานไทยโบราณ', 'price': 85000.0, 'weight': 2.0, 'costBasis': 80000.0, 'stock': 5, 'imageUrl': 'assets/images/prod_bracelet_pikul.png', 'category': 'สร้อยข้อมือ'},
      {'name': 'กำไลทองคำ เกลี้ยงกลม', 'description': 'กำไลทองคำแท้ 96.5% แบบกลมเรียบ', 'price': 21800.0, 'weight': 0.5, 'costBasis': 20000.0, 'stock': 15, 'imageUrl': 'assets/images/prod_bracelet_plain_bangle.png', 'category': 'สร้อยข้อมือ'},
      // ต่างหู
      {'name': 'ต่างหูทองคำ ลายพิกุล', 'description': 'ต่างหูทองคำแท้ 96.5% ลายพิกุล', 'price': 5800.0, 'weight': 0.125, 'costBasis': 5000.0, 'stock': 20, 'imageUrl': 'assets/images/prod_earring_pikul.png', 'category': 'ต่างหู'},
      {'name': 'ต่างหูทองคำ ห่วงกลม', 'description': 'ต่างหูทองคำแท้ 96.5% แบบห่วง', 'price': 10800.0, 'weight': 0.25, 'costBasis': 9500.0, 'stock': 18, 'imageUrl': 'assets/images/prod_earring_hoop.png', 'category': 'ต่างหู'},
      {'name': 'ต่างหูทองคำ แป้นหัวใจ', 'description': 'ต่างหูทองคำแท้ 96.5% แป้นรูปหัวใจ', 'price': 5500.0, 'weight': 0.125, 'costBasis': 4800.0, 'stock': 22, 'imageUrl': 'assets/images/prod_earring_heart.png', 'category': 'ต่างหู'},
      // ทองคำแท่ง (used by savings physical withdrawal — not shown in customer catalog)
      {'name': 'ทองคำแท่ง 0.25 บาท', 'description': 'ทองคำแท่งแท้ 96.5% น้ำหนัก 0.25 บาท', 'price': 10250.0, 'weight': 0.25, 'costBasis': 10000.0, 'stock': 100, 'imageUrl': 'assets/images/prod_gold_bar.png', 'category': 'ทองคำแท่ง'},
      {'name': 'ทองคำแท่ง 0.5 บาท', 'description': 'ทองคำแท่งแท้ 96.5% น้ำหนัก 0.5 บาท', 'price': 20500.0, 'weight': 0.5, 'costBasis': 20000.0, 'stock': 50, 'imageUrl': 'assets/images/prod_gold_bar.png', 'category': 'ทองคำแท่ง'},
      {'name': 'ทองคำแท่ง 1 บาท', 'description': 'ทองคำแท่งแท้ 96.5% น้ำหนัก 1 บาท', 'price': 41000.0, 'weight': 1.0, 'costBasis': 40000.0, 'stock': 30, 'imageUrl': 'assets/images/prod_gold_bar.png', 'category': 'ทองคำแท่ง'},
    ];

    for (var item in items) {
      final id = await _ids.generateId('products');
      final weight = (item['weight'] as num).toDouble();
      final category = item['category'] as String;
      await ref.doc(id).set({
        ...item,
        'id': id,
        'laborFee': PriceCalculationService.calculateLaborFee(category, weight),
      });
    }
  }
}
