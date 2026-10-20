import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_spacing.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/ui/widgets/posture_avatar.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

/// The five-minute guided routine, as a panel that can live anywhere.
///
/// ## Why this is a widget and not a bottom sheet
///
/// It used to exist only as the private `_GuidedStretchSheet` in
/// `home_screen.dart`, which meant the one screen where a guided stretch is most
/// obviously the right action — the forced-break cover — could not offer it. The
/// cover cannot push a route either: it is mounted from `MaterialApp.builder`,
/// *above* the navigator, so a modal sheet opened from it would render
/// underneath the very overlay that asked for it. So the routine is a plain
/// widget, and the two callers decide their own chrome: [GuidedStretchSheet]
/// wraps it in the bottom-sheet look the dashboard uses, and
/// `BreakBlockOverlay` swaps the cover for it in place.
///
/// [onClose] is called when the routine ends, whether the user finished it,
/// cancelled it, or let the timer complete it; the caller restores its own view.
class GuidedStretchPanel extends StatefulWidget {
  final AppState appState;

  /// Whether the routine starts on mount. False when the caller already started
  /// it (nothing needs to start it twice, and the app state is the timer's home).
  final bool autoStart;

  /// Chrome for the bottom-sheet presentation: a drag handle, a blurred rounded
  /// top, and a bottom gutter. Off when the panel is embedded.
  final bool sheetChrome;

  final VoidCallback? onClose;

  const GuidedStretchPanel({
    super.key,
    required this.appState,
    this.autoStart = true,
    this.sheetChrome = false,
    this.onClose,
  });

  @override
  State<GuidedStretchPanel> createState() => _GuidedStretchPanelState();
}

class _GuidedStretchPanelState extends State<GuidedStretchPanel> {
  bool _hasStarted = false;
  bool _closeScheduled = false;

  // Stored as English source strings and translated at render time so the whole
  // routine switches language with the rest of the interface.
  final List<Map<String, String>> _stretches = [
    {
      'title': '1. Overhead Reach & Spinal Stretch',
      'instruction': 'Interlace fingers, reach palms upward towards ceiling, lengthen spine and breathe deeply for 60 seconds.',
    },
    {
      'title': '2. Chest Opener & Shoulder Retraction',
      'instruction': 'Clasp hands behind lower back, pull shoulders down and back, lift chin gently, expanding lungs.',
    },
    {
      'title': '3. Standing Quad & Hip Flexor Stretch',
      'instruction': 'Hold desk for balance, grasp right ankle behind you for 30s, then switch to left ankle.',
    },
    {
      'title': '4. Standing Calf Raises',
      'instruction': 'Slowly rise onto balls of both feet, hold 2 seconds, lower slowly. Repeat 15 times.',
    },
    {
      'title': '5. Gentle Torso Twists',
      'instruction': 'With feet shoulder-width apart, gently rotate torso left and right with arms relaxed.',
    },
  ];

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppStateChanged);
    _hasStarted = true;
    if (widget.autoStart) {
      widget.appState.startGuidedStretch();
    }
  }

  /// Leaves when the routine stops running, so a panel that is embedded in the
  /// cover and a sheet that is pushed over the dashboard behave the same way:
  /// no stale "0:00" left counting a routine nobody is doing.
  void _onAppStateChanged() {
    if (!_hasStarted || widget.appState.isBreakActive || _closeScheduled) {
      return;
    }
    _closeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.onClose != null) {
        widget.onClose!();
        return;
      }
      // As a sheet there is no caller-provided close, so the routine's end
      // dismisses its own route.
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).maybePop();
      }
    });
  }

  Future<void> _finishGuidedStretch() async {
    HapticsService.celebration();
    try {
      final completed = await widget.appState.finishGuidedStretch();
      if (!mounted || completed) return;
      final message = widget.appState.lastActionRejection;
      if (message != null) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            appString(context, 'Unable to save the completed stretch'),
          ),
        ),
      );
      debugPrint('Unable to save guided stretch: $error');
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    // Dismissing the panel means the user abandoned the routine. Stop its timer
    // before it can auto-log an activity after the panel is gone.
    if (widget.appState.isBreakActive) {
      widget.appState.cancelGuidedStretch();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    if (!widget.sheetChrome) return body;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.section,
            AppSpace.xl,
            AppSpace.section,
            AppSpace.gutter,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.80),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1.2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 44,
                height: AppSpace.xs,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpace.huge),
              body,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.getAccentColor(
      widget.appState.preferences.colorSystem,
    );
    final step = widget.appState.activeBreakStep.clamp(
      0,
      _stretches.length - 1,
    );
    final current = _stretches[step];
    final remaining = widget.appState.breakSecondsRemaining;
    final mins = remaining ~/ 60;
    final secs = remaining % 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              appStringArgs(context, '{minutes}-Min Guided Stretch', {
                'minutes': '${widget.appState.breakTotalSeconds ~/ 60}',
              }),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xl,
                vertical: AppSpace.sm,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                '${mins.toString().padLeft(2, '0')}:'
                '${secs.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: accent,
                  fontSize: AppFontSize.label,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.huge),
        // Step progress dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_stretches.length, (i) {
            final active = i == step;
            final done = i < step;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
              width: active ? 24 : 8,
              height: AppSpace.md,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.completed
                    : active
                    ? accent
                    : Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpace.huge),
        Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Center(
                child: PostureAvatar(
                  isStanding: true,
                  stretchProgress: 0.35 + step * 0.1,
                  accentColor: accent,
                  size: 92,
                ),
              ),
            )
            .animate(key: ValueKey(step))
            .scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: AppSpace.xl),
        Text(
          appString(context, current['title']!),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ).animate(key: ValueKey('$step-title')).fadeIn(duration: 300.ms),
        const SizedBox(height: AppSpace.md),
        Text(
              appString(context, current['instruction']!),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            )
            .animate(key: ValueKey('$step-body'))
            .fadeIn(delay: 100.ms, duration: 300.ms),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: SpringButton(
                onTap: () => unawaited(_finishGuidedStretch()),
                backgroundColor: AppColors.completed,
                child: Text(appString(context, 'Finish & Log Stand')),
              ),
            ),
            const SizedBox(width: AppSpace.xl),
            SpringButton(
              onTap: () {
                HapticsService.light();
                widget.appState.cancelGuidedStretch();
              },
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              foregroundColor: theme.textTheme.bodyLarge?.color,
              child: Text(appString(context, 'Cancel')),
            ),
          ],
        ),
      ],
    );
  }
}

/// The dashboard's presentation of [GuidedStretchPanel]: the same routine, as a
/// bottom sheet.
class GuidedStretchSheet extends StatelessWidget {
  final AppState appState;

  const GuidedStretchSheet({super.key, required this.appState});

  @override
  Widget build(BuildContext context) => GuidedStretchPanel(
    appState: appState,
    autoStart: true,
    sheetChrome: true,
  );
}
