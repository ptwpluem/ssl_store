import 'dart:developer' as developer;

/// Centralised logging + crash-reporting seam.
///
/// Today it writes to the Dart developer log (visible in the IDE / `flutter
/// run` console). It also exposes [onError] — a hook a crash reporter is
/// attached to in `main()`. Wiring it once routes every `AppLogger.error(...)`
/// across the app to the reporter, instead of scattering reporter calls (or
/// silent `catch (_) {}` blocks) through the services.
///
/// To enable Firebase Crashlytics (after the native setup — see ROADMAP
/// Milestone C):
///
/// ```dart
/// AppLogger.onError = (error, stack, {reason}) =>
///     FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
/// ```
class AppLogger {
  AppLogger._();

  static const String _name = 'ssl_store';

  /// Attach a crash reporter here once Crashlytics is configured natively.
  /// Receives the error, its stack trace, and the log message as [reason].
  static void Function(Object error, StackTrace? stack, {String? reason})?
      onError;

  /// Low-severity diagnostic — non-critical, expected-to-sometimes-fail paths
  /// (e.g. an optional display-name lookup, a best-effort self-heal).
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message,
        name: _name, level: 500, error: error, stackTrace: stackTrace);
  }

  /// Something failed but the app recovered or continued in a degraded way.
  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message,
        name: _name, level: 900, error: error, stackTrace: stackTrace);
  }

  /// A real failure. Logged AND forwarded to the crash reporter ([onError])
  /// when one is attached and an [error] object is provided.
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message,
        name: _name, level: 1000, error: error, stackTrace: stackTrace);
    final reporter = onError;
    if (reporter != null && error != null) {
      reporter(error, stackTrace, reason: message);
    }
  }
}
