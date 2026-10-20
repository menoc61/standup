/// Counts break windows the user let close without acting.
///
/// ## Why this is its own object
///
/// Workrave escalates: once you have ignored a configurable number of prompts,
/// the reminder stops being a reminder and becomes a break you are held to.
/// Reproducing that here needs exactly one number — how many windows in a row
/// closed with nothing recorded — and that number is the only part of the feature
/// that can be wrong. So it lives in a pure object with its own tests, in the
/// same spirit as [ActiveTimeTracker], rather than inside the 1 Hz ticker where
/// it could only be observed through the UI.
///
/// ## What counts, and what deliberately does not
///
/// A window increments the count only when all three hold:
///
/// * it closed with **no recorded action** — a completion, a snooze and a skip
///   all reset the count to zero, because the user responded;
/// * the user was **never away** while it was open. Absence is not ignoring. A
///   window that opened over an empty desk is the exact case the presence work
///   exists to protect, and charging it would punish somebody for stepping away,
///   which is the behaviour the app is trying to encourage;
/// * the platform **can read idle time**, so "away" is a question that can be
///   answered at all. Where it cannot (mobile today), nothing is counted and
///   escalation stays inert rather than guessing.
///
/// A window that expires while the user is away is therefore neutral: it neither
/// increments nor resets. Walking away mid-streak keeps the streak, which is the
/// honest reading — no prompt was ignored.
class IgnoredPromptTracker {
  int _streak = 0;
  int? _openWindowKey;
  bool _sawAway = false;

  /// How many windows in a row have closed with no recorded response.
  int get ignoredStreak => _streak;

  /// The window this tracker currently believes is open, or null between windows.
  int? get openWindowKey => _openWindowKey;

  /// Whether the window now open has seen the user away at least once.
  bool get sawAwayThisWindow => _sawAway;

  /// Feeds one tick.
  ///
  /// [windowKey] is the identity of the window that is open right now (its closing
  /// instant), or null when none is. A change of key is what marks the previous
  /// window as closed, so this must be called on every tick even when nothing
  /// appears to change — that is how the close is noticed at all.
  ///
  /// [wasActed] answers whether the *closed* window already has a recorded
  /// action. It is injected rather than read here because the record lives in
  /// `AppState._actedWindows` and in the database, and this object should not
  /// know about either.
  void observe({
    required int? windowKey,
    required bool away,
    required bool presenceAvailable,
    required bool Function(int windowKey) wasActed,
  }) {
    if (windowKey != _openWindowKey) {
      final closed = _openWindowKey;
      if (closed != null) {
        if (wasActed(closed)) {
          _streak = 0;
        } else if (!_sawAway && presenceAvailable) {
          _streak++;
        }
      }
      _openWindowKey = windowKey;
      _sawAway = false;
    }
    if (windowKey != null && away) _sawAway = true;
  }

  /// Records that the user acted, dropping the count at once.
  ///
  /// Called the moment an action is recorded rather than waiting for the window
  /// to close, so the break screen a streak raised gets out of the way on the
  /// same tap that satisfies it.
  void acted() {
    _streak = 0;
    _sawAway = false;
  }

  /// Forgets everything, judging nothing. Used when the day rolls over, where a
  /// streak that began yesterday should not hold today's screen.
  void reset() {
    _streak = 0;
    _openWindowKey = null;
    _sawAway = false;
  }

  /// Whether a streak long enough to escalate has built up.
  ///
  /// [limit] is the configured number of ignored breaks, where zero means the
  /// feature is off — so a zero limit can never escalate, whatever the streak.
  bool isDue(int limit) => limit > 0 && _streak >= limit;
}
