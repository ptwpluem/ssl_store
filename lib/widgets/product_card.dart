import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/gold_rate.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final GoldRate? currentRate;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, this.currentRate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Dynamic Price Calculation
    double basePrice = currentRate != null ? (product.weight * currentRate!.sellPrice) : 0;
    double totalPrice = basePrice + product.laborFee;
    bool isOutOfStock = product.stock <= 0;

    return GestureDetector(
      onTap: isOutOfStock ? null : onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      color: Colors.white,
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.image, size: 50, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  if (isOutOfStock)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: const Center(
                        child: Text(
                          'สินค้า\nหมด',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isOutOfStock ? Colors.grey : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${product.weight} บาท',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        'คงเหลือ: ${product.stock}',
                        style: TextStyle(
                            color: isOutOfStock ? Colors.red : Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (currentRate != null)
                    Text(
                      '฿${NumberFormat('#,##0').format(totalPrice)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF600000),
                      ),
                    )
                  else
                    const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
