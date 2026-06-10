import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/gold_transaction.dart';
import 'package:ssl_store/pages/member/member_transactions_page.dart';
import 'package:ssl_store/providers/app_providers.dart';

/// Full-screen test of a ConsumerStatefulWidget driven entirely by overriding
/// transactionHistoryProvider — no Firebase. Exercises provider data + the
/// local filter state together.
void main() {
  GoldTransaction tx(TransactionType type, String details) => GoldTransaction(
        id: details,
        assetId: 'a',
        type: type,
        amount: 1000,
        weight: 1.0,
        timestamp: DateTime(2026, 6, 10, 10, 0),
        details: details,
        userId: 'u',
      );

  Widget scope(Stream<List<GoldTransaction>> stream) => ProviderScope(
        overrides: [
          transactionHistoryProvider.overrideWith((ref) => stream),
        ],
        child: const MaterialApp(home: TransactionHistoryPage()),
      );

  final sample = [
    tx(TransactionType.buy, 'BUY-A'),
    tx(TransactionType.sell, 'SELL-B'),
    tx(TransactionType.pawn, 'PAWN-C'),
    tx(TransactionType.redeem, 'REDEEM-D'),
    tx(TransactionType.savings_deposit, 'SAVE-E'),
  ];

  group('TxFilter grouping (pure)', () {
    test('pawnRedeem matches both pawn and redeem', () {
      expect(TxFilter.pawnRedeem.matches(TransactionType.pawn), isTrue);
      expect(TxFilter.pawnRedeem.matches(TransactionType.redeem), isTrue);
      expect(TxFilter.pawnRedeem.matches(TransactionType.buy), isFalse);
    });

    test('savings matches all three savings kinds', () {
      expect(TxFilter.savings.matches(TransactionType.savings_deposit), isTrue);
      expect(TxFilter.savings.matches(TransactionType.savings_withdraw), isTrue);
      expect(
        TxFilter.savings.matches(TransactionType.savings_physical_withdraw),
        isTrue,
      );
      expect(TxFilter.savings.matches(TransactionType.sell), isFalse);
    });

    test('all matches everything', () {
      for (final t in TransactionType.values) {
        expect(TxFilter.all.matches(t), isTrue);
      }
    });
  });

  testWidgets('loads, then lists every transaction', (tester) async {
    await tester.pumpWidget(scope(Stream.value(sample)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget); // loading

    await tester.pump(); // deliver data
    for (final d in ['BUY-A', 'SELL-B', 'PAWN-C', 'REDEEM-D', 'SAVE-E']) {
      expect(find.text(d), findsOneWidget);
    }
  });

  testWidgets('the buy filter narrows the list to buys', (tester) async {
    await tester.pumpWidget(scope(Stream.value(sample)));
    await tester.pump();

    await tester.tap(find.text('ซื้อ')); // the "buy" chip
    await tester.pump();

    expect(find.text('BUY-A'), findsOneWidget);
    expect(find.text('SELL-B'), findsNothing);
    expect(find.text('PAWN-C'), findsNothing);
  });

  testWidgets('the pawn/redeem filter shows both pawn and redeem', (tester) async {
    await tester.pumpWidget(scope(Stream.value(sample)));
    await tester.pump();

    await tester.tap(find.text('จำนำ/ไถ่ถอน'));
    await tester.pump();

    expect(find.text('PAWN-C'), findsOneWidget);
    expect(find.text('REDEEM-D'), findsOneWidget);
    expect(find.text('BUY-A'), findsNothing);
    expect(find.text('SAVE-E'), findsNothing);
  });

  testWidgets('shows the empty message when a filter matches nothing',
      (tester) async {
    await tester.pumpWidget(scope(Stream.value([tx(TransactionType.buy, 'BUY-A')])));
    await tester.pump();

    await tester.tap(find.text('ขาย')); // sell filter, no sells present
    await tester.pump();

    expect(find.text('ไม่พบประวัติการทำรายการ'), findsOneWidget);
    expect(find.text('BUY-A'), findsNothing);
  });
}
