import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/widgets/low_stock_banner.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  Map<String, dynamic> p(String name) => {'name': name, 'stock': 1};

  testWidgets('renders nothing when stock is healthy', (tester) async {
    await tester.pumpWidget(host(
      const LowStockBanner(lowStock: [], outOfStock: []),
    ));
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // shrink only
  });

  testWidgets('summarises low + out of stock with up to 3 names', (tester) async {
    await tester.pumpWidget(host(
      LowStockBanner(
        lowStock: [p('แหวน'), p('สร้อย')],
        outOfStock: [p('กำไล')],
      ),
    ));

    expect(find.text('สินค้าหมด 1 รายการ • ใกล้หมด 2 รายการ'), findsOneWidget);
    expect(find.textContaining('กำไล'), findsOneWidget); // out-of-stock listed first
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('shows only the low-stock line when nothing is fully out', (tester) async {
    await tester.pumpWidget(host(
      LowStockBanner(lowStock: [p('แหวน')], outOfStock: const []),
    ));
    expect(find.text('ใกล้หมด 1 รายการ'), findsOneWidget);
  });
}
