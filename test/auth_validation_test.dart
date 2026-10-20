import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/auth_validation.dart';

void main() {
  group('authEmailError', () {
    test('rejects an empty or blank address', () {
      expect(authEmailError(''), 'Enter your email address.');
      expect(authEmailError('   '), 'Enter your email address.');
    });

    test('rejects addresses with no usable local or domain part', () {
      expect(authEmailError('nobody'), 'Enter a valid email address.');
      expect(authEmailError('@cnps.cm'), 'Enter a valid email address.');
      expect(authEmailError('nobody@'), 'Enter a valid email address.');
      expect(authEmailError('nobody@cnps'), 'Enter a valid email address.');
      expect(authEmailError('nobody@cnps.'), 'Enter a valid email address.');
      expect(authEmailError('no body@cnps.cm'), 'Enter a valid email address.');
    });

    test('accepts a plausible work address regardless of internal spacing', () {
      expect(authEmailError('mony.aye@cnps.cm'), isNull);
      expect(authEmailError('  mony.aye@cnps.cm  '), isNull);
      expect(authEmailError('a@b.co'), isNull);
    });
  });

  group('authPasswordError', () {
    test('always requires something to submit', () {
      expect(authPasswordError('', creating: false), 'Enter your password.');
      expect(authPasswordError('', creating: true), 'Enter your password.');
    });

    test('does not lock out an existing shorter password', () {
      expect(authPasswordError('short', creating: false), isNull);
    });

    test('enforces the offered minimum while creating an account', () {
      expect(
        authPasswordError('short', creating: true),
        'Use at least 8 characters.',
      );
      expect(
        authPasswordError('1234567', creating: true),
        'Use at least 8 characters.',
      );
      expect(authPasswordError('12345678', creating: true), isNull);
    });
  });

  group('authPasswordConfirmationError', () {
    test('requires the confirmation field', () {
      expect(
        authPasswordConfirmationError('12345678', ''),
        'Confirm your new password.',
      );
    });

    test('reports a mismatch', () {
      expect(
        authPasswordConfirmationError('12345678', '87654321'),
        'Passwords do not match.',
      );
    });

    test('accepts identical values', () {
      expect(authPasswordConfirmationError('12345678', '12345678'), isNull);
    });
  });
}
