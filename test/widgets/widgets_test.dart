import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/gold_rate.dart';
import 'package:ssl_store/models/news_item.dart';
import 'package:ssl_store/models/product.dart';
import 'package:ssl_store/widgets/news_card.dart';
import 'package:ssl_store/widgets/owner_metric_card.dart';
import 'package:ssl_store/widgets/product_card.dart';
import 'package:ssl_store/widgets/store_info_card.dart';

/// Widget tests for the reusable, Firebase-free presentation layer. These lock
/// in what each card renders and how it reacts to taps — the safety net that
/// has to exist before any widget-tree restructuring or Riverpod migration.
///
/// Images use http URLs (not `assets/`) so ProductCard/NewsCard take their
/// `Image.network` branch, whose `errorBuilder` handles the test environment's
/// failed loads gracefully instead of throwing.
void main() {
  // Bounded box: these cards use Expanded/Row and need finite constraints.
  Widget host(Widget child, {double width = 360, double height = 280}) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      );

  Product product({
    String name = 'สร้อยคอทองคำ',
    double weight = 1.0,
    double laborFee = 500,
    int stock = 10,
  }) =>
      Product(
        id: 'PRD-1',
        name: name,
        description: 'desc',
        weight: weight,
        laborFee: laborFee,
        costBasis: 38000,
        stock: stock,
        imageUrl: 'https://example.com/ring.png',
        category: 'necklace',
      );

  final rate = GoldRate(
    buyPrice: 40000,
    sellPrice: 41000,
    timestamp: DateTime(2026, 6, 10),
  );

  group('ProductCard', () {
    testWidgets('renders name, weight, and the live price', (tester) async {
      await tester.pumpWidget(host(
        ProductCard(product: product(), currentRate: rate, onTap: () {}),
        width: 180,
        height: 260,
      ));

      expect(find.text('สร้อยคอทองคำ'), findsOneWidget);
      expect(find.text('1.0 บาท'), findsOneWidget);
      // totalPrice = weight*sellPrice + laborFee = 41000 + 500 = 41,500.
      expect(find.text('฿41,500'), findsOneWidget);
    });

    testWidgets('shows a loading spinner until a rate arrives', (tester) async {
      await tester.pumpWidget(host(
        ProductCard(product: product(), currentRate: null, onTap: () {}),
        width: 180,
        height: 260,
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('an in-stock card is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(
        ProductCard(
          product: product(stock: 8),
          currentRate: rate,
          onTap: () => tapped = true,
        ),
        width: 180,
        height: 260,
      ));
      await tester.tap(find.byType(ProductCard));
      expect(tapped, isTrue);
    });

    testWidgets('an out-of-stock card shows the badge and ignores taps',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(
        ProductCard(
          product: product(stock: 0),
          currentRate: rate,
          onTap: () => tapped = true,
        ),
        width: 180,
        height: 260,
      ));

      expect(find.text('สินค้าหมด'), findsOneWidget);
      await tester.tap(find.byType(ProductCard), warnIfMissed: false);
      expect(tapped, isFalse);
    });
  });

  group('NewsCard', () {
    testWidgets('renders title, summary, and a formatted date', (tester) async {
      await tester.pumpWidget(host(
        NewsCard(
          newsItem: NewsItem(
            id: 'N1',
            title: 'ราคาทองพุ่ง',
            summary: 'ทองคำปรับตัวขึ้น',
            imageUrl: 'https://example.com/n.png',
            date: DateTime(2026, 6, 9),
            content: '...',
          ),
        ),
        height: 140,
      ));

      expect(find.text('ราคาทองพุ่ง'), findsOneWidget);
      expect(find.text('ทองคำปรับตัวขึ้น'), findsOneWidget);
      expect(find.text('9/6/2026'), findsOneWidget);
    });
  });

  group('OwnerMetricCard', () {
    testWidgets('shows a skeleton while waiting, then the streamed value',
        (tester) async {
      await tester.pumpWidget(host(
        OwnerMetricCard(
          title: 'กำไร',
          icon: Icons.trending_up,
          color: Colors.green,
          stream: Stream.value('฿1.2M'),
        ),
        width: 200,
        height: 150,
      ));

      // First frame: stream still in waiting state, value not yet shown.
      expect(find.text('฿1.2M'), findsNothing);

      await tester.pump(); // deliver the stream event
      expect(find.text('กำไร'), findsOneWidget);
      expect(find.text('฿1.2M'), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(
        OwnerMetricCard(
          title: 'รายได้',
          icon: Icons.attach_money,
          color: Colors.blue,
          stream: Stream.value('฿500'),
          onTap: () => tapped = true,
        ),
        width: 200,
        height: 150,
      ));
      await tester.pump();
      await tester.tap(find.byType(OwnerMetricCard));
      expect(tapped, isTrue);
    });
  });

  group('StoreInfoCard', () {
    testWidgets('builds and renders store content without throwing',
        (tester) async {
      // Full surface (not the tight SizedBox) — the action-button row needs the
      // real screen width; the scroll view absorbs the height.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: StoreInfoCard()),
        ),
      ));
      expect(find.byType(StoreInfoCard), findsOneWidget);
      // The call + map action buttons are always present.
      expect(find.byIcon(Icons.call), findsOneWidget);
      expect(find.byIcon(Icons.map), findsOneWidget);
    });
  });
}
