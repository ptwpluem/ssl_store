import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/utils/app_logger.dart';

/// AppLogger is the single seam a crash reporter (Crashlytics) attaches to.
/// These pin the contract that `error()` forwards to that hook while the
/// lower-severity levels do not — so wiring Crashlytics in `main()` reports
/// real errors without spamming it with debug noise.
void main() {
  tearDown(() => AppLogger.onError = null);

  test('error() forwards the error, stack, and message to the onError hook', () {
    Object? gotError;
    StackTrace? gotStack;
    String? gotReason;
    AppLogger.onError = (e, s, {reason}) {
      gotError = e;
      gotStack = s;
      gotReason = reason;
    };

    final ex = Exception('boom');
    final st = StackTrace.current;
    AppLogger.error('payment failed', error: ex, stackTrace: st);

    expect(gotError, ex);
    expect(gotStack, st);
    expect(gotReason, 'payment failed');
  });

  test('error() without an error object does not invoke the hook', () {
    var called = false;
    AppLogger.onError = (e, s, {reason}) => called = true;
    AppLogger.error('message only');
    expect(called, isFalse);
  });

  test('debug() and warning() never reach the crash reporter', () {
    var called = false;
    AppLogger.onError = (e, s, {reason}) => called = true;
    AppLogger.debug('diag', error: Exception('x'));
    AppLogger.warning('recoverable', error: Exception('y'));
    expect(called, isFalse);
  });
}
