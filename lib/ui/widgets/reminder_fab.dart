import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/haptics_service.dart';

/// A completely round, glassmorphic reminder control floated bottom-left,
/// separate from the main bottom navigation. Tapping it opens the quick
/// reminder actions (stand up / snooze / skip / guided stretch).
class ReminderFab extends StatelessWidget {
  final AppState appState;

  const ReminderFab({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Semantics(
      button: true,
      label: appString(context, 'Reminder'),
      // Icon-only control with no text child: without an explicit label a screen
      // reader announces an unnamed double-tap target.
      excludeSemantics: true,
      child: Tooltip(
        message: appString(context, 'Reminder'),
        child: GestureDetector(
          onTap: () {
            unawaited(HapticsService.medium());
            _openActions(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.9),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 26,
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      appString(sheetContext, 'Reminder'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ActionTile(
                      icon: Icons.check_circle_rounded,
                      label: appString(sheetContext, 'I stood up!'),
                      color: accent,
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
                    const SizedBox(height: 8),
                    _ActionTile(
                      icon: Icons.snooze_rounded,
                      label: appString(sheetContext, 'Snooze 10m'),
                      color: Colors.amber.shade700,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        appState.snoozeReminder(minutes: 10);
                      },
                    ),
                    const SizedBox(height: 8),
                    _ActionTile(
                      icon: Icons.skip_next_rounded,
                      label: appString(sheetContext, 'Skip'),
                      color: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        appState.skipReminder();
                      },
                    ),
                    const SizedBox(height: 8),
                    _ActionTile(
                      icon: Icons.self_improvement_rounded,
                      label: appString(sheetContext, 'Start stretch'),
                      color: Colors.teal,
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
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
