import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'gold_rate_card.dart';

/// Subscribes to the live gold rate via Riverpod and renders the rate card, a
/// loader, or an error message.
///
/// Because it reads [goldRateProvider], it can be tested in isolation by
/// overriding that provider with a fake stream — no Firebase needed. This is
/// the injectable-screen pattern the rest of the UI will follow.
class GoldRateConsumer extends ConsumerWidget {
  const GoldRateConsumer({super.key, this.loadingColor = const Color(0xFF800000)});

  final Color loadingColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(goldRateProvider);
    const errorWidget = Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('ไม่สามารถโหลดราคาทองได้'),
      ),
    );
    // Check error first: a stream that errors before its first value sits in a
    // loading-with-error state, which `.when` would otherwise show as loading.
    if (rate.hasError) return errorWidget;
    return rate.when(
      data: (r) => GoldRateCard(rate: r),
      loading: () => Center(
        child: CircularProgressIndicator(color: loadingColor),
      ),
      error: (_, __) => errorWidget,
    );
  }
}
