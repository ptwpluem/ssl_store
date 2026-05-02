// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/gold_rate.dart';

// ─── Design tokens (matches owner dashboard) ──────────────────────────────────
const Color _cardPrimary = Color(0xFF800000);
const Color _cardGold    = Color(0xFFFFD700);

// Cached formatter — not rebuilt on every build()
final _priceFmt = NumberFormat('#,##0');

class ProductCard extends StatelessWidget {
  final Product product;
  final GoldRate? currentRate;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.currentRate,
    required this.onTap,
  });

  Widget _buildImage(bool isOutOfStock) {
    final img = product.imageUrl.startsWith('assets/')
        ? Image.asset(product.imageUrl, fit: BoxFit.cover)
        : Image.network(
            product.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF5F7FA),
              child: Icon(Icons.image_not_supported_rounded,
                  size: 40, color: Colors.grey[300]),
            ),
          );
    if (!isOutOfStock) return img;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]),
      child: img,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Price calculation (logic unchanged) ────────────────────────────────
    final double basePrice =
        currentRate != null ? (product.weight * currentRate!.sellPrice) : 0;
    final double totalPrice = basePrice + product.laborFee;
    final bool isOutOfStock = product.stock <= 0;
    final bool isLowStock = !isOutOfStock && product.stock <= 5;

    return GestureDetector(
      onTap: isOutOfStock ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOutOfStock
                ? Colors.grey.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image area ─────────────────────────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _buildImage(isOutOfStock),
                  ),

                  // Out-of-stock overlay
                  if (isOutOfStock)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'สินค้าหมด',
                            style: TextStyle(
                              color: Color(0xFF800000),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Stock badge (top-right)
                  if (!isOutOfStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isLowStock
                              ? Colors.orange.withValues(alpha: 0.9)
                              : const Color(0xFF2E7D32).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'เหลือ ${product.stock}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info area ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isOutOfStock ? Colors.grey : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Weight chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _cardGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${product.weight} บาท',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A5800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Price
                  if (currentRate != null)
                    Text(
                      '฿${_priceFmt.format(totalPrice)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock ? Colors.grey : _cardPrimary,
                      ),
                    )
                  else
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _cardPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
