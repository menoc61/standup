import 'package:flutter/material.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

/// The "you asked not to be interrupted" bar.
///
/// ## Why quiet mode needs to be visible
///
/// Every other interruption control is a preference: it changes what happens
/// next, and forgetting it costs nothing you can see. Quiet mode is a *state*,
/// and a state that suppresses reminders is indistinguishable from a broken app
/// once it is on. It therefore has to announce itself, and it has to offer the
/// way back in one tap — which is the work the banner does.
///
/// It rides in `MaterialApp.builder`, so it is present over onboarding, the
/// dashboard and every route alike, and it never traps input.
class QuietModeOverlay extends StatelessWidget {
  final AppState appState;

  /// Whether the banner may show at all. False during splash and onboarding,
  /// where there is no reminder rhythm to have paused.
  final bool active;

  final Widget child;

  const QuietModeOverlay({
    super.key,
    required this.appState,
    required this.active,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Stack(
        children: [
          child,
          if (active && appState.isQuietMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: QuietModeBanner(
                    onResume: () => appState.setQuietMode(false),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The bar itself: pure presentation, so it can be tested without an
/// `AppState`.
class QuietModeBanner extends StatelessWidget {
  final VoidCallback onResume;

  /// Injected for tests; defaults to the platform's reduced-motion setting.
  final bool? reduceMotionOverride;

  const QuietModeBanner({
    super.key,
    required this.onResume,
    this.reduceMotionOverride,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion =
        reduceMotionOverride ?? MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: TweenAnimationBuilder<double>(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: 1),
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, -18 * (1 - t)),
              child: child,
            ),
          ),
          child: Material(
            elevation: 8,
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.do_not_disturb_on_outlined,
                      color: scheme.onSurfaceVariant,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            appString(context, 'Quiet mode'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appString(
                            context,
                            'Reminders and the forced break are paused until you resume or restart StandUp.',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  SpringButton(
                    onTap: onResume,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(appString(context, 'Resume')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
