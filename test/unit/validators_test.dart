import 'package:flutter_test/flutter_test.dart';
import 'package:ssl_store/utils/validators.dart';

/// Validators guard every write into Firestore (amounts, phone numbers,
/// passwords), so they're worth pinning precisely — including the boundaries.
void main() {
  group('requiredField', () {
    test('rejects null / empty / whitespace, accepts content', () {
      expect(Validators.requiredField(null), isNotNull);
      expect(Validators.requiredField('   '), isNotNull);
      expect(Validators.requiredField('Piti'), isNull);
    });
  });

  group('email', () {
    test('accepts a well-formed address', () {
      expect(Validators.email('a.b+x@example.co.th'), isNull);
    });
    test('rejects malformed addresses', () {
      for (final bad in ['', 'nope', 'a@b', 'a@@b.com', 'a b@c.com']) {
        expect(Validators.email(bad), isNotNull, reason: bad);
      }
    });
  });

  group('thaiPhone', () {
    test('accepts 10 digits starting with 0, ignoring spaces/dashes', () {
      expect(Validators.thaiPhone('0812345678'), isNull);
      expect(Validators.thaiPhone('081-234-5678'), isNull);
      expect(Validators.thaiPhone('081 234 5678'), isNull);
    });
    test('rejects wrong length / prefix / non-digits', () {
      for (final bad in ['', '12345', '1812345678', '08123456789', '08a2345678']) {
        expect(Validators.thaiPhone(bad), isNotNull, reason: bad);
      }
    });
  });

  group('password', () {
    test('requires 8+ chars with a letter and a digit', () {
      expect(Validators.password('abc12345'), isNull);
      expect(Validators.password('short1'), isNotNull); // too short
      expect(Validators.password('allletters'), isNotNull); // no digit
      expect(Validators.password('12345678'), isNotNull); // no letter
      expect(Validators.password(''), isNotNull);
    });

    test('confirmPassword matches only when equal', () {
      expect(Validators.confirmPassword('abc12345', 'abc12345'), isNull);
      expect(Validators.confirmPassword('abc12345', 'different'), isNotNull);
    });
  });

  group('positiveAmount', () {
    test('accepts positive numbers incl. thousands separators', () {
      expect(Validators.positiveAmount('1500'), isNull);
      expect(Validators.positiveAmount('41,000.50'), isNull);
    });
    test('rejects empty, non-numeric, zero, negative', () {
      expect(Validators.positiveAmount(''), isNotNull);
      expect(Validators.positiveAmount('abc'), isNotNull);
      expect(Validators.positiveAmount('0'), isNotNull);
      expect(Validators.positiveAmount('-5'), isNotNull);
    });
  });

  group('amountWithin', () {
    test('accepts amounts up to and including the ceiling', () {
      expect(Validators.amountWithin('34000', 34000), isNull); // boundary
      expect(Validators.amountWithin('1000', 34000), isNull);
    });
    test('rejects amounts over the ceiling and invalid input', () {
      expect(Validators.amountWithin('34000.01', 34000), isNotNull);
      expect(Validators.amountWithin('0', 34000), isNotNull);
      expect(Validators.amountWithin('abc', 34000), isNotNull);
    });
  });

  group('quarterBahtWeight', () {
    test('accepts positive multiples of 0.25', () {
      expect(Validators.quarterBahtWeight(0.25), isNull);
      expect(Validators.quarterBahtWeight(2.0), isNull);
    });
    test('rejects zero, negative, and non-multiples', () {
      expect(Validators.quarterBahtWeight(0), isNotNull);
      expect(Validators.quarterBahtWeight(-1), isNotNull);
      expect(Validators.quarterBahtWeight(0.3), isNotNull);
    });
  });
}
