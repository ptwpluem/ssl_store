class Product {
  final String id;
  final String name;
  final String description;
  final double weight; // In Baht (บาทน้ำหนัก)
  final double laborFee; // Cost of craftsmanship (ค่ากำเหน็จ)
  final double costBasis; // Owner's acquisition cost per unit (from latest restock lot)
  final int stock; // Available quantity
  final String imageUrl;
  final String category;

  // Selling price is NOT stored — it is always calculated live:
  //   sellPrice = (weight × market.sellPrice) + laborFee

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.weight,
    required this.laborFee,
    required this.costBasis,
    required this.stock,
    required this.imageUrl,
    required this.category,
  });

  Product copyWith({int? stock, double? costBasis}) {
    return Product(
      id: id,
      name: name,
      description: description,
      weight: weight,
      laborFee: laborFee,
      costBasis: costBasis ?? this.costBasis,
      stock: stock ?? this.stock,
      imageUrl: imageUrl,
      category: category,
    );
  }
}
