class GoldAsset {
  final String id; // PRD-4GUNEfW32djCVMjx9c13
  final String name; // สร้อยคอทองคำ ลายเบนซ์
  final double weight; // 0.5
  final String category; // สร้อยคอ
  final DateTime acquisitionDate;
  final double acquisitionPrice; // ราคาซื้อ (ต้นทุน)
  final String status; // 'owned', 'sold', 'pawned'
  final double? loanAmount; // ยอดกู้ กรณีจำนำ
  final DateTime? pawnDate; // วันที่จำนำ
  final DateTime? dueDate;
  final double? interestRate;
  final double purity; // 0.965 or 0.9999

  GoldAsset({
    required this.id,
    required this.name,
    required this.weight,
    required this.category,
    required this.acquisitionDate,
    required this.acquisitionPrice,
    this.status = 'owned',
    this.loanAmount,
    this.pawnDate,
    this.dueDate,
    this.interestRate,
    this.purity = 0.965,
  });

  // Calculate accrued interest (1.25% per month industry standard)
  double get accruedInterest {
    // ทุกครั้งที่อ่านค่าจะคำนวณให้อัตโนมัติ โดยไม่ต้องเก็บใน Firestore
    if (status != 'pawned' || loanAmount == null || pawnDate == null)
      return 0.0;

    final daysElapsed = DateTime.now().difference(pawnDate!).inDays;
    if (daysElapsed <= 0) return 0.0;

    // Monthly rate 1.25% -> Daily rate approximately 0.0125 / 30
    final monthlyRate = interestRate ?? 0.0125;
    final dailyRate = monthlyRate / 30;

    return loanAmount! * dailyRate * daysElapsed;
  }

  double get totalRedemptionAmount {
    return (loanAmount ?? 0.0) + accruedInterest;
  }

  GoldAsset copyWith({
    String? status,
    double? loanAmount,
    DateTime? pawnDate,
    DateTime? dueDate,
    double? interestRate,
    bool clearLoan = false, // Helper to nullify loan fields when redeeming
  }) {
    return GoldAsset(
      id: id,
      name: name,
      weight: weight,
      category: category,
      acquisitionDate: acquisitionDate,
      acquisitionPrice: acquisitionPrice,
      status: status ?? this.status,
      loanAmount: clearLoan ? null : (loanAmount ?? this.loanAmount),
      pawnDate: clearLoan ? null : (pawnDate ?? this.pawnDate),
      dueDate: clearLoan ? null : (dueDate ?? this.dueDate),
      interestRate: clearLoan ? null : (interestRate ?? this.interestRate),
      purity: purity, // Purity doesn't usually change for an asset
    );
  }
}
