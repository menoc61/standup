import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/auth_errors.dart';

void main() {
  group('friendlyAuthError', () {
    test('maps a wrong password without echoing the provider wording', () {
      expect(
        friendlyAuthError(Exception('Invalid login credentials')),
        'Email or password is incorrect.',
      );
    });

    test('maps a duplicate sign-up to the sign-in suggestion', () {
      expect(
        friendlyAuthError(Exception('User already registered')),
        'An account already exists. Choose Sign in.',
      );
    });

    test('maps an unconfirmed account', () {
      expect(
        friendlyAuthError(Exception('Email not confirmed')),
        'Confirm your email address before signing in.',
      );
    });

    test('maps every rate-limit shape to one calm sentence', () {
      for (final message in const [
        'over_email_send_rate_limit',
        'Email rate limit exceeded',
        'Too many requests',
        'For security purposes, you can only request this after 47 seconds',
      ]) {
        expect(
          friendlyAuthError(Exception(message)),
          'Too many attempts. Wait a few minutes and try again.',
          reason: message,
        );
      }
    });

    test('maps a server password rule to the length the app asks for', () {
      expect(
        friendlyAuthError(
          Exception('Password should be at least 6 characters'),
        ),
        'Use at least 8 characters.',
      );
    });

    test('maps the unconfigured build to a configuration sentence', () {
      expect(
        friendlyAuthError(StateError('Cloud accounts are not configured.')),
        'Cloud accounts are not configured for this app yet.',
      );
    });

    test('maps network failures', () {
      for (final message in const [
        'SocketException: Failed host lookup',
        'ClientException with SocketException',
        'Connection timed out',
      ]) {
        expect(
          friendlyAuthError(Exception(message)),
          'Could not reach the server. Check your connection and try again.',
          reason: message,
        );
      }
    });

    test('keeps the account-boundary explanation verbatim', () {
      const message =
          'This device already has data for another account. Switching '
          'between local profiles is not supported yet.';
      // The repository throws a StateError, whose toString() adds "Bad state: ".
      expect(friendlyAuthError(StateError(message)), message);
    });

    test('falls back to the generic sentence rather than an empty banner', () {
      expect(friendlyAuthError(Exception('')), kGenericAuthError);
      expect(friendlyAuthError(Exception('   ')), kGenericAuthError);
    });

    test('passes an unrecognised sentence through unchanged', () {
      expect(
        friendlyAuthError(Exception('Some provider detail')),
        'Some provider detail',
      );
    });
  });
}
