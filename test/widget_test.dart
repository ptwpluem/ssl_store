import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/gold_rate.dart';
import 'package:ssl_store/widgets/gold_rate_card.dart';

/// Smoke test for a real, Firebase-free app widget. The live gold-rate card is
/// the most-seen element on the home screen, so we verify it renders its
/// labels and formats prices with thousands separators.
///
/// NOTE: a full app-boot / login smoke test is deferred — `MyApp` -> `AuthGate`
/// touches `FirebaseAuth.instance`, which needs Firebase Core mocks to pump in a
/// test. Tracked under Milestone B in ROADMAP.md.
void main() {
  testWidgets('GoldRateCard renders labels and formatted prices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoldRateCard(
            rate: GoldRate(
              buyPrice: 41000,
              sellPrice: 41100,
              timestamp: DateTime(2026, 6, 10, 9, 5),
              trend: 'up',
            ),
          ),
        ),
      ),
    );

    expect(find.text('ราคาทองวันนี้ (96.5%)'), findsOneWidget);
    expect(find.text('ราคารับซื้อ'), findsOneWidget);
    expect(find.text('ราคาขายออก'), findsOneWidget);

    // Prices are formatted with a thousands separator.
    expect(find.text('41,000'), findsOneWidget);
    expect(find.text('41,100'), findsOneWidget);
    expect(find.textContaining('09:05'), findsOneWidget);
  });
}
