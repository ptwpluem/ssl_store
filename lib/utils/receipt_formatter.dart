import 'package:intl/intl.dart';

import '../models/gold_transaction.dart';

/// Builds a plain-text Thai receipt for a transaction.
///
/// Pure and testable. The actual delivery (share sheet / PDF / printer) is a
/// device-only concern deferred per ROADMAP Milestone E — this is the content
/// those would render, and is unit-tested here.
class ReceiptFormatter {
  ReceiptFormatter._();

  static const String defaultShopName = 'ห้างทองซุ่นเซ่งหลี';

  static String typeLabel(TransactionType type) => switch (type) {
        TransactionType.buy => 'ซื้อทอง',
        TransactionType.sell => 'ขายคืน',
        TransactionType.pawn => 'จำนำ',
        TransactionType.redeem => 'ไถ่ถอน',
        TransactionType.savings_deposit => 'ออมทอง (ฝาก)',
        TransactionType.savings_withdraw => 'ออมทอง (ถอน)',
        TransactionType.savings_physical_withdraw => 'ถอนทองแท่ง',
      };

  static String format(GoldTransaction tx, {String shopName = defaultShopName}) {
    final baht = NumberFormat('#,##0.00');
    final date = DateFormat('dd/MM/yyyy HH:mm');
    const divider = '----------------------------------------';

    final lines = <String>[
      shopName,
      'ใบเสร็จรับเงิน',
      divider,
      'เลขที่: ${tx.id}',
      'วันที่: ${date.format(tx.timestamp)} น.',
      'รายการ: ${typeLabel(tx.type)}',
      if (tx.details.isNotEmpty) 'รายละเอียด: ${tx.details}',
      'น้ำหนัก: ${tx.weight} บาท',
      'ความบริสุทธิ์: ${(tx.purity * 100).toStringAsFixed(2)}%',
      if (tx.laborFee != null) 'ค่ากำเหน็จ: ฿${baht.format(tx.laborFee)}',
      divider,
      'จำนวนเงิน: ฿${baht.format(tx.amount)}',
      'ขอบคุณที่ใช้บริการ',
    ];
    return lines.join('\n');
  }
}
