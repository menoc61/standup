import 'package:standup_app/core/app_cadence.dart';

/// Whether the person is at the machine.
///
/// The distinction exists so the app does not nag an empty chair: a reminder
/// that arrives while nobody is at the desk should not chime, and (once the
/// forced break lands) it must never seize the screen of someone who stepped
/// away.
enum Presence {
  /// Input has been seen recently enough that someone is almost certainly here.
  present,

  /// No input for at least the away threshold.
  away,
}

/// Classifies presence from the operating system's "seconds since last input".
///
/// ## Why this is pure
///
/// The only thing the platform provides is a number: how long the mouse and
/// keyboard have been untouched. Everything that turns that number into a
/// decision — the threshold, the hysteresis around it, "when exactly did they
/// leave", surviving a clock change — is logic, and logic that cannot be tested
/// is logic that is wrong. So the reading is injected and the classification is
/// a pure function of it.
///
/// ## Deliberate non-features
///
/// There is no "idle but not away" middle state and no smoothing window. A
/// threshold plus a single state flip is enough for the two decisions the app
/// actually makes (chime or stay silent; block or wait), and every extra tier is
/// another way for the widget and the timer to disagree.
class ActiveTimeTracker {
  /// How long without input counts as away.
  final Duration awayThreshold;

  Presence _presence = Presence.present;
  DateTime? _awaySince;

  ActiveTimeTracker({
    this.awayThreshold = const Duration(
      minutes: AppCadence.defaultAwayThresholdMinutes,
    ),
  });

  Presence get presence => _presence;

  bool get isAway => _presence == Presence.away;

  /// When the absence began, or null while present.
  ///
  /// This is the moment the *input* stopped, not the moment the threshold was
  /// crossed, so a log that says "away from 14:03" agrees with the OS reading
  /// rather than lagging it by the threshold.
  DateTime? get awaySince => _awaySince;

  /// How long the user has been away as of [now], or [Duration.zero].
  ///
  /// Clamped at zero: a wall clock that jumped backwards must not produce a
  /// negative absence, which would render as a nonsensical duration.
  Duration awayDuration(DateTime now) {
    final since = _awaySince;
    if (since == null) return Duration.zero;
    final elapsed = now.difference(since);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// Feeds one OS reading and returns the resulting presence.
  ///
  /// [idle] is the time since the last mouse or keyboard input. A `null` reading
  /// means the platform could not answer — the caller should pass it through
  /// rather than guessing, and the previous state is kept so a transient failure
  /// does not flip a genuinely-away user back to present.
  Presence observe({required Duration? idle, required DateTime now}) {
    if (idle == null) return _presence;

    final nowAway = idle >= awayThreshold;
    if (nowAway && _presence != Presence.away) {
      _presence = Presence.away;
      // The absence started when input stopped, so back-date by the idle time
      // rather than recording "now". A backwards clock jump is clamped so the
      // derived start never lands in the future.
      final startedAt = now.subtract(idle);
      _awaySince = startedAt.isAfter(now) ? now : startedAt;
    } else if (!nowAway && _presence == Presence.away) {
      _presence = Presence.present;
      _awaySince = null;
    }
    return _presence;
  }

  /// Forces the tracker back to a known state.
  ///
  /// Used on resume, where the OS reading is the only trustworthy source, and in
  /// tests.
  void reset({Presence to = Presence.present}) {
    _presence = to;
    _awaySince = null;
  }
}
