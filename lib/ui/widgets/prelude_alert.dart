import 'package:flutter/material.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

/// The non-blocking "get ready to stop" banner that signals an imminent break.
///
/// ## Why a banner and not a dialog
///
/// The prelude is a *warning*, not the break itself: the user still has minutes
/// of work to finish, so stealing focus with a modal dialog would interrupt the
/// very thing the warning exists to protect. The banner therefore floats over
/// whatever screen is showing, never traps input, and can be dismissed — and
/// only the actual break window is allowed to take the screen.
///
/// It is mounted from `MaterialApp.builder` so it covers onboarding, home and
/// every route alike without each screen having to remember to include it.
class PreludeAlert extends StatefulWidget {
  final AppState appState;

  /// Whether the alert may currently show. False during splash and onboarding,
  /// where a "your break is in four minutes" card is meaningless.
  final bool active;

  /// The decorated app, painted underneath the banner.
  final Widget child;

  const PreludeAlert({
    super.key,
    required this.appState,
    required this.active,
    required this.child,
  });

  @override
  State<PreludeAlert> createState() => _PreludeAlertState();
}

class _PreludeAlertState extends State<PreludeAlert> {
  /// The break instant (the end of the prelude) the user dismissed, so the
  /// banner stays closed for this window and reappears for the next one.
  int? _dismissedWindowKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        // The ticker notifies once a second while the prelude is open, so the
        // countdown below updates without any timer of its own.
        final prelude = widget.active ? widget.appState.preludeWindow : null;
        final dismissed =
            prelude != null &&
            prelude.end.millisecondsSinceEpoch == _dismissedWindowKey;

        return Stack(
          children: [
            widget.child,
            if (prelude != null && !dismissed)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: PreludeBanner(
                      breakAt: prelude.end,
                      onDismiss: () => setState(
                        () => _dismissedWindowKey =
                            prelude.end.millisecondsSinceEpoch,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The banner itself: pure presentation, so it can be tested without an
/// `AppState`. [breakAt] is the instant the break begins.
class PreludeBanner extends StatelessWidget {
  final DateTime breakAt;
  final VoidCallback onDismiss;

  /// Injected for tests; defaults to the platform's reduced-motion setting.
  final bool? reduceMotionOverride;

  const PreludeBanner({
    super.key,
    required this.breakAt,
    required this.onDismiss,
    this.reduceMotionOverride,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion =
        reduceMotionOverride ?? MediaQuery.disableAnimationsOf(context);
    final remaining = breakAt.difference(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: TweenAnimationBuilder<double>(
          // Keying the animation to the break instant replays the slide-in for
          // each new window rather than reusing the first frame's state.
          key: ValueKey(breakAt.millisecondsSinceEpoch),
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
                      color: scheme.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: scheme.primary,
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
                            appStringArgs(context, 'Break in {time}', {
                              'time': formatClock(remaining),
                            }),
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
                            'Wrap up what you are doing and get ready to stand.',
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
                    onTap: onDismiss,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(appString(context, 'Got it')),
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
