import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/models/gold_transaction.dart';
import 'package:ssl_store/utils/receipt_formatter.dart';

void main() {
  GoldTransaction tx({
    TransactionType type = TransactionType.buy,
    double amount = 41000,
    double weight = 1.0,
    double purity = 0.965,
    double? laborFee,
    String details = 'ซื้อ: สร้อยคอ',
  }) =>
      GoldTransaction(
        id: 'BUY-1',
        assetId: 'AST-1',
        type: type,
        amount: amount,
        weight: weight,
        purity: purity,
        laborFee: laborFee,
        timestamp: DateTime(2026, 6, 10, 14, 30),
        details: details,
        userId: 'u',
      );

  test('includes shop name, id, formatted date, type label and amount', () {
    final r = ReceiptFormatter.format(tx());
    expect(r, contains(ReceiptFormatter.defaultShopName));
    expect(r, contains('เลขที่: BUY-1'));
    expect(r, contains('10/06/2026 14:30'));
    expect(r, contains('ซื้อทอง'));
    expect(r, contains('฿41,000.00'));
    expect(r, contains('96.50%'));
  });

  test('shows the labor fee only when present', () {
    expect(ReceiptFormatter.format(tx(laborFee: 500)), contains('ค่ากำเหน็จ: ฿500.00'));
    expect(ReceiptFormatter.format(tx()), isNot(contains('ค่ากำเหน็จ')));
  });

  test('uses the right Thai label per transaction type', () {
    expect(ReceiptFormatter.typeLabel(TransactionType.pawn), 'จำนำ');
    expect(ReceiptFormatter.typeLabel(TransactionType.savings_deposit), 'ออมทอง (ฝาก)');
    expect(
      ReceiptFormatter.format(tx(type: TransactionType.redeem)),
      contains('รายการ: ไถ่ถอน'),
    );
  });

  test('honours a custom shop name', () {
    expect(ReceiptFormatter.format(tx(), shopName: 'ร้านทองทดสอบ'),
        startsWith('ร้านทองทดสอบ'));
  });
}
