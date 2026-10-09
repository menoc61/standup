import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/data/models/device_profile.dart';
import 'package:standup_app/data/remote/supabase_service.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/audio_service.dart';
import 'package:standup_app/services/background_run_service.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/ui/screens/org_admin_screen.dart';
import 'package:standup_app/ui/layout/adaptive.dart';
import 'package:standup_app/ui/widgets/glass_card.dart';
import 'package:standup_app/ui/widgets/segmented_choice.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

class SettingsScreen extends StatelessWidget {
  final AppState appState;
  final VoidCallback onRerunOnboarding;

  const SettingsScreen({
    super.key,
    required this.appState,
    required this.onRerunOnboarding,
  });

  void _showEditProfileDialog(BuildContext context) {
    final user = appState.userProfile;
    final nameCtrl = TextEditingController(text: user?.name);
    final desigCtrl = TextEditingController(text: user?.designation);
    final emailCtrl = TextEditingController(text: user?.email);
    String dept = user?.department ?? 'Engineering';

    final departments = [
      'Engineering',
      'Product & Design',
      'Marketing & Sales',
      'People & Ops',
      'Finance',
      'Leadership',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(appString(context, 'Edit Employee Profile')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desigCtrl,
                  decoration: const InputDecoration(labelText: 'Designation'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Work Email'),
                ),
                const SizedBox(height: 16),
                Text(
                  appString(context, 'Department'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DropdownButton<String>(
                  value: dept,
                  isExpanded: true,
                  items: departments
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => dept = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(appString(context, 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                appState.updateProfile(
                  name: nameCtrl.text.trim(),
                  designation: desigCtrl.text.trim(),
                  department: dept,
                  email: emailCtrl.text.trim(),
                );
                Navigator.pop(ctx);
              },
              child: Text(appString(context, 'Save')),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // A TextEditingController owns a native text buffer. The two sibling
      // dialogs in this file dispose theirs; this one did not, so every profile
      // edit leaked three of them.
      nameCtrl.dispose();
      desigCtrl.dispose();
      emailCtrl.dispose();
    });
  }

  void _showAccountDialog(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final emailController = TextEditingController(
      text: appState.userProfile?.email ?? '',
    );
    final passwordController = TextEditingController();
    var createAccount = false;
    var isWorking = false;
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> signInWithProvider(OAuthProvider provider) async {
            setDialogState(() {
              isWorking = true;
              errorText = null;
            });
            try {
              await appState.signInWithProvider(provider);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (error) {
              if (dialogContext.mounted) {
                setDialogState(() => errorText = _friendlyAuthError(error));
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => isWorking = false);
              }
            }
          }

          Future<void> sendMagicLink() async {
            final email = emailController.text.trim();
            if (!email.contains('@')) {
              setDialogState(
                () => errorText = 'Enter your email address first.',
              );
              return;
            }
            setDialogState(() {
              isWorking = true;
              errorText = null;
            });
            try {
              await appState.sendMagicLink(email);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    appString(
                      context,
                      'Sign-in link sent. Check your email to continue.',
                    ),
                  ),
                ),
              );
            } catch (error) {
              if (dialogContext.mounted) {
                setDialogState(() => errorText = _friendlyAuthError(error));
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => isWorking = false);
              }
            }
          }

          Future<void> submit() async {
            final email = emailController.text.trim();
            final password = passwordController.text;
            if (!email.contains('@') ||
                password.isEmpty ||
                (createAccount && password.length < 8)) {
              setDialogState(
                () => errorText = createAccount
                    ? 'Enter a valid email and a password with at least 8 characters.'
                    : 'Enter a valid email and password.',
              );
              return;
            }
            setDialogState(() {
              isWorking = true;
              errorText = null;
            });
            try {
              if (createAccount) {
                final hasSession = await appState.createAccount(
                  email: email,
                  password: password,
                );
                if (!hasSession) {
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        appString(
                          context,
                          'Check your email to confirm your account, then sign in here.',
                        ),
                      ),
                    ),
                  );
                  return;
                }
                await appState.attachCurrentAccount();
              } else {
                await appState.signIn(email: email, password: password);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (error) {
              if (dialogContext.mounted) {
                setDialogState(() => errorText = _friendlyAuthError(error));
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => isWorking = false);
              }
            }
          }

          return AlertDialog(
            title: Text(
              appString(
                context,
                createAccount ? 'Create your account' : 'Sign in to StandUp',
              ),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      createAccount
                          ? 'Your local reminder history will stay on this device and move with your account.'
                          : 'Sign in to enable private account sync for your daily totals.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      autofillHints: [
                        createAccount
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: createAccount
                            ? 'Use at least 8 characters.'
                            : null,
                      ),
                      onSubmitted: (_) => isWorking ? null : submit(),
                    ),
                    if (!createAccount) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isWorking ? null : sendMagicLink,
                          child: Text(
                            appString(context, 'Email me a sign-in link'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              appString(context, 'OR'),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: isWorking
                                ? null
                                : () =>
                                      signInWithProvider(OAuthProvider.google),
                            icon: const Icon(Icons.g_mobiledata, size: 20),
                            label: Text(appString(context, 'Google')),
                          ),
                          OutlinedButton.icon(
                            onPressed: isWorking
                                ? null
                                : () => signInWithProvider(OAuthProvider.apple),
                            icon: const Icon(Icons.phone_iphone, size: 18),
                            label: Text(appString(context, 'Apple')),
                          ),
                        ],
                      ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isWorking
                    ? null
                    : () => setDialogState(() {
                        createAccount = !createAccount;
                        errorText = null;
                      }),
                child: Text(
                  appString(
                    context,
                    createAccount ? 'I have an account' : 'Create account',
                  ),
                ),
              ),
              FilledButton(
                onPressed: isWorking ? null : submit,
                child: isWorking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        appString(
                          context,
                          createAccount ? 'Create account' : 'Sign in',
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      emailController.dispose();
      passwordController.dispose();
    });
  }

  String _friendlyAuthError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('Invalid login credentials')) {
      return 'Email or password is incorrect.';
    }
    if (message.contains('already registered')) {
      return 'An account already exists. Choose Sign in.';
    }
    if (message.contains('different saved account')) return message;
    if (message.contains('not configured')) {
      return 'Cloud accounts are not configured for this app yet.';
    }
    return message;
  }

  void _showJoinWorkspaceDialog(BuildContext context) {
    final codeController = TextEditingController();
    var joining = false;
    String? errorText;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(appString(context, 'Join your workspace')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appString(
                  context,
                  'Enter the invite code provided by your organization.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Workspace invite code',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: joining ? null : () => Navigator.pop(dialogContext),
              child: Text(appString(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: joining
                  ? null
                  : () async {
                      if (codeController.text.trim().isEmpty) {
                        setDialogState(
                          () => errorText = 'Enter an invite code to continue.',
                        );
                        return;
                      }
                      setDialogState(() {
                        joining = true;
                        errorText = null;
                      });
                      try {
                        await appState.joinOrganization(codeController.text);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          final message = error.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                          setDialogState(
                            () => errorText = message.contains('not valid')
                                ? 'That invite code was not recognized.'
                                : _friendlyAuthError(error),
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => joining = false);
                        }
                      }
                    },
              child: joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(appString(context, 'Join workspace')),
            ),
          ],
        ),
      ),
    ).whenComplete(codeController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final prefs = appState.preferences;
    final accent = AppColors.getAccentColor(prefs.colorSystem);
    final user = appState.userProfile;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final departments = const [
      'Engineering',
      'Product & Design',
      'Marketing & Sales',
      'People & Ops',
      'Finance',
      'Leadership',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(appString(context, 'Preferences & Settings'))),
      body: SafeArea(
        // Settings is a pushed route, so it sits outside the shell's
        // constrainContent. Without a ceiling every card stretches to the full
        // width of a desktop window.
        child: constrainContent(
          RefreshIndicator(
            onRefresh: () => appState.triggerCloudSync(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                // ----------------------------------------------------------------
                // Language
                // ----------------------------------------------------------------
                _GlassSection(
                  reduceMotion: reduceMotion,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          appString(context, 'Language'),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: 'fr',
                            label: Text(appString(context, 'French')),
                          ),
                          ButtonSegment(
                            value: 'en',
                            label: Text(appString(context, 'English')),
                          ),
                        ],
                        selected: {appState.languageCode},
                        onSelectionChanged: (selection) =>
                            appState.updateLanguage(selection.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ----------------------------------------------------------------
                // Profile & Team
                // ----------------------------------------------------------------
                _GlassSection(
                  reduceMotion: reduceMotion,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: accent.withValues(alpha: 0.2),
                            child: Text(
                              user != null && user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ??
                                      appString(context, 'Employee User'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${user?.designation ?? appString(context, 'Member')} • ${user?.department ?? appString(context, 'General')}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.email ??
                                      appString(context, 'No email linked'),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: appString(
                              context,
                              'Edit Employee Profile',
                            ),
                            onPressed: () => _showEditProfileDialog(context),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          appString(context, 'Team'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: departments.contains(user?.department)
                            ? user?.department
                            : departments.first,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: appString(context, 'Your team'),
                        ),
                        items: departments
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text(appString(context, d)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            appState.updateProfile(department: value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: user?.organizationName ?? '',
                        decoration: InputDecoration(
                          labelText: appString(context, 'Workspace label'),
                          hintText: appString(
                            context,
                            'Optional team or workspace name',
                          ),
                        ),
                        onFieldSubmitted: (value) => appState.updateProfile(
                          organizationName: value.trim(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ----------------------------------------------------------------
                // Reminder cadence & notifications
                // ----------------------------------------------------------------
                _SectionTitle(appString(context, 'Reminder Cadence')),
                const SizedBox(height: 12),
                _GlassSection(
                  reduceMotion: reduceMotion,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appString(context, 'Frequency Interval'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [30, 60, 90].map((mins) {
                          final isSel = prefs.notificationFrequency == mins;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: InkWell(
                                onTap: () => appState.updatePreferences(
                                  notificationFrequency: mins,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSel ? accent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel
                                          ? accent
                                          : theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    formatDurationLabel(context, mins),
                                    style: TextStyle(
                                      color: isSel
                                          ? Colors.white
                                          : theme.textTheme.bodyLarge?.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appString(context, 'Daily stand goal'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  appString(
                                    context,
                                    'Target number of stand-ups per day',
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          DropdownButton<int>(
                            value: prefs.streakGoal,
                            underline: const SizedBox.shrink(),
                            items: [4, 6, 8, 10, 12]
                                .map(
                                  (n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                appState.updatePreferences(streakGoal: value);
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      _NotificationPermissionTile(
                        accent: accent,
                        appState: appState,
                      ),
                      const Divider(height: 20),
                      _QuietHoursRow(
                        accent: accent,
                        quietHours: prefs.quietHours,
                        onChanged: (value) => appState.updatePreferences(
                          quietHours: value,
                          clearQuietHours: value == null,
                        ),
                      ),
                      const Divider(height: 24),
                      _ActionWindowSection(appState: appState, accent: accent),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ----------------------------------------------------------------
                // Appearance
                // ----------------------------------------------------------------
                _SectionTitle(appString(context, 'Appearance & Styling')),
                const SizedBox(height: 12),
                _GlassSection(
                  reduceMotion: reduceMotion,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appString(context, 'App Theme Mode'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appString(
                          context,
                          'Light, dark, or follow your device setting.',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      // One accessible control replaces the previous row of
                      // unlabelled InkWells. Each option carries an icon so the
                      // three choices are distinguishable without reading them.
                      SegmentedChoice<String>(
                        semanticLabel: appString(context, 'App Theme Mode'),
                        selected: prefs.themeMode,
                        onChanged: (mode) =>
                            appState.updatePreferences(themeMode: mode),
                        singleRow: true,
                        options: [
                          SegmentedOption(
                            value: 'system',
                            label: appString(context, 'System'),
                            icon: Icons.brightness_auto_outlined,
                          ),
                          SegmentedOption(
                            value: 'light',
                            label: appString(context, 'Light'),
                            icon: Icons.light_mode_outlined,
                          ),
                          SegmentedOption(
                            value: 'dark',
                            label: appString(context, 'Dark'),
                            icon: Icons.dark_mode_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        appString(context, 'Color Accent System'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appString(
                          context,
                          'The app is black and white. Your accent colours the actions.',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      // Options come from the palette, so this can never offer a
                      // colour the theme cannot render.
                      SegmentedChoice<String>(
                        semanticLabel: appString(
                          context,
                          'Color Accent System',
                        ),
                        selected: prefs.colorSystem,
                        onChanged: (id) =>
                            appState.updatePreferences(colorSystem: id),
                        options: [
                          for (final option in AppColors.accents)
                            SegmentedOption(
                              value: option.id,
                              label: appString(context, option.label),
                              icon: Icons.circle,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ----------------------------------------------------------------
                // Sounds & haptics
                // ----------------------------------------------------------------
                _SectionTitle(appString(context, 'Sounds & Haptics')),
                const SizedBox(height: 12),
                _GlassSection(
                  reduceMotion: reduceMotion,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appString(context, 'Acoustic Chimes'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  appString(
                                    context,
                                    'Play melodic alert on break cadence',
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: prefs.soundEnabled,
                            activeThumbColor: accent,
                            onChanged: (val) =>
                                appState.updatePreferences(soundEnabled: val),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appString(context, 'Vibration & Haptics'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  appString(
                                    context,
                                    'Use the native vibration on every action',
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: prefs.hapticsEnabled,
                            activeThumbColor: accent,
                            onChanged: (val) {
                              appState.updatePreferences(hapticsEnabled: val);
                              if (val) HapticsService.medium();
                            },
                          ),
                        ],
                      ),
                      if (prefs.soundEnabled) ...[
                        const Divider(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            appString(context, 'Reminder tone'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: AudioService.soundAssets.keys.map((key) {
                            final isSel = prefs.selectedSound == key;
                            return _SoundChip(
                              label: appString(context, _soundLabel(key)),
                              selected: isSel,
                              accent: accent,
                              onTap: () {
                                appState.updatePreferences(selectedSound: key);
                                appState.audioService.playSound(key);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ----------------------------------------------------------------
                // Background run
                // ----------------------------------------------------------------
                _SectionTitle(appString(context, 'Background Run')),
                const SizedBox(height: 12),
                const _BackgroundRunSection(),
                const SizedBox(height: 24),

                // ----------------------------------------------------------------
                // Device & privacy transparency
                // ----------------------------------------------------------------
                _SectionTitle(appString(context, 'Device & app')),
                const SizedBox(height: 12),
                _DeviceSection(appState: appState, accent: accent),
                const SizedBox(height: 24),

                // ----------------------------------------------------------------
                // Account
                // ----------------------------------------------------------------
                _SectionTitle(appString(context, 'Account')),
                const SizedBox(height: 12),
                _GlassSection(
                  reduceMotion: reduceMotion,
                  child: Row(
                    children: [
                      Icon(
                        appState.supabaseService.signedInUserId == null
                            ? Icons.cloud_off_outlined
                            : Icons.cloud_done_outlined,
                        color: accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appString(
                                context,
                                appState.supabaseService.signedInUserId == null
                                    ? 'Using this device'
                                    : appState.supabaseService.signedInEmail ??
                                          'Account connected',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              appString(
                                context,
                                appState.supabaseService.isInitialized
                                    ? (appState
                                                  .supabaseService
                                                  .signedInUserId ==
                                              null
                                          ? 'Sign in to turn on account sync'
                                          : 'Your account is securely connected')
                                    : 'Cloud accounts need Supabase project keys',
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (appState.supabaseService.isInitialized)
                        TextButton(
                          onPressed:
                              appState.supabaseService.signedInUserId == null
                              ? () => _showAccountDialog(context)
                              : () => appState.signOut(),
                          child: Text(
                            appString(
                              context,
                              appState.supabaseService.signedInUserId == null
                                  ? 'Connect'
                                  : 'Sign out',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (appState.supabaseService.signedInUserId != null) ...[
                  _SectionTitle(appString(context, 'Workspace')),
                  const SizedBox(height: 12),
                  _GlassSection(
                    reduceMotion: reduceMotion,
                    child: Row(
                      children: [
                        Icon(Icons.groups_2_outlined, color: accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.organizationName ??
                                    appString(
                                      context,
                                      user?.organizationId == null
                                          ? 'No workspace linked'
                                          : 'Workspace linked',
                                    ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                appString(
                                  context,
                                  'Invite code connects your account to organization insights.',
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showJoinWorkspaceDialog(context),
                          child: Text(appString(context, 'Join')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ----------------------------------------------------------------
                  // Organization admin
                  // ----------------------------------------------------------------
                  _SectionTitle(appString(context, 'Organization')),
                  const SizedBox(height: 12),
                  _GlassSection(
                    reduceMotion: reduceMotion,
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings_outlined,
                          color: accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appString(context, 'Organization dashboard'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                appString(
                                  context,
                                  'Anonymised adherence and team trends. No individual is ever named.',
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        // Disabled rather than hidden when no workspace is linked:
                        // the row keeps its position instead of shifting under
                        // the user's finger once an invite code is applied.
                        TextButton(
                          onPressed: user?.organizationId == null
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        OrgAdminScreen(appState: appState),
                                  ),
                                ),
                          child: Text(appString(context, 'Open')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ----------------------------------------------------------------
                // Cloud sync & privacy
                // ----------------------------------------------------------------
                _SectionTitle(appString(context, 'Cloud Sync & Privacy')),
                const SizedBox(height: 12),
                _GlassSection(
                  reduceMotion: reduceMotion,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appString(context, 'Contribute Statistics'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  appString(
                                    context,
                                    'Share anonymized daily counts with employer',
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: prefs.statisticsOptIn,
                            activeThumbColor: accent,
                            onChanged: (val) => appState.updatePreferences(
                              statisticsOptIn: val,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appString(context, 'Supabase Cloud Sync'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  appString(context, switch (appState
                                      .syncStatus) {
                                    SyncStatus.syncing =>
                                      'Synchronizing in progress...',
                                    SyncStatus.success => 'Daily totals synced',
                                    SyncStatus.error =>
                                      'Sync failed; your local data is safe',
                                    _ => 'Local-only until Supabase Auth is configured',
                                  }),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          SpringButton(
                            onTap: () => appState.triggerCloudSync(),
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              appString(context, 'Sync Now'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ----------------------------------------------------------------
                // Data & onboarding
                // ----------------------------------------------------------------
                SpringButton(
                  onTap: () => _showExportSheet(context),
                  backgroundColor: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                  foregroundColor: theme.textTheme.bodyLarge?.color,
                  isFullWidth: true,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text(appString(context, 'Export my data')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SpringButton(
                  onTap: onRerunOnboarding,
                  backgroundColor: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                  foregroundColor: theme.textTheme.bodyLarge?.color,
                  isFullWidth: true,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.replay, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        appString(context, 'Replay 10-Slide Onboarding Tour'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Text(
                    appString(
                      context,
                      'StandUp v1.0.0 • Production Flutter + Supabase + Drift',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _soundLabel(String key) {
    return switch (key) {
      'chime' => 'Gentle chime',
      'success' => 'Bright success',
      'nudge' => 'Soft nudge',
      _ => 'Soft click',
    };
  }

  void _showExportSheet(BuildContext context) {
    final history = appState.dailyHistory;
    final rows = <String>[
      'date,stands_completed,stands_snoozed,stands_skipped,total_minutes',
    ];
    for (final d in history) {
      rows.add(
        '${d.date},${d.remindersCompleted},${d.remindersSnoozed},${d.remindersSkipped},${d.totalStandTime}',
      );
    }
    final csv = rows.join('\n');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // The CSV grows with the user's history, so the sheet must be allowed to
      // use more than the default 9/16 of the screen and must scroll internally.
      isScrollControlled: true,
      builder: (sheetContext) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.surface
                  .withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appString(sheetContext, 'Export my data'),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  appString(
                    sheetContext,
                    'A CSV summary of your daily stand-up history, generated on this device.',
                  ),
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      csv,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SpringButton(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Clipboard.setData(ClipboardData(text: csv));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          appString(context, 'CSV copied to your clipboard'),
                        ),
                      ),
                    );
                  },
                  backgroundColor: accentFor(context),
                  isFullWidth: true,
                  child: Center(
                    child: Text(
                      appString(sheetContext, 'Copy CSV to clipboard'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color accentFor(BuildContext context) =>
      AppColors.getAccentColor(appState.preferences.colorSystem);
}

/// A section heading used across the preferences list.
class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}

/// The action-window rule, exposed so the product rule is auditable and can be
/// relaxed for pilots without a code change.
class _ActionWindowSection extends StatelessWidget {
  final AppState appState;
  final Color accent;

  const _ActionWindowSection({required this.appState, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = appState.preferences;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appString(context, 'Enforce the action window'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    appString(
                      context,
                      prefs.enforceActionWindow
                          ? 'When on, a stand-up only counts inside the window.'
                          : 'When off, a stand-up is accepted at any time.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: prefs.enforceActionWindow,
              activeThumbColor: accent,
              onChanged: (val) =>
                  appState.updatePreferences(enforceActionWindow: val),
            ),
          ],
        ),
        if (prefs.enforceActionWindow) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appString(context, 'Window length'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      appString(
                        context,
                        'Open this many minutes before the hour ends',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              DropdownButton<int>(
                value: prefs.actionWindowMinutes,
                underline: const SizedBox.shrink(),
                items: [3, 5, 10, 15]
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text('$m min')),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    appState.updatePreferences(actionWindowMinutes: value);
                  }
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Shows exactly what the app reports about this device, and nothing more.
class _DeviceSection extends StatelessWidget {
  final AppState appState;
  final Color accent;

  const _DeviceSection({required this.appState, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = appState.deviceProfile;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices_other_outlined, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appString(context, 'This device'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      profile == null
                          ? appString(context, 'Collecting…')
                          : '${profile.deviceType} · ${profile.platform} · '
                                '${profile.appVersion}+${profile.appBuild}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 18),
                tooltip: appString(context, 'What this device reports'),
                onPressed: profile == null
                    ? null
                    : () => _showDetails(context, profile),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            appString(
              context,
              'Everything below is read from your operating system and stored on this device. No IP address, location, or advertising identifier is ever collected.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (appState.isClockUnreliable)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.skipped,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appString(
                      context,
                      'The device clock has moved repeatedly, so totals are flagged as unreliable for the leaderboard.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.skipped,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: AppColors.completed,
                ),
                const SizedBox(width: 8),
                Text(
                  appString(context, 'Clock looks normal'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, DeviceProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.surface
                  .withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appString(sheetContext, 'What this device reports'),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      profile.describeForUser(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SpringButton(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: profile.describeForUser()),
                    );
                    Navigator.pop(sheetContext);
                  },
                  backgroundColor: AppColors.getAccentColor(
                    appState.preferences.colorSystem,
                  ),
                  isFullWidth: true,
                  child: Center(
                    child: Text(appString(sheetContext, 'Copy device details')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass section used for every preferences block.
class _GlassSection extends StatelessWidget {
  final Widget child;
  final bool reduceMotion;

  const _GlassSection({required this.child, this.reduceMotion = false});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      reduceMotion: reduceMotion,
      child: child,
    );
  }
}

class _SoundChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SoundChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? accent
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 16,
                color: selected ? accent : null,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? accent
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationPermissionTile extends StatefulWidget {
  final Color accent;
  final AppState appState;

  const _NotificationPermissionTile({
    required this.accent,
    required this.appState,
  });

  @override
  State<_NotificationPermissionTile> createState() =>
      _NotificationPermissionTileState();
}

class _NotificationPermissionTileState
    extends State<_NotificationPermissionTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.notifications_active_outlined, color: widget.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appString(context, 'Notifications'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                appString(
                  context,
                  'Allow alerts and exact timers so reminders arrive on time.',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _request,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(appString(context, 'Enable')),
        ),
      ],
    );
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      final granted = await widget.appState.notificationService
          .requestPermissions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? appString(context, 'Notifications are enabled')
                : appString(
                    context,
                    'Notifications were not granted on this device',
                  ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _QuietHoursRow extends StatelessWidget {
  final Color accent;
  final String? quietHours;
  final ValueChanged<String?> onChanged;

  const _QuietHoursRow({
    required this.accent,
    required this.quietHours,
    required this.onChanged,
  });

  static const _options = <String?>[
    null,
    '20:00-08:00',
    '21:00-07:00',
    '22:00-06:00',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appString(context, 'Quiet hours'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                appString(
                  context,
                  'Pause reminders during your personal rest window',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        DropdownButton<String?>(
          value: _options.contains(quietHours) ? quietHours : null,
          underline: const SizedBox.shrink(),
          hint: Text(appString(context, 'Off')),
          items: _options
              .map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(value ?? appString(context, 'Off')),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Background run opt-in. On Android this opens the battery optimisation
/// exemption screen; other platforms explain their own limitation.
class _BackgroundRunSection extends StatefulWidget {
  const _BackgroundRunSection();

  @override
  State<_BackgroundRunSection> createState() => _BackgroundRunSectionState();
}

class _BackgroundRunSectionState extends State<_BackgroundRunSection> {
  BackgroundRunStatus _status = BackgroundRunStatus.unknown;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await BackgroundRunService.currentStatus();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final (title, subtitle, actionable) = switch (_status) {
      BackgroundRunStatus.allowed => (
        appString(context, 'Background run enabled'),
        appString(
          context,
          'StandUp can wake on schedule even when the app is closed.',
        ),
        false,
      ),
      BackgroundRunStatus.restricted => (
        appString(context, 'Allow background activity'),
        appString(
          context,
          'Your device may delay reminders. Grant the battery exemption for exact timing.',
        ),
        true,
      ),
      BackgroundRunStatus.unknown => (
        appString(context, 'Background run'),
        appString(
          context,
          'On Android, allow StandUp to ignore battery optimisation for exact reminders.',
        ),
        true,
      ),
    };

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.battery_saver_outlined, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (actionable)
            TextButton(
              onPressed: _busy ? null : _request,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(appString(context, 'Allow')),
            ),
        ],
      ),
    );
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await BackgroundRunService.requestExemption();
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
