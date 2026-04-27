import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// -- Pages / Widgets --
import 'widgets/auth_gate.dart';
import 'pages/main_screen.dart';
import 'pages/member/member_home_page.dart';
import 'pages/member/member_login_page.dart';
import 'pages/member/member_appointment_page.dart';
import 'pages/member/member_blank_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // User will now stay logged in between sessions
  // await FirebaseAuth.instance.signOut();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ห้างทองสุ้นเซ่งหลี',
      debugShowCheckedModeBanner: false,
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
        '/': (_) => const AuthGate(),
        '/login': (_) => const LoginPage(),
        //        '/buy-sell': (_) => const BuySellPage(),
        '/appointment': (_) => const AppointmentPage(),
        //       '/history': (_) => const HistoryPage(),
        '/blank': (_) => const BlankPage(),
      },
    );
  }
}
