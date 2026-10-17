/// The local work schedule used to decide when StandUp can remind or log a
/// break. Weekdays use DateTime's convention: Monday = 1, Sunday = 7.
class WorkSchedule {
  static const defaultDays = <int>{1, 2, 3, 4, 5};
  static const defaultStartMinute = 9 * 60;
  static const defaultEndMinute = 17 * 60;

  final Set<int> days;
  final int startMinute;
  final int endMinute;

  WorkSchedule({
    Iterable<int> days = defaultDays,
    this.startMinute = defaultStartMinute,
    this.endMinute = defaultEndMinute,
  }) : days = Set.unmodifiable(days.where((day) => day >= 1 && day <= 7)) {
    if (this.days.isEmpty) {
      throw ArgumentError('At least one workday is required.');
    }
    if (startMinute < 0 || endMinute >= 24 * 60 || startMinute >= endMinute) {
      throw ArgumentError('Work hours must be a valid same-day time range.');
    }
  }

  factory WorkSchedule.fromStored({
    String? days,
    int? startMinute,
    int? endMinute,
  }) {
    final parsedDays = days
        ?.split(',')
        .map(int.tryParse)
        .whereType<int>()
        .where((day) => day >= 1 && day <= 7)
        .toSet();
    try {
      return WorkSchedule(
        days: parsedDays == null || parsedDays.isEmpty
            ? defaultDays
            : parsedDays,
        startMinute: startMinute ?? defaultStartMinute,
        endMinute: endMinute ?? defaultEndMinute,
      );
    } on ArgumentError {
      return WorkSchedule(
        days: parsedDays == null || parsedDays.isEmpty
            ? defaultDays
            : parsedDays,
      );
    }
  }

  String get storedDays => (days.toList()..sort()).join(',');

  bool isWorkingAt(DateTime when) {
    if (!days.contains(when.weekday)) return false;
    final minute = when.hour * 60 + when.minute;
    return minute >= startMinute && minute < endMinute;
  }

  /// A cadence window can be used only when its whole actionable span falls
  /// within a scheduled workday. This avoids windows that start before opening
  /// or remain actionable after the configured closing time.
  bool allowsWindow(DateTime start, DateTime end) {
    if (!days.contains(start.weekday) ||
        start.year != end.year ||
        start.month != end.month ||
        start.day != end.day) {
      return false;
    }
    final beginMinute = start.hour * 60 + start.minute;
    final finishMinute = end.hour * 60 + end.minute;
    return beginMinute >= startMinute && finishMinute <= endMinute;
  }

  /// Minutes this schedule spans in a single day.
  int get lengthMinutes => endMinute - startMinute;

  /// The instant on [when]'s local day after which StandUp stops offering
  /// breaks, or `null` when no cut-off applies.
  ///
  /// ## What this measures, and what it deliberately does not
  ///
  /// This is the **scheduled** day's length, not accumulated desk time. Workrave
  /// counts the real minutes you worked and forces a rest once you pass the
  /// limit; doing that here would mean continuously tracking desk occupancy,
  /// reading it back after a crash, and reconciling it across clock changes and
  /// suspend — and the app would then fire an interruption the employee cannot
  /// predict from any setting they chose. The cut-off is expressed instead as
  /// "N hours after your work day starts", which the user can compute from their
  /// own schedule, which is stable across days, and which cannot be wrong about
  /// how long they were actually at the desk.
  ///
  /// Returns `null` — no cut-off — for a non-positive limit, and for a limit at
  /// least as long as the schedule itself. The second case matters: an 8-hour
  /// limit on an 8-hour day is not a feature that failed to work, it is the
  /// schedule already saying the same thing, and returning an instant there
  /// would put a cut-off line where no window could exist anyway.
  DateTime? dailyLimitInstant({
    required DateTime when,
    required int limitMinutes,
  }) {
    if (limitMinutes <= 0 || limitMinutes >= lengthMinutes) return null;
    final midnight = DateTime(when.year, when.month, when.day);
    return midnight.add(Duration(minutes: startMinute + limitMinutes));
  }

  /// Whether a window starting at [windowStart] falls past the daily cut-off.
  ///
  /// The comparison uses the window's **start**, so a window that opened before
  /// the limit stays actionable for its whole length. Cutting it mid-window
  /// would revoke a break the app had already offered, which is the one thing a
  /// limit must not do: the rule exists to end the day, not to snatch an
  /// invitation back.
  bool isPastDailyLimit({
    required DateTime windowStart,
    required int limitMinutes,
  }) {
    final limit = dailyLimitInstant(
      when: windowStart,
      limitMinutes: limitMinutes,
    );
    return limit != null && !windowStart.isBefore(limit);
  }

  @override
  bool operator ==(Object other) =>
      other is WorkSchedule &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      _sameDays(other.days);

  bool _sameDays(Set<int> other) =>
      days.length == other.length && days.containsAll(other);

  @override
  int get hashCode => Object.hash(
    startMinute,
    endMinute,
    Object.hashAll(days.toList()..sort()),
  );
}
