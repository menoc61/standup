import 'package:flutter/material.dart';
import 'package:standup_app/core/app_spacing.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/core/auth_errors.dart';
import 'package:standup_app/core/auth_validation.dart';
import 'package:standup_app/ui/screens/auth/auth_shell.dart';

/// Shown when the person arrives from a "reset your password" email.
///
/// The recovery link already opened a session, so this screen only collects the
/// new password. It is deliberately not part of [AuthScreen]: leaving through
/// "Cancel" has to end that session, and a form nested in the sign-in page
/// would make the two transitions indistinguishable.
class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({
    super.key,
    required this.onSubmit,
    required this.onCancel,
  });

  /// Saves the new password. Throws a server error to keep the person on the
  /// form with an explanation.
  final Future<void> Function(String password) onSubmit;

  /// Ends the recovery session and returns to the account screen.
  final Future<void> Function() onCancel;

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  bool _showErrors = false;
  bool _working = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String? get _passwordError =>
      _showErrors ? authPasswordError(_password.text, creating: true) : null;

  String? get _confirmationError => _showErrors
      ? authPasswordConfirmationError(_password.text, _confirmation.text)
      : null;

  Future<void> _submit() async {
    if (_working) return;
    FocusScope.of(context).unfocus();

    final passwordError = authPasswordError(_password.text, creating: true);
    final confirmationError = authPasswordConfirmationError(
      _password.text,
      _confirmation.text,
    );
    if (passwordError != null || confirmationError != null) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_password.text);
      // The root clears the recovery flag and swaps screens; this only stops
      // the spinner if that has not happened yet.
      if (mounted) setState(() => _working = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = appString(context, friendlyAuthError(error));
        _working = false;
      });
    }
  }

  Future<void> _cancel() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await widget.onCancel();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthShell(
      titleKey: 'Set a new password',
      subtitleKey: 'Choose a password with at least 8 characters.',
      children: [
        if (_error != null) ...[
          AuthBanner(
            icon: Icons.error_outline,
            text: _error!,
            background: theme.colorScheme.errorContainer,
            foreground: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(height: AppSpace.xl),
        ],
        TextField(
          controller: _password,
          enabled: !_working,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: appString(context, 'New password'),
            errorText: _passwordError == null
                ? null
                : appString(context, _passwordError!),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              tooltip: appString(
                context,
                _obscurePassword ? 'Show password' : 'Hide password',
              ),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _confirmation,
          enabled: !_working,
          obscureText: _obscureConfirmation,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: appString(context, 'Confirm password'),
            errorText: _confirmationError == null
                ? null
                : appString(context, _confirmationError!),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirmation = !_obscureConfirmation),
              tooltip: appString(
                context,
                _obscureConfirmation ? 'Show password' : 'Hide password',
              ),
              icon: Icon(
                _obscureConfirmation
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
        SizedBox(
          height: AppSpace.control,
          child: FilledButton(
            onPressed: _working ? null : _submit,
            child: _working
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : Text(
                    appString(context, 'Update password'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        TextButton(
          onPressed: _working ? null : _cancel,
          child: Text(appString(context, 'Cancel')),
        ),
      ],
    );
  }
}
