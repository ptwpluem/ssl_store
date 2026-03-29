import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/gold_rate.dart';
import '../models/gold_transaction.dart';
import '../services/mock_service.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  final GoldRate? currentRate;

  const ProductDetailPage({super.key, required this.product, this.currentRate});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final MockService _service = MockService();
  bool _isProcessing = false;
  int _quantity = 1;

  void _showCheckoutBottomSheet(BuildContext context, double totalPrice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return StreamBuilder<double>(
              stream: _service.getWalletBalanceStream(),
              builder: (context, snapshot) {
                final balance = snapshot.data ?? 0.0;
                final hasEnoughFunds = balance >= totalPrice;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 24,
                    right: 24,
                    top: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('สรุปการชำระเงิน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF600000))),
                            const SizedBox(height: 16),
                            _summaryRow('รายการ', widget.product.name),
                            _summaryRow('จำนวน', '$_quantity'),
                            _summaryRow('น้ำหนักรวม', '${widget.product.weight * _quantity} บาท'),
                            _summaryRow('ราคาทอง', '฿ ${NumberFormat('#,##0').format(widget.product.weight * (widget.currentRate?.sellPrice ?? 0) * _quantity)}'),
                            _summaryRow('ค่ากำเหน็จ', '฿ ${NumberFormat('#,##0').format(widget.product.laborFee * _quantity)}'),
                            const Divider(height: 24),
                            _summaryRow('ยอดรวมทั้งสิ้น', '฿ ${NumberFormat('#,##0').format(totalPrice)}', isBold: true),
                            if (balance >= totalPrice) ...[
                              _summaryRow('เงินคงเหลือโดยประมาณ', '฿ ${NumberFormat('#,##0').format(balance - totalPrice)}', isBold: true),
                            ] else ...[
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16.0),
                                child: Text(
                                  'ยอดเงินในวอลเล็ตไม่เพียงพอ กรุณาเติมเงิน',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: (_isProcessing || !hasEnoughFunds)
                            ? null
                            : () async {
                          setModalState(() => _isProcessing = true);
                          try {
                            await _service.createTransaction(
                              assetName: widget.product.name,
                              weight: widget.product.weight * _quantity,
                              amount: totalPrice,
                              type: TransactionType.buy,
                              category: widget.product.category,
                              productId: widget.product.id,
                              quantity: _quantity,
                            );

                            if (mounted) {
                              Navigator.pop(context); // Close bottom sheet
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('ซื้อสำเร็จแล้ว! ตรวจสอบได้ที่พอร์ตโฟลิโอของคุณ')),
                              );
                              Navigator.pop(context); // Go back to catalog
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setModalState(() => _isProcessing = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: hasEnoughFunds ? const Color(0xFF800000) : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('ยืนยันการสั่งซื้อ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              }
            );
          }
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double basePrice = widget.currentRate != null ? (widget.product.weight * widget.currentRate!.sellPrice) : 0;
    double unitPrice = basePrice + widget.product.laborFee;
    double totalPrice = unitPrice * _quantity;
    bool isOutOfStock = widget.product.stock <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดสินค้า')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 350,
              width: double.infinity,
              color: Colors.white,
              child: Image.network(
                widget.product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.image, size: 100, color: Colors.grey[400]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isOutOfStock ? Colors.grey[200] : Colors.green[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOutOfStock ? 'สินค้าหมด' : 'คงเหลือ: ${widget.product.stock}',
                          style: TextStyle(
                            color: isOutOfStock ? Colors.grey[600] : Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.product.weight} บาท',
                        style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                      ),
                      if (widget.currentRate != null)
                        Text(
                          '฿ ${NumberFormat('#,##0').format(unitPrice)}',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor),
                        )
                      else
                        const CircularProgressIndicator(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Quantity Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('จำนวน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('ยอดรวม: ฿ ${NumberFormat('#,##0').format(totalPrice)}',
                              style: const TextStyle(color: Color(0xFF600000), fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                            ),
                            Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _quantity < widget.product.stock
                                  ? () => setState(() => _quantity++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text('รายละเอียดราคา', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (widget.currentRate != null) ...[
                    _summaryRow('ราคาทองวันนี้', '฿ ${NumberFormat('#,##0').format(widget.currentRate!.sellPrice)} / บาท'),
                    _summaryRow('มูลค่าทอง (${widget.product.weight} บาท)', '฿ ${NumberFormat('#,##0').format(basePrice)}'),
                    _summaryRow('ค่ากำเหน็จ', '฿ ${NumberFormat('#,##0').format(widget.product.laborFee)}'),
                  ],
                  const SizedBox(height: 24),
                  const Text('คำอธิบายสินค้า', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.product.description, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: isOutOfStock || widget.currentRate == null
                ? null
                : () => _showCheckoutBottomSheet(context, totalPrice),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: const Color(0xFF800000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isOutOfStock ? 'สินค้าหมด' : 'ซื้อทันที',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
