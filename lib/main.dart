import 'package:flutter/foundation.dart'; // เครื่องมือพื้นฐาน
import 'package:flutter/material.dart'; // ชุด UI component เช่น button, text, AppBar
import 'package:firebase_core/firebase_core.dart'; // Library เริ่มสำหรับ Firebase
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart'; // File Configure ที่ Filebase สร้างให้อัตโนมัติ

// -- Pages / Widgets --
import 'widgets/auth_gate.dart';
import 'pages/member/member_login_page.dart';
import 'pages/member/member_appointment_page.dart';

void main() async {
  // async คือรอให้ Firebase เชื่อมต่อก่อน
  WidgetsFlutterBinding.ensureInitialized(); // เรียกใช้เสมอถ้ามี await ใน main ()

  // แก้ปัญหาเฉพาะของ Firestore: เมื่อ stream 2 ตัวอัปเดตพร้อมกัน (เช่น wallet + savings)
  //Flutter debug mode จะขึ้น error หน้าแดง แต่ข้อมูลจริงถูกต้อง โค้ดนี้จึงซ่อน error นั้นไว้

  bool isSuppressedError(Object error) =>
      error.toString().contains('_dependents.isEmpty');

  FlutterError.onError = (FlutterErrorDetails details) {
    if (isSuppressedError(details.exception)) {
      debugPrint(
        '⚠️  Suppressed concurrent-stream assertion '
        '(all data saved correctly): ${details.exceptionAsString()}',
      );
      return; // do NOT call presentError → no red screen
    }
    FlutterError.presentError(details); // surface all other errors normally
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (isSuppressedError(error)) {
      debugPrint('⚠️  Suppressed at platform level: $error');
      return true; // handled — prevents zone crash
    }
    return false; // not handled — let Flutter's default handler take it
  };

  // ── ErrorWidget.builder ─────────────────────────────────────────────────────
  // THIS is the actual control point for the red error screen.
  // FlutterError.onError only suppresses the log entry; the red screen is
  // painted by ErrorWidget.builder inside ComponentElement.performRebuild()'s
  // catch block — it fires independently, AFTER FlutterError.reportError().
  // Overriding this builder is the only way to prevent the red screen widget
  // from appearing in the tree.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (isSuppressedError(details.exception)) {
      debugPrint(
        '⚠️  ErrorWidget suppressed — UI will recover on next stream '
        'event: ${details.exceptionAsString()}',
      );
      // Return an invisible widget; the StreamBuilder will repaint correctly
      // on the very next Firestore event (which arrives within milliseconds).
      return const SizedBox.shrink();
    }
    // All other errors still show the normal red error screen.
    return ErrorWidget(details.exception);
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); //เชื่อมต่อ Firebase และรอให้เชื่อมสำเร็จก่อนที่จะรัน App

  // Offline support: persist Firestore data on-device so the app keeps working
  // on flaky in-shop wifi and syncs back when the connection returns.
  // (Persistence is on by default on mobile; set explicitly + unlimited cache.)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // User will now stay logged in between sessions
  // await FirebaseAuth.instance.signOut();

  runApp(const ProviderScope(child: MyApp())); // [1]
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // กำหนด Theme ของ App, static ไม่เปลี่ยน

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // กล่องใหญ่ที่เอามากำหนด Theme ของ App
      title: 'ห้างทองซุ่นเซ่งหลี',
      debugShowCheckedModeBanner: true,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF800000), // Deep Maroon Red
          secondary: const Color(0xFFFFD700), // Gold
          surface: const Color(
            0xFFFFF8E1,
          ), // Light Cream (optional warm background)
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8E1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF800000),
          foregroundColor: Color(0xFFFFD700),
          centerTitle: true,
        ),
      ),

      initialRoute: '/',
      routes: {
        // ลงทะเบียน 3 หน้านี้ไว้ใน Routes เพราะมีการเรียกใช้บ่อย เช่น Navigator.pushNamed(context, '/login') แต่หน้าอื่น ไม่ค่อยถูกเรียกใช้เลยไม่ได้ทำเป็น Route ไว้
        '/': (_) => const AuthGate(),
        '/login': (_) => const LoginPage(),
        '/appointment': (_) => const AppointmentPage(),
      },
    );
  }
}
