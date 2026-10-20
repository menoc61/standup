/// Turns an auth exception into a sentence a person can act on.
///
/// Supabase returns provider-shaped messages ("Invalid login credentials",
/// "over_email_send_rate_limit", "Password should be at least 6 characters").
/// Showing them raw is how a sign-in page ends up telling a French-speaking
/// employee that their "refresh token was revoked".
///
/// The rules are deliberately substring matches rather than exception types:
/// the same failure arrives as `AuthException`, `PostgrestException` or a plain
/// network error depending on where it happened, and the message is the only
/// part that is stable across those paths. Anything unrecognised falls through
/// unchanged instead of being flattened to "unknown error" — a specific server
/// sentence is still more useful than nothing.
library;

/// The one sentence used when no rule matches and the error carries no text.
const String kGenericAuthError = 'Something went wrong. Please try again.';

String friendlyAuthError(Object error) {
  // `StateError` prefixes its message with "Bad state: ", and the local
  // repository uses one for the shared-device account boundary. Stripping the
  // wrapper keeps that explanation readable instead of showing Dart class names.
  var message = error.toString();
  for (final prefix in const ['Exception: ', 'Bad state: ']) {
    if (message.startsWith(prefix)) {
      message = message.substring(prefix.length);
      break;
    }
  }
  message = message.trim();
  final lower = message.toLowerCase();

  if (lower.contains('invalid login credentials')) {
    return 'Email or password is incorrect.';
  }
  if (lower.contains('already registered') ||
      lower.contains('already exists') ||
      lower.contains('user already exists')) {
    return 'An account already exists. Choose Sign in.';
  }
  if (lower.contains('email not confirmed')) {
    return 'Confirm your email address before signing in.';
  }
  if (lower.contains('rate limit') ||
      lower.contains('over_email_send') ||
      lower.contains('too many') ||
      lower.contains('for security purposes')) {
    return 'Too many attempts. Wait a few minutes and try again.';
  }
  if (lower.contains('password should be at least') ||
      lower.contains('weak password') ||
      lower.contains('password is too short')) {
    return 'Use at least 8 characters.';
  }
  if (lower.contains('invalid email') || lower.contains('email address')) {
    return 'Enter a valid email address.';
  }
  if (lower.contains('not configured')) {
    return 'Cloud accounts are not configured for this app yet.';
  }
  // Preserved because the local repository writes it as a complete explanation
  // for the person switching accounts on a shared device.
  if (lower.contains('another account') ||
      lower.contains('different saved account')) {
    return message;
  }
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('clientexception') ||
      lower.contains('network') ||
      lower.contains('timed out') ||
      lower.contains('timeout')) {
    return 'Could not reach the server. Check your connection and try again.';
  }
  return message.isEmpty ? kGenericAuthError : message;
}
