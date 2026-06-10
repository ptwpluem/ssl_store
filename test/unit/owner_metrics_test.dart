import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/utils/owner_metrics.dart';

/// The owner dashboard reports the shop's money — wallet float, stock value,
/// investment, savings liability, and period profit/revenue/cost. This pins
/// that math now that it lives in a pure helper instead of stream callbacks.
void main() {
  Map<String, dynamic> tx({
    String type = 'buy',
    double amount = 0,
    double profit = 0,
    double cost = 0,
    DateTime? at,
  }) =>
      {
        'type': type,
        'amount': amount,
        'profit': profit,
        'cost': cost,
        if (at != null) 'timestamp': Timestamp.fromDate(at),
      };

  group('balance-sheet aggregations', () {
    test('walletTotal sums every wallet balance', () {
      expect(
        OwnerMetrics.walletTotal([
          {'balance': 1000},
          {'balance': 250.5},
          {'other': 1}, // missing balance -> treated as 0
        ]),
        1250.5,
      );
    });

    test('stockValue = Σ stock × (weight × sellRate + laborFee)', () {
      final products = [
        {'stock': 2, 'weight': 1.0, 'laborFee': 500.0}, // 2*(40000+500)=81000
        {'stock': 3, 'weight': 0.5, 'laborFee': 0.0}, // 3*(20000)=60000
      ];
      expect(OwnerMetrics.stockValue(products, 40000), 141000.0);
    });

    test('stockInvestment = Σ stock × costBasis', () {
      expect(
        OwnerMetrics.stockInvestment([
          {'stock': 2, 'costBasis': 38000.0},
          {'stock': 1, 'costBasis': 19000.0},
        ]),
        95000.0,
      );
    });

    test('savingsWeight sums saved gold across accounts', () {
      expect(
        OwnerMetrics.savingsWeight([
          {'totalWeightSaved': 1.5},
          {'totalWeightSaved': 0.25},
        ]),
        1.75,
      );
    });

    test('empty inputs aggregate to zero', () {
      expect(OwnerMetrics.walletTotal([]), 0.0);
      expect(OwnerMetrics.stockValue([], 40000), 0.0);
      expect(OwnerMetrics.stockInvestment([]), 0.0);
      expect(OwnerMetrics.savingsWeight([]), 0.0);
    });
  });

  group('inRange', () {
    final range = DateTimeRange(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 30),
    );

    test('null range or null timestamp is always in range', () {
      expect(OwnerMetrics.inRange(DateTime(2020), null), isTrue);
      expect(OwnerMetrics.inRange(null, range), isTrue);
    });

    test('includes the whole start and end days', () {
      expect(OwnerMetrics.inRange(DateTime(2026, 6, 1, 0, 0, 0), range), isTrue);
      expect(OwnerMetrics.inRange(DateTime(2026, 6, 30, 23, 59, 59), range), isTrue);
    });

    test('excludes timestamps outside the range', () {
      expect(OwnerMetrics.inRange(DateTime(2026, 5, 31, 23, 59), range), isFalse);
      expect(OwnerMetrics.inRange(DateTime(2026, 7, 1, 0, 0, 1), range), isFalse);
    });
  });

  group('period aggregations', () {
    final june = DateTimeRange(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 30),
    );

    test('profit sums only in-range transactions', () {
      final txns = [
        tx(profit: 100, at: DateTime(2026, 6, 10)),
        tx(profit: 50, at: DateTime(2026, 6, 20)),
        tx(profit: 999, at: DateTime(2026, 7, 1)), // out of range
      ];
      expect(OwnerMetrics.profit(txns, june), 150.0);
      expect(OwnerMetrics.profit(txns, null), 1149.0); // no filter
    });

    test('revenue counts buy amount and redeem profit, ignoring others', () {
      final txns = [
        tx(type: 'buy', amount: 41000, at: DateTime(2026, 6, 5)),
        tx(type: 'redeem', profit: 500, at: DateTime(2026, 6, 6)),
        tx(type: 'sell', amount: 9999, at: DateTime(2026, 6, 7)), // ignored
      ];
      expect(OwnerMetrics.revenue(txns, june), 41500.0);
    });

    test('cost sums in-range cost', () {
      final txns = [
        tx(cost: 38000, at: DateTime(2026, 6, 5)),
        tx(cost: 1000, at: DateTime(2026, 5, 1)), // out of range
      ];
      expect(OwnerMetrics.cost(txns, june), 38000.0);
    });

    test('countInRange counts only in-range rows', () {
      final txns = [
        tx(at: DateTime(2026, 6, 5)),
        tx(at: DateTime(2026, 6, 6)),
        tx(at: DateTime(2026, 1, 1)),
      ];
      expect(OwnerMetrics.countInRange(txns, june), 2);
    });
  });

  group('formatCurrency', () {
    test('compacts millions and thousands, keeps small amounts exact', () {
      expect(OwnerMetrics.formatCurrency(2500000), '฿2.5M');
      expect(OwnerMetrics.formatCurrency(41500), '฿41.5k');
      expect(OwnerMetrics.formatCurrency(250), '฿250');
    });

    test('prefixes negatives with -฿', () {
      expect(OwnerMetrics.formatCurrency(-1500), '-฿1.5k');
    });
  });
}
