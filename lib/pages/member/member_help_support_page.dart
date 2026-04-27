import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ความช่วยเหลือและติดต่อเรา'),
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'ติดต่อเรา',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.2),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('กำลังเปิดแอปโทรศัพท์...')));
                    },
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF800000).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.phone, color: Color(0xFF800000)),
                    ),
                    title: const Text('โทรสอบถาม',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('+66 2 123 4567',
                        style: TextStyle(fontSize: 13)),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                  const Divider(
                      height: 1,
                      indent: 64,
                      thickness: 1,
                      color: Color(0xFFF0F0F0)),
                  ListTile(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('กำลังเปิดแอป LINE...')));
                    },
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06C755).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.chat_bubble,
                          color: Color(0xFF06C755)),
                    ),
                    title: const Text('LINE ทางการ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('@sungsengleegold',
                        style: TextStyle(fontSize: 13)),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'คำถามที่พบบ่อย (FAQ)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.2),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Column(
                children: [
                  ExpansionTile(
                    title: Text('ซื้อทองออนไลน์ได้อย่างไร?'),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            'คุณสามารถซื้อทองออนไลน์ได้โดยไปที่เมนู "ซื้อ / ขาย", เลือก "ซื้อทอง", ระบุจำนวนที่ต้องการ (เป็นบาท หรือ บาทเงินสด), ตรวจสอบยอดและยืนยันรายการ กรุณาตรวจสอบให้แน่ใจว่าคุณมีเงินเพียงพอในวอลเล็ตก่อนทำรายการ'),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text('จะมารับทองที่หน้าร้านต้องทำอย่างไร?'),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            'คุณสามารถนัดหมายการรับทองได้ที่เมนู โปรไฟล์ > รายการนัดหมายของฉัน เลือกวันและเวลาที่สะดวก เมื่อมาถึงหน้าร้าน กรุณาแสดง QR Code นัดหมายหรือเลขที่รายการต่อพนักงาน'),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text('เวลาทำการของร้านคือช่วงใด?'),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            'เราเปิดให้บริการวันจันทร์ถึงวันเสาร์ เวลา 9:00 น. ถึง 17:30 น. และปิดทำการในวันอาทิตย์และวันหยุดนักขัตฤกษ์'),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text('ระบบการจำนำทองทำงานอย่างไร?'),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            'หากคุณมีทองคำในพอร์ตการลงทุน คุณสามารถนำมาจำนำผ่านแอปได้ทันที โดยจะได้รับเงินสูงสุด 85% ของราคารับซื้อในขณะนั้น เงินกู้จะโอนเข้าวอลเล็ตของคุณโดยตรง พร้อมอัตราดอกเบี้ย 1.25% ต่อเดือน'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'ข้อมูลทางกฎหมาย',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.2),
              ),
            ),
             Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                   ListTile(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กำลังเปิดหน้าเงื่อนไขการใช้บริการ...')));
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    title: const Text('เงื่อนไขการใช้บริการ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    trailing: const Icon(Icons.open_in_new, color: Colors.grey, size: 20),
                  ),
                   const Divider(height: 1, indent: 20, thickness: 1, color: Color(0xFFF0F0F0)),
                   ListTile(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กำลังเปิดหน้านโยบายความเป็นส่วนตัว...')));
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                     title: const Text('นโยบายความเป็นส่วนตัว', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     trailing: const Icon(Icons.open_in_new, color: Colors.grey, size: 20),
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
