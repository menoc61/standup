import 'dart:async';

import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/ui/screens/settings_screen.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

/// The account affordance: tapping the avatar opens Settings.
///
/// ## Why Settings is a route and not a tab
///
/// The bottom bar is capped at four destinations, and the daily-use screens —
/// Timer, Leaderboard, Analytics — deserve that budget more than a gear the user
/// opens occasionally. Making Settings a pushed route also puts it where it
/// belongs conceptually: it is per-person configuration, not another place in the
/// product's information architecture.
///
/// ## Why avatar-only
///
/// This sits at the trailing edge of the navigation bar alongside the other
/// items. At that size a name is unreadable and the label pushed the real
/// destinations off the row; the name is still exposed to screen readers and in
/// the tooltip, so nothing is lost for assistive technology.
///
/// ## Why this is a StatelessWidget
///
/// It holds no state of its own. The initials are derived from [AppState] on
/// every build, and the press feedback belongs to [SpringButton], which is
/// already a StatefulWidget handling exactly that. Wrapping it in another
/// StatefulWidget would mean a `setState` that exists only to duplicate a child's
/// behaviour.
///
/// The screen underneath stays mounted while this route is pushed, so returning
/// from Settings does not rebuild the dashboard or lose its scroll position. That
/// is what makes an appearance change feel immediate rather than like a reload.
class AccountButton extends StatelessWidget {
  final AppState appState;

  /// Replays onboarding. Supplied by the shell, which owns the top-level screen
  /// switch, so the button never has to reach across widget boundaries to
  /// rebuild the app.
  final VoidCallback onRerunOnboarding;
  final double size;

  const AccountButton({
    super.key,
    required this.appState,
    required this.onRerunOnboarding,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.getAccentColor(appState.preferences.colorSystem);
    final rawName = appState.userProfile?.name ?? '';

    // The seeded placeholder profile is literally named "Employee"; rendering
    // that reads as a bug rather than as a name.
    final label = (rawName.isEmpty || rawName == 'Employee')
        ? appString(context, 'Your account')
        : rawName;

    // Built with the value already substituted, because appString keys on the
    // literal it is given and cannot interpolate.
    final semantics = '${appString(context, 'Open settings')}: $label';

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Tooltip(
        message: semantics,
        child: SpringButton(
          onTap: () => unawaited(_open(context)),
          borderRadius: BorderRadius.circular(size / 2),
          scaleFactor: 0.94,
          semanticLabel: semantics,
          padding: EdgeInsets.zero,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            child: _Monogram(label: label, accent: accent, diameter: size - 8),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    unawaited(HapticsService.selection());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          appState: appState,
          onRerunOnboarding: onRerunOnboarding,
        ),
      ),
    );
  }
}

/// The leading initials shown inside the account control.
///
/// Falls back to a person glyph when there is nothing to initialise, because an
/// empty circle reads as a rendering failure rather than as an empty state.
class _Monogram extends StatelessWidget {
  final String label;
  final Color accent;
  final double diameter;

  const _Monogram({
    required this.label,
    required this.accent,
    this.diameter = 30,
  });

  @override
  Widget build(BuildContext context) {
    final initials = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    if (initials.isEmpty) {
      return Icon(
        Icons.person_outline,
        size: diameter * 0.55,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }

    return CircleAvatar(
      radius: diameter / 2,
      backgroundColor: accent,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: diameter * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
