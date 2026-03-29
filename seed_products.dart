import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;
  final productsRef = firestore.collection('products');

  final dummyProducts = [
    {
      'id': 'p1',
      'name': 'สร้อยคอทองคำ ลายสี่เสา',
      'description': 'สร้อยคอทองคำแท้ 96.5% ลายสี่เสา ดีไซน์คลาสสิก แข็งแรงทนทาน เหมาะสำหรับใส่ทำกิจกรรมประจำวัน',
      'price': 42000.0,
      'weight': 1.0,
      'laborFee': 1200.0,
      'stock': 15,
      'imageUrl': 'https://somsrimanee.com/wp-content/uploads/2023/07/20240906-0370.jpg',
      'category': 'Necklace'
    },
    {
      'id': 'p2',
      'name': 'แหวนทองคำ ลายมังกรคาบแก้ว',
      'description': 'แหวนทองคำแท้ 96.5% แกะสลักลายมังกรอย่างประณีต เสริมบารมีและความเป็นสิริมงคล',
      'price': 21500.0,
      'weight': 0.5,
      'laborFee': 800.0,
      'stock': 8,
      'imageUrl': 'https://somsrimanee.com/wp-content/uploads/2023/07/20240906-0158.jpg',
      'category': 'Ring'
    },
    {
      'id': 'p3',
      'name': 'กำไลทองคำกลมเกลี้ยง',
      'description': 'กำไลทองคำแท้ 96.5% แบบกลมเกลี้ยง ขัดเงาสวยงาม เรียบง่ายแต่หรูหรา',
      'price': 84500.0,
      'weight': 2.0,
      'laborFee': 1500.0,
      'stock': 5,
      'imageUrl': 'https://somsrimanee.com/wp-content/uploads/2023/07/20240906-0279-Edit.jpg',
      'category': 'Bracelet'
    },
    {
      'id': 'p4',
      'name': 'ต่างหูทองคำ ลายดอกพิกุล',
      'description': 'ต่างหูทองคำแท้ 96.5% ลายดอกพิกุล งานศิลปะไทยโบราณที่ละเอียดอ่อนและงดงาม',
      'price': 10800.0,
      'weight': 0.25,
      'laborFee': 600.0,
      'stock': 20,
      'imageUrl': 'https://somsrimanee.com/wp-content/uploads/2023/07/20240906-0209-Edit.jpg',
      'category': 'Earrings'
    },
    {
      'id': 'p5',
      'name': 'แหวนทองคำประดับทับทิมแท้',
      'description': 'แหวนทองคำแท้ 96.5% ดีไซน์ร่วมสมัย ประดับด้วยทับทิมเม็ดสวย คุณภาพสูง',
      'price': 25000.0,
      'weight': 0.5,
      'laborFee': 2500.0,
      'stock': 3,
      'imageUrl': 'https://somsrimanee.com/wp-content/uploads/2023/07/20240906-0164.jpg',
      'category': 'Ring'
    },
  ];

  print("Starting seed...");
  for (final p in dummyProducts) {
    await productsRef.doc(p['id'].toString()).set(p);
    print("Added ${p['name']}!");
  }
  print("Done!");
}
