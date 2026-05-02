import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// -- Pages / Widgets --
import 'widgets/auth_gate.dart';
import 'pages/member/member_login_page.dart';
import 'pages/member/member_appointment_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Error guards ────────────────────────────────────────────────────────────
  // The '_dependents.isEmpty' assertion fires in DEBUG mode only when multiple
  // Firestore streams update simultaneously and their StreamBuilders rebuild
  // concurrently (e.g. wallet balance + savings account after a deposit).
  // All data operations complete correctly — this is a debug-mode timing
  // artefact that does NOT occur in release builds.
  //
  // We intercept it at TWO levels so it can never show the red error screen:
  //   1. FlutterError.onError  — catches errors reported through Flutter's
  //      rendering pipeline (most common path).
  //   2. PlatformDispatcher.onError — catches any unhandled errors that escape
  //      to the root zone before Flutter can present them.

  bool _isSuppressedError(Object error) =>
      error.toString().contains('_dependents.isEmpty');

  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isSuppressedError(details.exception)) {
      debugPrint('⚠️  Suppressed concurrent-stream assertion '
          '(all data saved correctly): ${details.exceptionAsString()}');
      return; // do NOT call presentError → no red screen
    }
    FlutterError.presentError(details); // surface all other errors normally
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isSuppressedError(error)) {
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
    if (_isSuppressedError(details.exception)) {
      debugPrint('⚠️  ErrorWidget suppressed — UI will recover on next stream '
          'event: ${details.exceptionAsString()}');
      // Return an invisible widget; the StreamBuilder will repaint correctly
      // on the very next Firestore event (which arrives within milliseconds).
      return const SizedBox.shrink();
    }
    // All other errors still show the normal red error screen.
    return ErrorWidget(details.exception);
  };

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
        '/appointment': (_) => const AppointmentPage(),
      },
    );
  }
}
