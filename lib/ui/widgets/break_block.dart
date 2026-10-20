import 'dart:async';

import 'package:flutter/material.dart';
import 'package:standup_app/core/app_cadence.dart';
import 'package:standup_app/core/app_spacing.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/core/break_block.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/ui/widgets/guided_stretch.dart';
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
///
/// ## Why the guided routine lives inside the cover
///
/// The one moment a guided stretch is unambiguously the right action is the
/// forced break, and the cover cannot push it: this widget sits *above* the
/// navigator, so pushing would put the routine *underneath* the barrier that is
/// supposed to show it. Nesting it inside the cover keeps the action visible.
class BreakBlockOverlay extends StatefulWidget {
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
  State<BreakBlockOverlay> createState() => _BreakBlockOverlayState();
}

class _BreakBlockOverlayState extends State<BreakBlockOverlay> {
  /// Whether *this* cover session asked for the guided routine. Deliberately not
  /// derived from `isBreakActive`: a stretch started from the dashboard bell is
  /// already on screen with its own sheet, and taking over the cover for it
  /// would show the same routine twice.
  bool _stretchRequested = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        // The window end is read from the app state on every tick, so the
        // countdown below stays in step with the timer that decides when the
        // block lifts.
        final window = widget.appState.activeWindow;
        final view = breakBlockView(
          active: widget.active,
          windowOpen: window != null,
          coverEligible: widget.appState.isBreakBlockActive,
          coverRequestedStretch: _stretchRequested,
          breakInProgress: widget.appState.isBreakActive,
        );

        return Stack(
          children: [
            widget.child,
            if (view != BreakBlockView.none) ...[
              // Swallows taps, drags and scrolls aimed at the app underneath.
              const ModalBarrier(dismissible: false, color: Colors.black54),
              Positioned.fill(
                child: view == BreakBlockView.guidedStretch
                    ? _EmbeddedStretch(
                        appState: widget.appState,
                        onClose: () =>
                            setState(() => _stretchRequested = false),
                      )
                    : BreakBlockScreen(
                        endsAt: window!.end,
                        standing: widget.appState.isBreakActive,
                        minWaitSeconds: BreakBlockScreen.defaultMinWaitSeconds,
                        // The label must describe the routine this tap would
                        // actually start, so it reads the *open* window: outside
                        // a window `startGuidedStretch` runs the standard routine
                        // whichever break happens to be next.
                        stretchMinutes: widget.appState.isCurrentWindowLongBreak
                            ? widget.appState.longBreakMinutes
                            : AppCadence.guidedStretchMinutes,
                        onStoodUp: () => widget.appState.completeReminder(),
                        onStartStretch: () {
                          setState(() => _stretchRequested = true);
                          widget.appState.startGuidedStretch();
                        },
                      ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The guided routine as a centred card, so it is legible over the dimmed app
/// rather than being bare text on a translucent barrier.
class _EmbeddedStretch extends StatelessWidget {
  final AppState appState;
  final VoidCallback onClose;

  const _EmbeddedStretch({required this.appState, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                margin: const EdgeInsets.all(AppSpace.section),
                padding: const EdgeInsets.all(AppSpace.section),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: GuidedStretchPanel(
                  appState: appState,
                  // The cover already started it; starting it again here would
                  // reset a routine that is a second old.
                  autoStart: false,
                  onClose: onClose,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The cover itself: pure presentation, with an optional anti-cheat timer.
///
/// [endsAt] is the instant the break window closes, which is also the moment the
/// cover lifts on its own. There is intentionally no dismiss button: the two
/// honest ways out are standing up (which logs the break) and the window simply
/// ending, and a third escape hatch would turn the block into a suggestion.
///
/// [minWaitSeconds] enforces a mandatory anti-cheat delay (e.g. 30 seconds)
/// before the user is allowed to confirm "I stood up", ensuring real physical
/// movement rather than an instant dismissal.
class BreakBlockScreen extends StatefulWidget {
  /// The delay the forced break uses before it accepts a confirmation.
  ///
  /// Deliberately short: it exists to stop a reflexive two-second dismissal,
  /// not to hold anyone hostage. A later setting can make it configurable.
  static const int defaultMinWaitSeconds = 30;

  final DateTime endsAt;

  /// True while the completion is being written, so the button cannot be
  /// double-tapped into two records.
  final bool standing;

  final VoidCallback onStoodUp;

  /// Optional: offers the guided routine instead of a plain stand. Null keeps
  /// the cover to its single authoritative action, which is what the widget
  /// tests render.
  final VoidCallback? onStartStretch;

  /// How long the routine this cover offers runs, in minutes.
  ///
  /// The label has to state it, because a long-break window offers a longer
  /// routine and a button promising five minutes on a ten-minute break is wrong
  /// exactly where the user is about to spend the time. Defaults to the standard
  /// routine, so a caller that does not know keeps the old copy.
  final int stretchMinutes;

  /// Anti-cheat delay in seconds before the confirmation button unlocks.
  final int minWaitSeconds;

  const BreakBlockScreen({
    super.key,
    required this.endsAt,
    required this.onStoodUp,
    this.standing = false,
    this.onStartStretch,
    this.stretchMinutes = AppCadence.guidedStretchMinutes,
    this.minWaitSeconds = 0,
  });

  @override
  State<BreakBlockScreen> createState() => _BreakBlockScreenState();
}

class _BreakBlockScreenState extends State<BreakBlockScreen> {
  Timer? _ticker;
  int _secondsElapsed = 0;
  late final int _requiredSeconds;

  @override
  void initState() {
    super.initState();
    // The cover disappears when the window closes, so waiting longer than the
    // window would show an unlock countdown that can never be acted on. A user
    // who arrives in the last ten seconds of the window gets those ten seconds,
    // not a thirty-second wait followed by the cover vanishing.
    final windowSeconds = widget.endsAt.difference(DateTime.now()).inSeconds;
    _requiredSeconds = windowSeconds <= 0
        ? 0
        : (windowSeconds < widget.minWaitSeconds
              ? windowSeconds
              : widget.minWaitSeconds);
    if (_requiredSeconds > 0) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _secondsElapsed++;
          if (_secondsElapsed >= _requiredSeconds) {
            _ticker?.cancel();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _unlockable => _secondsElapsed >= _requiredSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = widget.endsAt.difference(DateTime.now());
    // A window that has already closed shows zero rather than a negative time.
    final clock = formatClock(remaining.isNegative ? Duration.zero : remaining);
    final canStand = !widget.standing && _unlockable;
    final delayRemaining = (_requiredSeconds - _secondsElapsed).clamp(
      0,
      _requiredSeconds,
    );

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
                    if (!_unlockable) ...[
                      Text(
                        appStringArgs(
                          context,
                          'Please step away from your desk ({seconds}s)',
                          {'seconds': '$delayRemaining'},
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SpringButton(
                      onTap: canStand ? widget.onStoodUp : null,
                      backgroundColor: canStand
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      foregroundColor: canStand
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      child: Text(appString(context, 'I stood up')),
                    ),
                    if (widget.onStartStretch != null) ...[
                      const SizedBox(height: 12),
                      // Secondary on purpose: standing up is the action that
                      // counts, and the routine is a longer way of doing the
                      // same thing rather than an alternative to it.
                      SpringButton(
                        onTap: widget.standing ? null : widget.onStartStretch,
                        backgroundColor: scheme.primary.withValues(alpha: 0.12),
                        foregroundColor: scheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Text(
                          appStringArgs(
                            context,
                            'Guided {minutes}-minute stretch',
                            {'minutes': '${widget.stretchMinutes}'},
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
    );
  }
}
