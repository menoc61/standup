import 'package:flutter/material.dart';
import 'package:standup_app/core/app_spacing.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/core/auth_errors.dart';
import 'package:standup_app/core/auth_validation.dart';
import 'package:standup_app/ui/screens/auth/auth_shell.dart';

/// The account gate shown after the splash and before onboarding.
///
/// ## Why it exists
///
/// Onboarding used to be the first screen, and the account was an optional card
/// buried in Settings. A person therefore chose a name, a cadence and a
/// workspace before the app had any idea who they were, and joining a workspace
/// silently depended on having signed in first. This screen puts the identity
/// decision first: sign in, create the account, recover a password, or
/// deliberately continue on this device alone.
///
/// ## What it deliberately does not do
///
/// It does not decide whether an address is allowed in the workspace, whether
/// an account exists, or whether a password is correct. Those are server rules;
/// guessing them here would either leak account existence or drift from the
/// policies in `supabase_schema.sql`. The shape checks in
/// `auth_validation.dart` only keep obvious typos from costing a round trip.
///
/// It also does not remove the offline path. The app is offline-first, so
/// "Use this device only" is always available when the project is configured.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onSendReset,
    required this.onContinueOffline,
  });

  /// Signs in an existing account. Throwing surfaces the friendly message.
  final Future<void> Function(String email, String password) onSignIn;

  /// Creates an account. Returns true when the server returned a session,
  /// which is false while email confirmation is enabled.
  final Future<bool> Function(String email, String password) onCreateAccount;

  /// Sends the password-recovery email.
  final Future<void> Function(String email) onSendReset;

  /// Records the deliberate local-only choice and lets the root continue.
  final Future<void> Function() onContinueOffline;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { signIn, createAccount, reset }

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _showErrors = false;
  bool _working = false;
  bool _obscure = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _primaryLabel {
    switch (_mode) {
      case _AuthMode.signIn:
        return 'Sign in';
      case _AuthMode.createAccount:
        return 'Create account';
      case _AuthMode.reset:
        return 'Send reset link';
    }
  }

  String? get _emailError => _showErrors ? authEmailError(_email.text) : null;

  String? get _passwordError => !_showErrors || _mode == _AuthMode.reset
      ? null
      : authPasswordError(
          _password.text,
          creating: _mode == _AuthMode.createAccount,
        );

  void _switchMode(_AuthMode mode) {
    if (_working) return;
    setState(() {
      _mode = mode;
      _showErrors = false;
      _error = null;
      _notice = null;
      _password.clear();
      _obscure = true;
    });
  }

  Future<void> _submit() async {
    if (_working) return;
    FocusScope.of(context).unfocus();

    final emailError = authEmailError(_email.text);
    final passwordError = _mode == _AuthMode.reset
        ? null
        : authPasswordError(
            _password.text,
            creating: _mode == _AuthMode.createAccount,
          );
    if (emailError != null || passwordError != null) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() {
      _working = true;
      _error = null;
      _notice = null;
    });

    try {
      if (_mode == _AuthMode.reset) {
        await widget.onSendReset(_email.text.trim());
        if (!mounted) return;
        setState(() {
          _notice = 'Check your email for a reset link.';
          _working = false;
        });
        return;
      }

      if (_mode == _AuthMode.createAccount) {
        final hasSession = await widget.onCreateAccount(
          _email.text.trim(),
          _password.text,
        );
        if (!mounted) return;
        if (hasSession) {
          // The root swaps to onboarding as the session propagates; leaving the
          // spinner up avoids a flash of the empty form in that frame.
          return;
        }
        setState(() {
          _mode = _AuthMode.signIn;
          _showErrors = false;
          _password.clear();
          _notice =
              'Check your email to confirm your account, then sign in here.';
          _working = false;
        });
        return;
      }

      await widget.onSignIn(_email.text.trim(), _password.text);
      if (mounted) setState(() => _working = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = appString(context, friendlyAuthError(error));
        _working = false;
      });
    }
  }

  Future<void> _continueOffline() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await widget.onContinueOffline();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthShell(
      titleKey: _titleKey,
      subtitleKey: _subtitleKey,
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
        if (_notice != null) ...[
          AuthBanner(
            icon: Icons.mark_email_read_outlined,
            text: appString(context, _notice!),
            background: theme.colorScheme.secondaryContainer,
            foreground: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(height: AppSpace.xl),
        ],
        TextField(
          controller: _email,
          enabled: !_working,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: appString(context, 'Email address'),
            errorText: _emailError == null
                ? null
                : appString(context, _emailError!),
            prefixIcon: const Icon(Icons.alternate_email),
          ),
        ),
        if (_mode != _AuthMode.reset) ...[
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _password,
            enabled: !_working,
            obscureText: _obscure,
            autofillHints: [
              _mode == _AuthMode.createAccount
                  ? AutofillHints.newPassword
                  : AutofillHints.password,
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: appString(context, 'Password'),
              helperText: _mode == _AuthMode.createAccount
                  ? appString(context, 'Use at least 8 characters.')
                  : null,
              errorText: _passwordError == null
                  ? null
                  : appString(context, _passwordError!),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: appString(
                  context,
                  _obscure ? 'Show password' : 'Hide password',
                ),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        ],
        if (_mode == _AuthMode.signIn) ...[
          const SizedBox(height: AppSpace.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _working ? null : () => _switchMode(_AuthMode.reset),
              child: Text(appString(context, 'Forgot password?')),
            ),
          ),
        ] else
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
                    appString(context, _primaryLabel),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        if (_mode != _AuthMode.reset) ...[
          const SizedBox(height: AppSpace.md),
          TextButton(
            onPressed: _working
                ? null
                : () => _switchMode(
                    _mode == _AuthMode.signIn
                        ? _AuthMode.createAccount
                        : _AuthMode.signIn,
                  ),
            child: Text(
              appString(
                context,
                _mode == _AuthMode.signIn
                    ? 'Create account'
                    : 'I have an account',
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: AppSpace.md),
          TextButton(
            onPressed: _working ? null : () => _switchMode(_AuthMode.signIn),
            child: Text(appString(context, 'Back to sign in')),
          ),
        ],
        const SizedBox(height: AppSpace.gutter),
        Divider(color: theme.colorScheme.outlineVariant, height: 1),
        const SizedBox(height: AppSpace.xxl),
        TextButton.icon(
          onPressed: _working ? null : _continueOffline,
          icon: const Icon(Icons.devices_outlined),
          label: Text(appString(context, 'Use this device only')),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          appString(
            context,
            'Your breaks stay on this device. You can sign in later from Settings.',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String get _titleKey {
    switch (_mode) {
      case _AuthMode.signIn:
        return 'Sign in to StandUp';
      case _AuthMode.createAccount:
        return 'Create your account';
      case _AuthMode.reset:
        return 'Reset your password';
    }
  }

  String get _subtitleKey {
    switch (_mode) {
      case _AuthMode.signIn:
        return 'Sign in to sync your breaks across devices.';
      case _AuthMode.createAccount:
        return 'Create an account to sync your breaks across devices.';
      case _AuthMode.reset:
        return 'We will email you a link to choose a new password.';
    }
  }
}
