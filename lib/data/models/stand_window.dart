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
/// Every value is derived from the operating system rather than from anything
/// the app writes, so resetting app storage does not reset the guard.
class ClockIntegrityGuard {
  const ClockIntegrityGuard._();

  /// A jump larger than this in either direction suggests the wall clock was
  /// moved rather than time passing.
  static const int driftThresholdMinutes = 20;

  /// One such jump in this window is tolerated before the device is flagged.
  static const int toleratedDriftsPerHour = 2;

  /// Returns the number of monotonic violations observed since [previous].
  ///
  /// [previous] is the previously observed wall-clock reading. A violation is
  /// when the new reading is behind the old one, or jumps forward by more than
  /// [driftThresholdMinutes]. The caller owns the accumulator, which keeps this
  /// function pure and testable.
  static int countViolations({
    required DateTime previous,
    required DateTime now,
  }) {
    final delta = now.difference(previous);
    if (delta.isNegative) return 1;
    if (delta.inMinutes.abs() > driftThresholdMinutes) return 1;
    return 0;
  }

  /// Whether accumulated violations justify refusing to trust the reported
  /// totals for leaderboard purposes.
  static bool isUnreliable({
    required int violations,
    required DateTime windowStart,
    required DateTime now,
  }) {
    final windowHours = now.difference(windowStart).inHours.clamp(1, 24);
    final allowed = toleratedDriftsPerHour * windowHours;
    return violations > allowed;
  }
}
