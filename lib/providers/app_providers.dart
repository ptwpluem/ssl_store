import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gold_rate.dart';
import '../models/gold_transaction.dart';
import '../services/market_service.dart';
import '../services/user_service.dart';

/// Application providers — the dependency-injection seam for the UI.
///
/// Screens read these instead of constructing services directly, which means a
/// test can swap any of them for a fake with `ProviderScope(overrides: [...])`.
/// This is the first slice of the Riverpod migration (the live gold rate); the
/// other streams follow the same shape.

/// The market data service. Overridable in tests to inject a fake Firestore.
final marketServiceProvider = Provider<MarketService>((ref) => MarketService());

/// The live gold rate, as a reactive stream. Widgets `ref.watch` this and get
/// loading / data / error states for free.
final goldRateProvider = StreamProvider<GoldRate>(
  (ref) => ref.watch(marketServiceProvider).getGoldRateStream(),
);

/// User-scoped data service (resolves the signed-in user internally).
/// Overridable in tests.
final userServiceProvider = Provider<UserService>((ref) => UserService());

/// The signed-in member's transaction history, newest first.
final transactionHistoryProvider = StreamProvider<List<GoldTransaction>>(
  (ref) => ref.watch(userServiceProvider).getTransactionHistoryStream(),
);
