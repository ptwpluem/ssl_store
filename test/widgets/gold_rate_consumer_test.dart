import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/gold_rate.dart';
import 'package:ssl_store/providers/app_providers.dart';
import 'package:ssl_store/widgets/gold_rate_card.dart';
import 'package:ssl_store/widgets/gold_rate_consumer.dart';

/// Demonstrates the injectable-screen pattern: pump a real consumer widget and
/// drive it entirely by overriding [goldRateProvider] — no Firebase, fully
/// deterministic across loading / data / error.
void main() {
  Widget appWith(Stream<GoldRate> stream) => ProviderScope(
        overrides: [goldRateProvider.overrideWith((ref) => stream)],
        child: const MaterialApp(home: Scaffold(body: GoldRateConsumer())),
      );

  final rate = GoldRate(
    buyPrice: 40000,
    sellPrice: 41000,
    timestamp: DateTime(2026, 6, 10, 9, 5),
  );

  testWidgets('shows a loader first, then the rate card', (tester) async {
    await tester.pumpWidget(appWith(Stream.value(rate)));

    // Initial frame: provider is still loading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GoldRateCard), findsNothing);

    await tester.pump(); // deliver the stream value
    expect(find.byType(GoldRateCard), findsOneWidget);
    expect(find.text('41,000'), findsOneWidget); // sell price, formatted
  });

  testWidgets('shows an error message when the stream errors', (tester) async {
    await tester.pumpWidget(
      appWith(Stream.fromFuture(Future<GoldRate>.error(Exception('boom')))),
    );
    await tester.pump(); // deliver the error event
    await tester.pump(const Duration(milliseconds: 10)); // settle to AsyncError

    expect(find.text('ไม่สามารถโหลดราคาทองได้'), findsOneWidget);
    expect(find.byType(GoldRateCard), findsNothing);
  });
}
