import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';

class InquiryPage extends StatefulWidget {
  final Product? product;

  const InquiryPage({super.key, this.product});

  @override
  State<InquiryPage> createState() => _InquiryPageState();
}

class _InquiryPageState extends State<InquiryPage> {
  final _messageController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _messageController.text = 'ฉันสนใจสินค้า ${widget.product!.name} (น้ำหนัก: ${widget.product!.weight} บาท) มีสินค้าอยู่ไหมคะ/ครับ?';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
     if (_messageController.text.isNotEmpty) {
      // In real app, send to API
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งข้อความแล้ว! เราจะติดต่อกลับหาคุณเร็วๆ นี้')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สอบถามข้อมูล')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (widget.product != null)
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.amber[50],
                child: ListTile(
                  leading: const Icon(Icons.shopping_bag, color: Colors.amber),
                  title: const Text('สินค้าที่เลือก'),
                  subtitle: Text(
                    '${widget.product!.weight} บาทน้ำหนัก · ค่ากำเหน็จ ฿${NumberFormat('#,##0').format(widget.product!.laborFee)}',
                  ),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              ),
            const Text(
              'เราจะช่วยคุณได้อย่างไร?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'พิมพ์ข้อความของคุณที่นี่...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('สอบถามสินค้าในสต็อก'),
                  onPressed: () {
                    setState(() {
                      _messageController.text = 'มีสินค้านี้ในสต็อกตอนนี้ไหมคะ/ครับ?';
                    });
                  },
                ),
                ActionChip(
                  label: const Text('ขอสั่งทำพิเศษ'),
                  onPressed: () {
                    setState(() {
                      _messageController.text = 'ฉันต้องการสั่งทำสินค้าชิ้นนี้แบบพิเศษตามที่ต้องการครับ/ค่ะ';
                    });
                  },
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
              label: const Text('ส่งข้อความ'),
               style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
            ),
          ],
        ),
      ),
    );
  }
}
