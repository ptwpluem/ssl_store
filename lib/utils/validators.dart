/// Pure form-field validators. Each returns `null` when the input is valid, or
/// a Thai error message otherwise — the shape `TextFormField.validator` wants.
///
/// Keeping them here (instead of inline in each form) makes the rules
/// consistent across screens and unit-testable without pumping any UI.
class Validators {
  Validators._();

  /// Required free-text field (name, etc.). [field] names it in the message.
  static String? requiredField(String? value, {String field = 'ข้อมูลนี้'}) {
    if (value == null || value.trim().isEmpty) return 'กรุณากรอก$field';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'กรุณากรอกอีเมล';
    // Pragmatic check: something@something.tld
    final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!re.hasMatch(v)) return 'รูปแบบอีเมลไม่ถูกต้อง';
    return null;
  }

  /// Thai mobile number: 10 digits starting with 0 (spaces/dashes ignored).
  static String? thaiPhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (digits.isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
    if (!RegExp(r'^0\d{9}$').hasMatch(digits)) {
      return 'เบอร์โทรศัพท์ต้องเป็นตัวเลข 10 หลัก ขึ้นต้นด้วย 0';
    }
    return null;
  }

  /// Password for sign-up / change-password. Min 8 chars with at least one
  /// letter and one digit.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (v.length < 8) return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'รหัสผ่านต้องมีทั้งตัวอักษรและตัวเลข';
    }
    return null;
  }

  /// Confirm-password must match [original].
  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'รหัสผ่านไม่ตรงกัน';
    return null;
  }

  /// A positive THB amount. Returns the parsed value via [onParsed] is not
  /// done here — callers parse separately; this only validates.
  static String? positiveAmount(String? value) {
    final v = (value ?? '').replaceAll(',', '').trim();
    if (v.isEmpty) return 'กรุณากรอกจำนวนเงิน';
    final amount = double.tryParse(v);
    if (amount == null) return 'จำนวนเงินไม่ถูกต้อง';
    if (amount <= 0) return 'จำนวนเงินต้องมากกว่า 0';
    return null;
  }

  /// A positive amount that must not exceed [max] (e.g. loan ≤ max loan,
  /// withdrawal ≤ balance). [label] names the ceiling in the message.
  static String? amountWithin(
    String? value,
    double max, {
    String label = 'วงเงิน',
  }) {
    final base = positiveAmount(value);
    if (base != null) return base;
    final amount = double.parse((value ?? '').replaceAll(',', '').trim());
    if (amount > max) return 'จำนวนต้องไม่เกิน$label';
    return null;
  }

  /// Withdrawable gold weight: a positive multiple of 0.25 baht.
  static String? quarterBahtWeight(double? weight) {
    if (weight == null || weight <= 0) return 'กรุณาเลือกน้ำหนัก';
    if ((weight * 4) % 1 != 0) {
      return 'น้ำหนักต้องเป็นทวีคูณของ 0.25 บาท';
    }
    return null;
  }
}
