/// A single actionable span inside [StandWindow].
class WindowSpan {
  final DateTime start;
  final DateTime end;

  const WindowSpan(this.start, this.end);

  /// Whether [now] falls inside the span, inclusive of the start and exclusive
  /// of the end so two adjacent windows never overlap.
  bool contains(DateTime now) => !now.isBefore(start) && now.isBefore(end);

  Duration get length => end.difference(start);

  @override
  String toString() => 'WindowSpan($start -> $end)';
}

/// The hourly stand-up window.
///
/// The product rule is that a movement break counts only inside the last
/// [actionWindowMinutes] minutes of an hour, measured against the device's
/// local wall clock. Everything here is pure and absolute-time based: no global
/// state, no `DateTime.now()` calls inside the calculations, so every rule can
/// be unit tested against injected timestamps.
///
/// Design notes:
/// * The window is [endMinute]:00-exclusive, e.g. the last 5 minutes of 10:00
///   is 09:55:00 (inclusive) through 10:00:00 (exclusive).
/// * The window wraps past midnight, so 23:58 is handled without a special case.
/// * The cadence selects how often a window opens (every hour by default), which
///   is why this is modelled as a window rather than a single instant.
class StandWindow {
  const StandWindow._();

  /// Default: a break may only be logged in the final 5 minutes of the hour.
  static const int defaultActionWindowMinutes = 5;

  /// Default spacing between windows: one per hour.
  static const int defaultCadenceMinutes = 60;

  /// The actionable window that contains [now], or null when [now] sits in the
  /// gap between windows.
  ///
  /// With a 60-minute cadence and a 5-minute window there is exactly one
  /// window per hour, opening at `HH:55` and closing at `HH:00`.
  static WindowSpan? activeWindow({
    required DateTime now,
    int actionWindowMinutes = defaultActionWindowMinutes,
    int cadenceMinutes = defaultCadenceMinutes,
  }) {
    _validate(actionWindowMinutes, cadenceMinutes);

    // The window closes on the next cadence boundary, and opens
    // `actionWindowMinutes` before it.
    final boundary = _boundaryAtOrAfter(now, cadenceMinutes);
    final start = boundary.subtract(Duration(minutes: actionWindowMinutes));
    final candidate = WindowSpan(start, boundary);
    return candidate.contains(now) ? candidate : null;
  }

  /// The next window that has not yet started, relative to [now].
  static WindowSpan? nextWindow({
    required DateTime now,
    int actionWindowMinutes = defaultActionWindowMinutes,
    int cadenceMinutes = defaultCadenceMinutes,
  }) {
    _validate(actionWindowMinutes, cadenceMinutes);

    // The window whose boundary is the next one up is either the current
    // (already open) window or the upcoming one.
    final boundary = _boundaryAtOrAfter(now, cadenceMinutes);
    final start = boundary.subtract(Duration(minutes: actionWindowMinutes));
    if (now.isBefore(start)) {
      return WindowSpan(start, boundary);
    }
    final nextBoundary = boundary.add(Duration(minutes: cadenceMinutes));
    return WindowSpan(
      nextBoundary.subtract(Duration(minutes: actionWindowMinutes)),
      nextBoundary,
    );
  }

  /// Time remaining until [now] leaves the active window. Zero when the window
  /// is not currently open, which lets the UI collapse to a "closed" state
  /// without a separate branch.
  static Duration remainingInWindow({
    required DateTime now,
    int actionWindowMinutes = defaultActionWindowMinutes,
    int cadenceMinutes = defaultCadenceMinutes,
  }) {
    final active = activeWindow(
      now: now,
      actionWindowMinutes: actionWindowMinutes,
      cadenceMinutes: cadenceMinutes,
    );
    if (active == null) return Duration.zero;
    final remaining = active.end.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Time until the next window opens. Zero when a window is already open.
  static Duration untilNextWindow({
    required DateTime now,
    int actionWindowMinutes = defaultActionWindowMinutes,
    int cadenceMinutes = defaultCadenceMinutes,
  }) {
    if (activeWindow(
          now: now,
          actionWindowMinutes: actionWindowMinutes,
          cadenceMinutes: cadenceMinutes,
        ) !=
        null) {
      return Duration.zero;
    }
    final next = nextWindow(
      now: now,
      actionWindowMinutes: actionWindowMinutes,
      cadenceMinutes: cadenceMinutes,
    );
    if (next == null) return Duration.zero;
    final remaining = next.start.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether a stand action taken at [now] should be honoured. This is the
  /// single authority used by the UI, the notification handlers and the local
  /// write path, so the three can never disagree.
  static bool isActionable({
    required DateTime now,
    int actionWindowMinutes = defaultActionWindowMinutes,
    int cadenceMinutes = defaultCadenceMinutes,
  }) =>
      activeWindow(
        now: now,
        actionWindowMinutes: actionWindowMinutes,
        cadenceMinutes: cadenceMinutes,
      ) !=
      null;

  /// Whole windows that closed between [from] and [to]. Used to detect missed
  /// breaks without trusting a client-supplied counter, so a tampered database
  /// cannot inflate or deflate the total.
  ///
  /// A window "closed" at its boundary instant, so the range is half-open:
  /// (from, to].
  static int windowsBetween({
    required DateTime from,
    required DateTime to,
    int cadenceMinutes = defaultCadenceMinutes,
  }) {
    _validate(defaultActionWindowMinutes, cadenceMinutes);
    if (!to.isAfter(from)) return 0;

    var cursor = _boundaryAtOrAfter(from, cadenceMinutes);
    // The range is half-open, (from, to]. A boundary landing exactly on `from`
    // closed before the window of interest began, so it must not be counted.
    if (cursor == from) {
      cursor = cursor.add(Duration(minutes: cadenceMinutes));
    }

    var count = 0;
    while (!cursor.isAfter(to)) {
      count++;
      cursor = cursor.add(Duration(minutes: cadenceMinutes));
    }
    return count;
  }

  /// The first cadence-aligned boundary at or after [now].
  ///
  /// Boundaries are aligned to the local clock, so every device produces stable
  /// "top of the hour" anchors without shipping a timezone database.
  static DateTime _boundaryAtOrAfter(DateTime now, int cadenceMinutes) {
    final hourStart = DateTime(now.year, now.month, now.day, now.hour);
    final minutesIntoHour = now.minute;

    // Round up to the next cadence step. Using ceil keeps an exact boundary
    // (minute == 0) on itself rather than pushing it to the following step.
    final steps = minutesIntoHour == 0
        ? 0
        : (minutesIntoHour + cadenceMinutes - 1) ~/ cadenceMinutes;
    return hourStart.add(Duration(minutes: steps * cadenceMinutes));
  }

  static void _validate(int actionWindowMinutes, int cadenceMinutes) {
    if (actionWindowMinutes <= 0) {
      throw ArgumentError.value(
        actionWindowMinutes,
        'actionWindowMinutes',
        'must be positive',
      );
    }
    if (cadenceMinutes <= 0) {
      throw ArgumentError.value(
        cadenceMinutes,
        'cadenceMinutes',
        'must be positive',
      );
    }
    if (actionWindowMinutes > cadenceMinutes) {
      throw ArgumentError('actionWindowMinutes cannot exceed cadenceMinutes');
    }
  }
}

/// Guards against trivial ways of faking participation.
///
/// A local-first wellness app cannot be made tamper-proof: the SQLite file lives
/// on the user's own device and can be edited, and the device clock can be
/// changed. What *is* achievable, and what these checks do, is to stop the
/// cheap, accidental forms of drift and to make suspicious data visible to the
/// server instead of silently trusted.
///
/// The check compares the wall clock against a **monotonic** stopwatch. That
/// distinction matters: a plain "did the wall clock go backwards" test reports a
/// violation every single time the OS suspends the app, so an ordinary night of
/// sleep would eventually get a diligent user flagged and excluded from the
/// leaderboard. A monotonic reference does not advance while suspended, so
/// sleep is correctly classified as legitimate rather than as tampering.
class ClockIntegrityGuard {
  const ClockIntegrityGuard._();

  /// A divergence between wall-clock and monotonic time larger than this is a
  /// violation. Anything smaller is ordinary timer imprecision.
  static const Duration driftThreshold = Duration(seconds: 90);

  /// Consecutive violations before the device is distrusted.
  static const int tolerance = 3;

  /// A monotonic interval shorter than this means the process was effectively
  /// frozen, i.e. suspended. The UI ticker runs at 1 Hz, so a live interval is
  /// close to one second; anything well under that is a genuine suspend rather
  /// than normal jitter.
  static const Duration suspendThreshold = Duration(milliseconds: 500);

  /// Classifies the transition between two observations.
  ///
  /// Returns [ClockVerdict.violation] when the wall clock was moved,
  /// [ClockVerdict.reset] when the app was suspended (monotonic time also barely
  /// advanced), and [ClockVerdict.ok] when the two clocks agree.
  static ClockVerdict classify({
    required Duration wallDelta,
    required Duration monotonicDelta,
  }) {
    if (wallDelta.isNegative) return ClockVerdict.violation;

    // A monotonic clock that did not advance means the process was suspended.
    // The wall clock jumping forward over that gap is normal sleep, not
    // tampering, so it must not count against the user.
    if (monotonicDelta.abs() < suspendThreshold) return ClockVerdict.reset;

    final divergence = (wallDelta - monotonicDelta).inSeconds.abs();
    if (divergence > driftThreshold.inSeconds) return ClockVerdict.violation;
    return ClockVerdict.ok;
  }
}

/// Outcome of a single clock observation.
enum ClockVerdict {
  /// The wall clock moved independently of real elapsed time.
  violation,

  /// Time passed normally.
  ok,

  /// The app was suspended; the gap is not user error.
  reset,
}

/// Tracks the running clock-integrity tally for a single device.
///
/// Clean readings decay the streak so a single accident does not permanently
/// penalise the user; a suspend/resume clears it outright.
class ClockIntegrityTracker {
  DateTime? _lastWall;
  int _streak = 0;

  int get streak => _streak;

  /// True once enough consecutive violations have been observed.
  bool get isDistrusted => _streak >= ClockIntegrityGuard.tolerance;

  /// Records a new observation and returns the running violation streak.
  ///
  /// The very first observation only establishes the reference point. There is
  /// nothing to compare it against, so it cannot be a violation and must not
  /// count towards the tolerance.
  int observe({required DateTime wallNow, required Duration monotonicDelta}) {
    final previous = _lastWall;
    _lastWall = wallNow;
    if (previous == null) return _streak;

    final verdict = ClockIntegrityGuard.classify(
      wallDelta: wallNow.difference(previous),
      monotonicDelta: monotonicDelta,
    );
    switch (verdict) {
      case ClockVerdict.violation:
        _streak++;
      case ClockVerdict.ok:
        if (_streak > 0) _streak--;
      case ClockVerdict.reset:
        _streak = 0;
    }
    return _streak;
  }
}
