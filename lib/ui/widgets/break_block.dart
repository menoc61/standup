import 'package:flutter/material.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

/// The forced-break screen: a full-window cover raised for the duration of a
/// break window when the user has opted into it.
///
/// ## What this can and cannot do
///
/// Inside the app it is authoritative: a [ModalBarrier] swallows every pointer
/// event and the whole window is painted over, so nothing underneath can be
/// tapped. It is **not** an operating-system lock — on desktop the user can
/// still Alt-Tab away, and only the native keep-above work can change that. This
/// is deliberately the in-app half, so the behaviour is honest on every platform
/// and the native layer only has to raise the window.
///
/// ## Why it is mounted from `MaterialApp.builder`
///
/// The block must cover *any* route, including one pushed by a deep link while
/// the break opens. Wrapping the navigator once is the only way a screen cannot
/// forget to include it.
class BreakBlockOverlay extends StatelessWidget {
  final AppState appState;

  /// Whether the block may show at all. False during splash and onboarding.
  final bool active;

  /// The decorated app, painted underneath the cover.
  final Widget child;

  const BreakBlockOverlay({
    super.key,
    required this.appState,
    required this.active,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        // The window end is read from the app state on every tick, so the
        // countdown below stays in step with the timer that decides when the
        // block lifts.
        final window = appState.activeWindow;
        final show = active && appState.isBreakBlockActive && window != null;

        return Stack(
          children: [
            child,
            if (show) ...[
              // Swallows taps, drags and scrolls aimed at the app underneath.
              const ModalBarrier(dismissible: false, color: Colors.black54),
              Positioned.fill(
                child: BreakBlockScreen(
                  endsAt: window.end,
                  standing: appState.isBreakActive,
                  onStoodUp: () => appState.completeReminder(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The cover itself: pure presentation, so it is testable without an `AppState`.
///
/// [endsAt] is the instant the break window closes, which is also the moment the
/// cover lifts on its own. There is intentionally no dismiss button: the two
/// honest ways out are standing up (which logs the break) and the window simply
/// ending, and a third escape hatch would turn the block into a suggestion.
class BreakBlockScreen extends StatelessWidget {
  final DateTime endsAt;

  /// True while the completion is being written, so the button cannot be
  /// double-tapped into two records.
  final bool standing;

  final VoidCallback onStoodUp;

  const BreakBlockScreen({
    super.key,
    required this.endsAt,
    required this.onStoodUp,
    this.standing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = endsAt.difference(DateTime.now());
    // A window that has already closed shows zero rather than a negative time.
    final clock = formatClock(remaining.isNegative ? Duration.zero : remaining);

    return Semantics(
      // Marks this as the screen a screen reader should treat as a new route.
      // The visible heading below provides its name, so no label is set here.
      scopesRoute: true,
      explicitChildNodes: true,
      child: Material(
        color: scheme.surface,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.accessibility_new,
                        color: scheme.primary,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      appString(context, 'Time to stand up'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      appString(
                        context,
                        'Stand, stretch and breathe. This screen lifts when the break ends or when you log it.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      appStringArgs(context, 'Unlocks in {time}', {
                        'time': clock,
                      }),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SpringButton(
                      onTap: standing ? null : onStoodUp,
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      child: Text(appString(context, 'I stood up')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
