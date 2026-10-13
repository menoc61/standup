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
