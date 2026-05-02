import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gold_rate.dart';
import '../models/news_item.dart';
import 'id_generator_service.dart';

/// Provides live market data: gold rates, news articles, and promotions.
/// All data is read-only for regular users; writes are owner-gated by
/// Firestore security rules.
class MarketService {
  static final MarketService _instance = MarketService._internal();
  factory MarketService() => _instance;
  MarketService._internal();

  final IdGeneratorService _ids = IdGeneratorService();

  // ─── Gold Rate ────────────────────────────────────────────────────────────

  /// Updates the live gold rate AND appends an immutable record to
  /// markethistory so no historical price data is ever overwritten.
  /// Called from the owner dashboard whenever the rate changes.
  Future<void> updateGoldRate({
    required double buyPrice,
    required double sellPrice,
    required String updatedByUid,
  }) async {
    final rateId = await _ids.generateId('gold_rates');

    // Derive trend by reading the current rate before overwriting.
    final currentDoc = await FirebaseFirestore.instance
        .collection('market')
        .doc('gold_rate')
        .get();
    final previousBuy =
        (currentDoc.data()?['buyPrice'] as num?)?.toDouble() ?? buyPrice;
    final trend = buyPrice > previousBuy
        ? 'up'
        : buyPrice < previousBuy
            ? 'down'
            : 'stable';

    final batch = FirebaseFirestore.instance.batch();

    // Overwrite the live rate document (used by real-time listeners).
    batch.set(
      FirebaseFirestore.instance.collection('market').doc('gold_rate'),
      {
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'timestamp': FieldValue.serverTimestamp(),
        'trend': trend,
      },
    );

    // Append an immutable history record — never deleted, never overwritten.
    // This means every price the shop has ever set is auditable.
    batch.set(
      FirebaseFirestore.instance.collection('markethistory').doc(rateId),
      {
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'trend': trend,
        'timestamp': FieldValue.serverTimestamp(),
        'recordedBy': updatedByUid,
        'source': 'manual',
      },
    );

    await batch.commit();
  }

  /// Returns the most recent gold rate records for trend display.
  Stream<List<Map<String, dynamic>>> getGoldRateHistoryStream({int limit = 30}) {
    return FirebaseFirestore.instance
        .collection('markethistory')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'buyPrice': (data['buyPrice'] as num?)?.toDouble() ?? 0.0,
                'sellPrice': (data['sellPrice'] as num?)?.toDouble() ?? 0.0,
                'trend': data['trend'] ?? 'stable',
                'timestamp':
                    (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                'recordedBy': data['recordedBy'] ?? '',
              };
            }).toList());
  }

  Stream<GoldRate> getGoldRateStream() {
    return FirebaseFirestore.instance
        .collection('market')
        .doc('gold_rate')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return GoldRate(
          buyPrice: 40000.0,
          sellPrice: 40100.0,
          timestamp: DateTime.now(),
        );
      }
      final data = snapshot.data()!;
      return GoldRate(
        buyPrice: (data['buyPrice'] ?? 40000).toDouble(),
        sellPrice: (data['sellPrice'] ?? 40100).toDouble(),
        timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    });
  }

  // ─── News ─────────────────────────────────────────────────────────────────

  Stream<List<NewsItem>> getNewsStream() {
    final collection = FirebaseFirestore.instance.collection('news');
    _ensureNewsPopulated(collection);
    return collection.orderBy('date', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        final data = doc.data();
        return NewsItem(
          id: doc.id,
          title: data['title'] ?? 'No Title',
          summary: data['summary'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          content: data['content'] ?? '',
          url: data['url'] as String?,
        );
      }).toList(),
    );
  }

  Future<void> _ensureNewsPopulated(CollectionReference collection) async {
    final snapshot = await collection.get();
    const oldTitles = [
      'Why Gold is the Best Safe Haven Asset?',
      'Gold Price Analysis: Upward Trend continues',
      'Understanding 96.5% vs 99.99% Gold',
    ];

    bool needsUpdate = false;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final title = data['title'] as String?;
      final imageUrl = data['imageUrl'] as String?;
      if (title != null && oldTitles.contains(title)) { needsUpdate = true; break; }
      if (title != null && title.contains('ทอง') &&
          (!data.containsKey('url') || imageUrl?.contains('placeholder') == true)) {
        needsUpdate = true;
        break;
      }
    }

    if (snapshot.docs.isEmpty || needsUpdate) {
      if (needsUpdate) {
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title'] as String?;
          final imageUrl = data['imageUrl'] as String?;
          final isOld = title != null &&
              (oldTitles.contains(title) ||
               (title.contains('ทอง') &&
                (!data.containsKey('url') || imageUrl?.contains('placeholder') == true)));
          if (isOld) await doc.reference.delete();
        }
      }
      await _seedNews();
    }
  }

  Future<void> _seedNews() async {
    final batch = FirebaseFirestore.instance.batch();
    final items = [
      {
        'title': 'แนวโน้มราคาทองปี 69: ลุ้นแตะ 85,000 บาท?',
        'summary': 'นักวิเคราะห์คาดราคาทองไทยมีโอกาสพุ่งสูงต่อเนื่อง',
        'imageUrl': 'assets/images/news_trend.png',
        'url': 'https://www.bangkokpost.com/business/general/2881144/gold-prices-hit-another-record',
        'date': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
        'content': 'บทวิเคราะห์เจาะลึกเกี่ยวกับทิศทางราคาทองคำในปี 2569...',
      },
      {
        'title': 'สงครามในต่างประเทศกระทบราคาทองอย่างไร?',
        'summary': 'ทำความเข้าใจความสัมพันธ์ระหว่างความขัดแย้งระดับโลกและราคาทอง',
        'imageUrl': 'assets/images/news_war.png',
        'url': 'https://www.bangkokpost.com/business/general/2778841/gold-prices-volatile-amid-geopolitical-tensions',
        'date': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
        'content': 'วิเคราะห์ผลกระทบของสงครามและภูมิรัฐศาสตร์ต่อนักลงทุนทองคำ...',
      },
      {
        'title': 'ออมทองฉบับชาวบ้าน: ทำไมการเก็บทองถึงดีกว่าเงินฝาก?',
        'summary': 'เปรียบเทียบข้อดีของการออมทองและการฝากเงินธนาคาร',
        'imageUrl': 'assets/images/news_saving.png',
        'url': 'https://www.bangkokpost.com/business/general/2785541/gold-savings-plans-gain-popularity',
        'date': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 5))),
        'content': 'เคล็ดลับการเริ่มออมทองทีละนิดสำหรับคนทำงานและเกษตรกร...',
      },
      {
        'title': 'ขายข้าวแล้วซื้อทอง: ทำไมเกษตรกรไทยถึงนิยม?',
        'summary': 'ส่องพฤติกรรมการออมของคนไทยที่นิยมแปลงรายได้เป็นทอง',
        'imageUrl': 'assets/images/news_harvest.png',
        'url': 'https://www.bangkokpost.com/business/general/2774914/gold-prices-set-new-records',
        'date': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7))),
        'content': 'ทำไมทองคำถึงเป็น "ธนาคารเคลื่อนที่" ที่ชาวบ้านไว้วางใจ...',
      },
    ];
    for (var item in items) {
      final id = await _ids.generateId('news');
      batch.set(FirebaseFirestore.instance.collection('news').doc(id), item);
    }
    await batch.commit();
  }

  // ─── Promotions ───────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getPromotionsStream() {
    final collection = FirebaseFirestore.instance.collection('promotions');
    _ensurePromotionsPopulated(collection);
    return collection.snapshots().map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'] ?? '',
        'color': data['color'] ?? 0xFF800000,
        'textColor': data['textColor'] ?? 0xFFFFFFFF,
        'image': data['image'],
        'category': data['category'] ?? 'catalog',
      };
    }).toList());
  }

  Future<void> _ensurePromotionsPopulated(CollectionReference collection) async {
    final snapshot = await collection.get();
    final titles = <String>{};
    bool hasDuplicates = false;
    for (var doc in snapshot.docs) {
      final title = (doc.data() as Map<String, dynamic>)['title'] as String?;
      if (title != null) {
        if (titles.contains(title)) { hasDuplicates = true; break; }
        titles.add(title);
      }
    }
    final isOutdated = snapshot.docs.isNotEmpty &&
        !(snapshot.docs.first.data() as Map<String, dynamic>).containsKey('category');

    if (snapshot.docs.isEmpty || isOutdated || hasDuplicates || snapshot.docs.length > 3) {
      for (var doc in snapshot.docs) { await doc.reference.delete(); }
      await _seedPromotions();
    }
  }

  Future<void> _seedPromotions() async {
    final batch = FirebaseFirestore.instance.batch();
    final promos = [
      {
        'title': 'ลดค่ากำเหน็จ 50%\nฉลองเปิดตัวแอปพลิเคชัน',
        'color': 0xFF800000,
        'textColor': 0xFFFFFFFF,
        'image': null,
        'category': 'catalog',
      },
      {
        'title': 'คอลเลกชันมังกรทอง\nรับตรุษจีน',
        'color': 0xFFFFD700,
        'textColor': 0xFF000000,
        'image': null,
        'category': 'catalog',
      },
      {
        'title': 'ออมทองง่ายๆ\nเริ่มต้นเพียง 100 บาท',
        'color': 0xFF1E88E5,
        'textColor': 0xFFFFFFFF,
        'image': null,
        'category': 'savings',
      },
    ];
    for (var promo in promos) {
      final id = await _ids.generateId('promotions');
      batch.set(FirebaseFirestore.instance.collection('promotions').doc(id), promo);
    }
    await batch.commit();
  }
}
