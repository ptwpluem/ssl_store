import 'package:intl/intl.dart';

class FormatterUtils {
  static const _thaiMonths = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];

  static String formatThaiDateShort(DateTime date) {
    final year = date.year + 543;
    return '${date.day} ${_thaiMonths[date.month - 1]} $year';
  }

  static String formatThaiDateTime(DateTime date) {
    final timeStr = DateFormat('HH:mm').format(date);
    return '${formatThaiDateShort(date)} $timeStr น.';
  }
}
