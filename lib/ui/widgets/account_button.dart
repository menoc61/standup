import 'dart:async';

import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/ui/screens/settings_screen.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

/// The account affordance: tapping the user's name opens Settings.
///
/// ## Why Settings is a route and not a tab
///
/// The bottom bar is capped at four destinations, and the daily-use screens —
/// Timer, Leaderboard, Analytics — deserve that budget more than a gear the user
/// opens occasionally. Making Settings a pushed route also puts it where it
/// belongs conceptually: it is per-person configuration, not another place in the
/// product's information architecture.
///
/// ## Why this is a StatelessWidget
///
/// It holds no state of its own. The label is derived from [AppState] on every
/// build, and the press feedback belongs to [SpringButton], which is already a
/// StatefulWidget handling exactly that. Wrapping it in another StatefulWidget
/// would mean a `setState` that exists only to duplicate a child's behaviour.
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
  final double topPadding;
  final double sidePadding;

  const AccountButton({
    super.key,
    required this.appState,
    required this.onRerunOnboarding,
    this.topPadding = 8,
    this.sidePadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding, right: sidePadding),
        child: Align(
          alignment: Alignment.topRight,
          child: Semantics(
            button: true,
            label: semantics,
            excludeSemantics: true,
            child: Tooltip(
              message: appString(context, 'Settings'),
              child: SpringButton(
                onTap: () => unawaited(_open(context)),
                borderRadius: BorderRadius.circular(999),
                scaleFactor: 0.94,
                semanticLabel: semantics,
                padding: const EdgeInsets.all(2),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.3
                              : 0.07,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Monogram(label: label, accent: accent),
                      if (label.length > 1) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          // Truncating rather than overflowing: a long name
                          // must not push the control past the content edge.
                          constraints: const BoxConstraints(maxWidth: 96),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
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

  const _Monogram({required this.label, required this.accent});

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
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }

    return CircleAvatar(
      radius: 15,
      backgroundColor: accent,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
