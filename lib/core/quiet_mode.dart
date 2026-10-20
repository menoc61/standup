/// A pause on interruptions that can end by itself.
///
/// ## Why a value object and not a boolean
///
/// Quiet mode used to be one flag, and the flag was the whole design: quiet
/// until the user resumes. Workrave's *Temporarily Quiet…* adds the second
/// shape — quiet for thirty minutes, for an hour, or until tomorrow — and those
/// two shapes have to agree about the same three questions: is the pause still
/// running, how long is left, and what does "until tomorrow" actually mean.
///
/// Those answers are arithmetic on the device's own clock, which is the part of
/// this that can be wrong, so it lives here with its own tests rather than inside
/// the 1 Hz ticker. Nothing here is persisted: [AppState] keeps the pause in
/// memory on purpose, because a quiet mode that survived a restart is a silent
/// failure the user cannot see (see the field's own comment).
class QuietPeriod {
  /// The instant the pause ends, or null when only the user can end it.
  final DateTime? until;

  /// A pause that runs until the user resumes.
  const QuietPeriod.indefinite() : until = null;

  /// A pause that ends at [until].
  const QuietPeriod.until(this.until);

  /// Whether an indefinite pause, or at least one that has not run out.
  bool isActiveAt(DateTime now) {
    final end = until;
    return end == null || now.isBefore(end);
  }

  /// Time left on a timed pause, or null while the pause is indefinite.
  ///
  /// Clamped at zero rather than going negative: the caller is a countdown, and
  /// a countdown that briefly renders `-0:01` in the second before the ticker
  /// clears it looks broken rather than wrong.
  Duration? remainingAt(DateTime now) {
    final end = until;
    if (end == null) return null;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// The start of the next local day after [now].
  ///
  /// Built with an overflowing day-of-month rather than `add(const Duration(days:
  /// 1))`, which adds twenty-four hours of wall time: on a spring-forward night
  /// that lands at 01:00 and on an autumn night at 23:00, so "until tomorrow"
  /// would end an hour early or an hour late exactly when the clocks move. Asking
  /// `DateTime` for day `n + 1` at midnight lets it apply the same offset rule it
  /// uses for every other local date.
  static DateTime nextLocalMidnight(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1);
}
