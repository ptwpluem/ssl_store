// lib/pages/owner/owner_inventory_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/catalog_service.dart';

class OwnerInventoryTab extends StatelessWidget {
  const OwnerInventoryTab({super.key});

  static const Color _primary = Color(0xFF800000);
  static const Color _textDark = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildInventoryList()),
      ],
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 22,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.inventory_2_rounded, size: 18, color: _primary),
          const SizedBox(width: 8),
          const Text(
            'จัดการคลังสินค้า',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textDark,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Inventory List ───────────────────────────────────────────────────────

  Widget _buildInventoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: _primary, strokeWidth: 2.5),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('ไม่พบสินค้าในคลัง',
                    style: TextStyle(color: Colors.grey[400], fontSize: 15)),
              ],
            ),
          );
        }

        final formatter = NumberFormat('#,##0.00');

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final name = data['name'] as String? ?? 'Unknown Product';
            final stock = (data['stock'] as num?)?.toInt() ?? 0;
            final inStock = data['inStock'] as bool? ?? true;
            final priceOffset =
                (data['priceOffset'] as num?)?.toDouble() ?? 0.0;
            final weight = (data['weight'] as num?)?.toDouble() ?? 1.0;

            final isOutOfStock = stock <= 0 || !inStock;
            final isLowStock = stock > 0 && stock <= 3;

            return _buildProductCard(
              context: context,
              docId: doc.id,
              name: name,
              stock: stock,
              weight: weight,
              priceOffset: priceOffset,
              isOutOfStock: isOutOfStock,
              isLowStock: isLowStock,
              formatter: formatter,
            );
          },
        );
      },
    );
  }

  // ─── Product Card ─────────────────────────────────────────────────────────

  Widget _buildProductCard({
    required BuildContext context,
    required String docId,
    required String name,
    required int stock,
    required double weight,
    required double priceOffset,
    required bool isOutOfStock,
    required bool isLowStock,
    required NumberFormat formatter,
  }) {
    // Stock badge config
    final Color badgeColor;
    final Color badgeBg;
    final String badgeText;
    final IconData badgeIcon;

    if (isOutOfStock) {
      badgeColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFFEF2F2);
      badgeText = 'สินค้าหมด';
      badgeIcon = Icons.remove_circle_outline_rounded;
    } else if (isLowStock) {
      badgeColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFFFFFBEB);
      badgeText = 'เหลือน้อย: $stock';
      badgeIcon = Icons.warning_amber_rounded;
    } else {
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFECFDF5);
      badgeText = 'คงเหลือ: $stock';
      badgeIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F1F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Product icon box
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isOutOfStock
                      ? [Colors.grey[100]!, Colors.grey[200]!]
                      : [const Color(0xFFFFF8E7), const Color(0xFFFFF0C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.diamond_outlined,
                color: isOutOfStock
                    ? Colors.grey[400]
                    : const Color(0xFFB8860B),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isOutOfStock ? Colors.grey[400] : _textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _infoChip(
                        '${weight.toStringAsFixed(2)} บาท',
                        Icons.scale_rounded,
                      ),
                      const SizedBox(width: 6),
                      _infoChip(
                        '+฿${formatter.format(priceOffset)}',
                        Icons.price_change_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Stock badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 12, color: badgeColor),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionButton(
                  icon: Icons.add_rounded,
                  color: const Color(0xFF1976D2),
                  bgColor: const Color(0xFFEFF6FF),
                  tooltip: 'เติมสินค้า',
                  onTap: () => _showRestockDialog(context, docId, name, weight),
                ),
                const SizedBox(height: 6),
                _actionButton(
                  icon: Icons.edit_rounded,
                  color: Colors.grey[400]!,
                  bgColor: const Color(0xFFF5F7FA),
                  tooltip: 'แก้ไข',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'ระบบแก้ไขข้อมูลสินค้าจะเปิดใช้งานเร็วๆ นี้'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey[500]),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // ─── Restock Dialog ───────────────────────────────────────────────────────

  void _showRestockDialog(
      BuildContext context, String productId, String productName, double weight) {
    final qtyCtrl = TextEditingController(text: '1');
    final unitCostCtrl = TextEditingController();
    final fmt = NumberFormat('#,##0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final qty = int.tryParse(qtyCtrl.text) ?? 0;
          final unitCost = double.tryParse(unitCostCtrl.text) ?? 0.0;
          final totalCost = qty * unitCost;
          final hasTotal = qty > 0 && unitCost > 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_box_rounded,
                      color: Color(0xFF1976D2), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('เติมสินค้า',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        productName,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.normal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),

                // ── Quantity ──────────────────────────────────────────
                TextField(
                  controller: qtyCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'จำนวนที่เติม (ชิ้น)',
                    prefixIcon: const Icon(
                        Icons.add_shopping_cart_rounded, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),

                // ── Unit cost ─────────────────────────────────────────
                TextField(
                  controller: unitCostCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'ต้นทุนต่อชิ้น (฿)',
                    prefixIcon:
                        const Icon(Icons.payments_rounded, size: 20),
                    prefixText: '฿ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*')),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Total cost summary ────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: hasTotal
                        ? const Color(0xFFEFF6FF)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasTotal
                          ? const Color(0xFF1976D2).withValues(alpha: 0.3)
                          : Colors.grey[200]!,
                    ),
                  ),
                  child: hasTotal
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'รวมต้นทุนทั้งหมด',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '฿${fmt.format(totalCost)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$qty ชิ้น × ฿${fmt.format(unitCost.round())} = ฿${fmt.format(totalCost)}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        )
                      : Text(
                          'กรอกจำนวนและต้นทุนต่อชิ้นเพื่อดูยอดรวม',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[400]),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('ยกเลิก'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('ยืนยัน'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: !hasTotal
                    ? null // disable until both fields are filled
                    : () async {
                        try {
                          await CatalogService().restockProduct(
                            productId: productId,
                            productName: productName,
                            quantity: qty,
                            totalCost: totalCost,
                          );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ เพิ่ม $qty ชิ้น · ต้นทุนรวม ฿${fmt.format(totalCost)}',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ เกิดข้อผิดพลาด: $e'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}
