import 'dart:async';

import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_spacing.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/haptics_service.dart';

/// A round quick-action control, kept separate from destination navigation.
class ReminderBellButton extends StatelessWidget {
  const ReminderBellButton({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windowOpen = appState.isActionWindowOpen;
    final accent = theme.colorScheme.primary;

    return Semantics(
      button: true,
      label: appString(context, 'Reminder'),
      // Icon-only control: without an explicit label a screen reader announces
      // an unnamed double-tap target.
      excludeSemantics: true,
      child: Tooltip(
        message: appString(context, 'Reminder'),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              unawaited(HapticsService.medium());
              _openActions(context);
            },
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: windowOpen ? accent : theme.colorScheme.surface,
                border: Border.all(
                  color: windowOpen ? accent : theme.colorScheme.outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: windowOpen ? 0.28 : 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    windowOpen
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    size: 25,
                    color: windowOpen
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                  if (windowOpen)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final accent = theme.colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xxl,
            0,
            AppSpace.xxl,
            AppSpace.section,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.huge),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      appString(sheetContext, 'Reminder'),
                      style: TextStyle(
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    _ActionTile(
                      icon: Icons.check_circle_rounded,
                      label: appString(sheetContext, 'I stood up!'),
                      color: AppColors.completed,
                      enabled:
                          appState.isActionWindowOpen ||
                          !appState.preferences.enforceActionWindow,
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        // Capture everything that needs a BuildContext before
                        // the await, so nothing reads context across the gap.
                        final messenger = ScaffoldMessenger.maybeOf(context);
                        final fallbackMessage = appString(
                          context,
                          'Not inside the movement window',
                        );

                        final accepted = await appState.completeReminder();
                        if (!accepted && messenger != null) {
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                                content: Text(
                                  appState.lastActionRejection ??
                                      fallbackMessage,
                                ),
                              ),
                            );
                        }
                      },
                    ),
                    const SizedBox(height: AppSpace.md),
                    _ActionTile(
                      icon: Icons.snooze_rounded,
                      label: appString(sheetContext, 'Next reminder'),
                      color: AppColors.snoozed,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        appState.snoozeReminder();
                      },
                    ),
                    const SizedBox(height: AppSpace.md),
                    _ActionTile(
                      icon: Icons.skip_next_rounded,
                      label: appString(sheetContext, 'Skip'),
                      color: AppColors.skipped,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        appState.skipReminder();
                      },
                    ),
                    const SizedBox(height: AppSpace.md),
                    _ActionTile(
                      icon: Icons.self_improvement_rounded,
                      label: appString(sheetContext, 'Start stretch'),
                      color: accent,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        appState.startGuidedStretch();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xxl,
              vertical: AppSpace.xxl,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: AppIconSize.nav),
                const SizedBox(width: AppSpace.xl),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFontSize.label,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: color,
                  size: AppIconSize.medium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
