import 'package:flutter/material.dart';
import 'member/member_home_page.dart';
import 'member/member_portfolio_page.dart';
import 'member/member_trading_page.dart';
import 'member/member_profile_page.dart';

// Total 13 Steps

// [1] Import tooles เพื่อจะเอาไปใช้

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
  }); // [2] ประกาศ Class MainScreen เป็น StatefulWidget (มีหน่วยความจำ)

  @override
  State<MainScreen> createState() => _MainScreenState(); // [3] สร้าง State และบอก Flutter ว่าให้ไปดูข้อมูลและ Build ที่ _MainScreenState
}

class _MainScreenState extends State<MainScreen> {
  // [4] ตัวจริงที่เก็ฐข้อมูลและวาดหน้าจอ
  int _selectedIndex =
      0; // [5] ตัวแปรจำว่ากด Tab ไหนอยู่โดยเริ่มต้นที่ 0 (หน้าแรก)

  final List<Widget> _pages = [
    const HomePage(), // หน้าแรก
    const TradingPage(), // ซื้อ-ขาย
    const PortfolioPage(), // ทองของฉัน
    const ProfilePage(), // โปรไฟล์
  ]; // [6] รานชื่อหน้าทั้ง 4 - index 0,1,2,3 ที่ตรงกับปุ่มเมนูด้านล่าง

  void _onItemTapped(int index) {
    setState(() {
      // [7] Function ทำงานเมื่อ Users กดปุ่มด้านล่าง
      _selectedIndex = index;
    }); // [8] เปลี่ยนหน้าจอเมื่อมีการกดปุ่ม
  }

  @override
  Widget build(BuildContext context) {
    // [9] Flutter เรียก build() ทุกครั้งที่ setState() ถูกเรียก เช่น เปิด App -> build (HomePage), กด Tab ซื้อ-ขาย, onItemTapped(1) -> setState() _selectedIndex = 1, Flutter => build(), IndexedStack เห็น TradingPage
    return Scaffold(
      body: IndexedStack(
        // [10] เก็บหน้าจอหลายหน้าซ้อนกัน แต่แสดงแค่หน้าเดียวตามที่เราเลือก
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          // [11] แถบเมนูด้านล่างเชื่อมกับ _selectedIndex
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF800000),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          onTap: _onItemTapped,
          items: const [
            // [13] 4 ปุ่มเมนูตรงกับ index 0-3
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าแรก'),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart),
              label: 'ซื้อ-ขาย',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart), // or savings icon
              label: 'ทองของฉัน',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'โปรไฟล์'),
          ],
        ),
      ),
    );
  }
}
