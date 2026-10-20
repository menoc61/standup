/// Validation for the account screens that run before onboarding.
///
/// The rules live outside the widgets for the same reason the profile rules do:
/// the sign-in page, the create-account page and the password-recovery page all
/// need the same answer, and a widget test should be able to prove it without a
/// configured Supabase project.
///
/// These are shape checks only. Whether an account exists, whether the workspace
/// accepts its domain, and whether a password is correct are server decisions.
/// Deciding any of those here would either leak account existence or drift from
/// the rules the Edge/GoTrue side actually enforces.
library;

/// The minimum length the app offers. Supabase's own minimum can be lower, but
/// the account is the key to a person's break history and organisation data, so
/// the client asks for more rather than less.
const int kAuthPasswordMinLength = 8;

/// Returns an English dictionary key, or null when [value] can be submitted as
/// an email address.
String? authEmailError(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Enter your email address.';
  if (RegExp(r'\s').hasMatch(trimmed)) return 'Enter a valid email address.';
  final at = trimmed.indexOf('@');
  final dot = trimmed.lastIndexOf('.');
  if (at <= 0 || dot <= at + 1 || dot >= trimmed.length - 1) {
    return 'Enter a valid email address.';
  }
  return null;
}

/// Returns an English dictionary key, or null when [value] can be submitted.
///
/// Sign-in does not enforce the length: an account created before the current
/// rule may have a shorter password, and refusing to submit it would lock that
/// person out of their own history. Create-account does enforce it.
String? authPasswordError(String value, {required bool creating}) {
  if (value.isEmpty) return 'Enter your password.';
  if (creating && value.length < kAuthPasswordMinLength) {
    return 'Use at least 8 characters.';
  }
  return null;
}

/// Returns an English dictionary key, or null when both recovery fields agree.
String? authPasswordConfirmationError(String password, String confirmation) {
  if (confirmation.isEmpty) return 'Confirm your new password.';
  if (password != confirmation) return 'Passwords do not match.';
  return null;
}
