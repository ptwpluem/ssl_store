import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/main_screen.dart';
import '../pages/owner/owner_dashboard_page.dart';

// 9 STEPS

class AuthGate extends StatelessWidget {
  // [1] สร้าง Class: เปิดตัวยามแต่ยังไม่ทำอะไร
  const AuthGate({
    super.key,
  }); // ยามที่อยู่หน้าประตู และคอยเช็คทุกครั้งว่า Login หรือยัง หาก Login แล้วเป็น Role อะไร

  @override // อันเดิมมีอยู่แล้ว แต่ไม่อยากใช้ ให้ใช้อันที่พึ่งสร้างขึ้น
  Widget build(BuildContext context) {
    // [2] เริ่มวาดหน้าจอ: คอยฟัง Firebase Auth ตลอดเวลาว่ามีคน Login/Logout ไหม
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } // [3] รอ Firebase ตอบกลับ: ถ้ายังไม่ตอบให้หมุน

        final user = authSnapshot.data;
        if (user == null) {
          return const MainScreen();
        } // [4] Firebase ตอบแล้ว: ถ้าไม่มี User ไปที่ MainScreen

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('uid', isEqualTo: user.uid)
              .snapshots(), // [5] Login แล้วไปเช็ค Role ใน Firebase: ดูจาก Collection user ว่าเป็น Role อะไร
          builder: (context, querySnapshot) {
            if (querySnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            List<DocumentSnapshot> docs = querySnapshot.data?.docs ?? [];

            if (docs.isEmpty && user.email != null) {
              // Fallback to searching by email if UID query yields nothing
              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: user.email)
                    .limit(1)
                    .get(),
                builder: (context, emailSnapshot) {
                  if (emailSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final emailDocs = emailSnapshot.data?.docs ?? [];
                  if (emailDocs.isEmpty) {
                    return const MainScreen();
                  }

                  return _buildPlatformByRole(emailDocs.first);
                },
              );
            } // [6] ถ้าหาด้วย uid ไม่เจอ ให้หาด้วย Email แทน

            if (docs.isEmpty) {
              return const MainScreen();
            } // [7] ถ้าไม่เจอทั้ง uid และ email, route ไป MainScreen

            DocumentSnapshot userDoc = docs.first;
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data?['role'] == 'owner') {
                userDoc = doc;
                break;
              }
            } // [8] เจอ Document แล้วให้หา Role: ถ้ามีหลาย documeny ให้เลือก owner ก่อน

            return _buildPlatformByRole(userDoc);
          },
        );
      },
    );
  }

  Widget _buildPlatformByRole(DocumentSnapshot userSnapshot) {
    final data = userSnapshot.data() as Map<String, dynamic>?;
    final role = data?['role'] ?? 'user';

    if (role == 'owner') {
      return const OwnerDashboardPage(); // ถ้าเป็น owner, route ไปหน้า owner pages
    }

    return const MainScreen();
  } // [9] ตัดสินใจขึ้นสุดท้าย: ถ้า owner -> OwnerDB, ถ้าไม่ใช่ไป MainScreen
}

// Initial Route คือ AuthGate และจะมีการเช็ค Login, และ Login Role
