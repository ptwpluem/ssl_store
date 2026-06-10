import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/gold_rate.dart';
import 'package:ssl_store/providers/app_providers.dart';

/// The provider is the DI seam: tests swap its backing stream with
/// `overrideWith`, exactly as a screen test would, with no Firebase.
///
/// Note: Riverpod 3 providers are auto-dispose by default, so each test keeps a
/// listener alive while awaiting `.future`; otherwise the provider disposes and
/// cancels its stream before it can emit.
void main() {
  final rate = GoldRate(
    buyPrice: 40000,
    sellPrice: 41000,
    timestamp: DateTime(2026, 6, 10),
  );

  test('goldRateProvider surfaces the value from its stream', () async {
    final container = ProviderContainer(overrides: [
      goldRateProvider.overrideWith((ref) => Stream.value(rate)),
    ]);
    addTearDown(container.dispose);
    container.listen(goldRateProvider, (_, _) {}, onError: (_, _) {});

    final result = await container.read(goldRateProvider.future);
    expect(result.sellPrice, 41000);
    expect(result.buyPrice, 40000);
  });

  test('goldRateProvider propagates a stream error as AsyncError', () async {
    final container = ProviderContainer(overrides: [
      goldRateProvider.overrideWith(
        (ref) => Stream.fromFuture(Future<GoldRate>.error(Exception('down'))),
      ),
    ]);
    addTearDown(container.dispose);
    container.listen(goldRateProvider, (_, _) {}, onError: (_, _) {});

    // Let the async error + stream-done propagate, then assert the provider
    // surfaced the failure.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(goldRateProvider).hasError, isTrue);
  });
}
