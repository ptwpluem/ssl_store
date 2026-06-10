import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateTimeRange;

/// Pure financial aggregations for the owner dashboard.
///
/// Extracted out of `owner_overview_tab.dart` so the screen "mostly renders"
/// and this money math is unit-testable. Each function takes the raw Firestore
/// document data (`Map<String, dynamic>`) and returns a number — no widgets,
/// no streams, no I/O.
class OwnerMetrics {
  OwnerMetrics._();

  /// Total cash held across all customer wallets.
  static double walletTotal(Iterable<Map<String, dynamic>> wallets) =>
      wallets.fold(
        0.0,
        (acc, w) => acc + ((w['balance'] as num?)?.toDouble() ?? 0.0),
      );

  /// Retail value of all stock: Σ stock × (weight × sellRate + laborFee).
  static double stockValue(
    Iterable<Map<String, dynamic>> products,
    double sellRate,
  ) =>
      products.fold(0.0, (acc, p) {
        final stock = (p['stock'] as num?)?.toInt() ?? 0;
        final weight = (p['weight'] as num?)?.toDouble() ?? 0.0;
        final laborFee = (p['laborFee'] as num?)?.toDouble() ?? 0.0;
        return acc + stock * ((weight * sellRate) + laborFee);
      });

  /// Capital tied up in stock at cost: Σ stock × costBasis.
  static double stockInvestment(Iterable<Map<String, dynamic>> products) =>
      products.fold(0.0, (acc, p) {
        final stock = (p['stock'] as num?)?.toInt() ?? 0;
        final costBasis = (p['costBasis'] as num?)?.toDouble() ?? 0.0;
        return acc + stock * costBasis;
      });

  /// Total gold weight customers have saved (the shop's savings liability,
  /// before multiplying by the sell rate). Caller passes only `account` docs.
  static double savingsWeight(Iterable<Map<String, dynamic>> accountDatas) =>
      accountDatas.fold(
        0.0,
        (acc, d) => acc + ((d['totalWeightSaved'] as num?)?.toDouble() ?? 0.0),
      );

  /// Inclusive of the full start day through the last millisecond of the end
  /// day. Null range or null timestamp ⇒ always in range.
  static bool inRange(DateTime? ts, DateTimeRange? range) {
    if (range == null || ts == null) return true;
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );
    return !ts.isBefore(start) && !ts.isAfter(end);
  }

  /// Σ profit over in-range transactions (caller pre-filters by type).
  static double profit(
    Iterable<Map<String, dynamic>> txns,
    DateTimeRange? range,
  ) =>
      _inRange(txns, range).fold(
        0.0,
        (acc, t) => acc + ((t['profit'] as num?)?.toDouble() ?? 0.0),
      );

  /// Revenue over in-range transactions: a `buy` contributes its amount, a
  /// `redeem` contributes its profit (interest), matching the dashboard.
  static double revenue(
    Iterable<Map<String, dynamic>> txns,
    DateTimeRange? range,
  ) =>
      _inRange(txns, range).fold(0.0, (acc, t) {
        final type = t['type'] as String?;
        if (type == 'buy') return acc + ((t['amount'] as num?)?.toDouble() ?? 0.0);
        if (type == 'redeem') {
          return acc + ((t['profit'] as num?)?.toDouble() ?? 0.0);
        }
        return acc;
      });

  /// Σ cost over in-range transactions.
  static double cost(
    Iterable<Map<String, dynamic>> txns,
    DateTimeRange? range,
  ) =>
      _inRange(txns, range).fold(
        0.0,
        (acc, t) => acc + ((t['cost'] as num?)?.toDouble() ?? 0.0),
      );

  /// Count of in-range transactions (caller pre-filters by type).
  static int countInRange(
    Iterable<Map<String, dynamic>> txns,
    DateTimeRange? range,
  ) =>
      _inRange(txns, range).length;

  /// Compact currency label: ฿1.2M / ฿3.4k / ฿250, with a leading minus.
  static String formatCurrency(double amount) {
    final negative = amount < 0;
    final abs = amount.abs();
    final prefix = negative ? '-฿' : '฿';
    if (abs >= 1000000) return '$prefix${(abs / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '$prefix${(abs / 1000).toStringAsFixed(1)}k';
    return '$prefix${abs.toStringAsFixed(0)}';
  }

  static Iterable<Map<String, dynamic>> _inRange(
    Iterable<Map<String, dynamic>> txns,
    DateTimeRange? range,
  ) =>
      txns.where((t) => inRange((t['timestamp'] as Timestamp?)?.toDate(), range));
}
