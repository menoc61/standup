/// Validation for the onboarding profile step.
///
/// The rules live outside the widget so they can be tested without a running
/// `AppState`, and so the same rule guards both "Continue" and "Finish" — the
/// profile step used to fall back to `Employee` when the name was blank, which
/// produced an account with no identity that the administrator could not match
/// to a person.
library;

/// The longest a person's name may be before it is almost certainly a paste.
const int kProfileNameMaxLength = 80;

/// The longest a designation may be before the department view loses the row.
const int kProfileDesignationMaxLength = 80;

/// Returns an English dictionary key, or null when the name is usable.
String? profileNameError(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Enter your full name.';
  if (trimmed.length < 2) return 'Your name is too short.';
  if (trimmed.length > kProfileNameMaxLength) return 'Your name is too long.';
  return null;
}

/// Returns an English dictionary key, or null when the designation is usable.
String? profileDesignationError(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Enter your role or designation.';
  if (trimmed.length < 2) return 'Your role is too short.';
  if (trimmed.length > kProfileDesignationMaxLength) {
    return 'Your role is too long.';
  }
  return null;
}

/// The work email is optional, but a value that is present must be usable.
///
/// This is deliberately a shape check, not a deliverability check: the app has
/// no business deciding which addresses exist, and the workspace's domain rule
/// is enforced by the server at join time, not here.
String? profileEmailError(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (RegExp(r'\s').hasMatch(trimmed)) {
    return 'Enter a valid work email address.';
  }
  final at = trimmed.indexOf('@');
  final dot = trimmed.lastIndexOf('.');
  if (at <= 0 || dot <= at + 1 || dot >= trimmed.length - 1) {
    return 'Enter a valid work email address.';
  }
  return null;
}

/// True when the profile step may be left.
bool profileDraftIsComplete({
  required String name,
  required String designation,
  required String email,
}) {
  return profileNameError(name) == null &&
      profileDesignationError(designation) == null &&
      profileEmailError(email) == null;
}
