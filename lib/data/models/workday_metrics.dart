import 'daily_analytics.dart';

/// Shared calculations for a standard eight-hour workday.
///
/// A completed reminder represents a five-minute movement break. The target
/// scales with the selected reminder cadence and is capped by the workday
/// length, so a slower cadence does not claim more breaks than fit in a day.
class WorkdayMetrics {
  static const int workdayMinutes = 8 * 60;
  static const int standBreakMinutes = 5;

  const WorkdayMetrics._();

  static int standTargetMinutes(int cadenceMinutes) {
    if (cadenceMinutes <= 0) return 0;
    final breaks = workdayMinutes ~/ cadenceMinutes;
    return breaks * standBreakMinutes;
  }

  static double averageStandMinutesPerActiveDay(Iterable<DailyAnalytics> days) {
    final activeDays = days.where((day) => day.remindersSent > 0).toList();
    if (activeDays.isEmpty) return 0;
    final minutes = activeDays.fold<int>(
      0,
      (total, day) => total + day.totalStandTime,
    );
    return minutes / activeDays.length;
  }

  static double targetProgress(int standMinutes, int targetMinutes) {
    if (targetMinutes <= 0) return 0;
    return (standMinutes / targetMinutes).clamp(0.0, 1.0);
  }

  static int currentStreak(Iterable<DailyAnalytics> days, DateTime now) {
    final completedDates = days
        .where((day) => day.remindersCompleted > 0)
        .map((day) => day.date)
        .toSet();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!completedDates.contains(dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (completedDates.contains(dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Formats [date] as the `yyyy-MM-dd` key used by `AnalyticsDailyTable.date`.
  ///
  /// ## Why this is not `DateFormat('yyyy-MM-dd')`
  ///
  /// Three call sites had grown their own copy of this: one using `intl`, two
  /// doing manual `padLeft`. A locale-aware formatter can emit a different
  /// separator or calendar under some configurations, which would silently stop
  /// matching rows already stored — a streak would go to zero and a heatmap would
  /// blank, with no error anywhere.
  ///
  /// The format is part of the storage contract, so it is derived arithmetically
  /// and never from a locale.
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Time calculations use absolute timestamps so a paused/suspended app can
/// catch up correctly when it resumes.
class ReminderClock {
  const ReminderClock._();

  static Duration remaining(DateTime now, DateTime dueAt) {
    final difference = dueAt.difference(now);
    return difference.isNegative ? Duration.zero : difference;
  }

  static double progress({
    required DateTime now,
    required DateTime startedAt,
    required DateTime dueAt,
  }) {
    final totalSeconds = dueAt.difference(startedAt).inSeconds;
    if (totalSeconds <= 0) return 1;
    final elapsedSeconds = now.difference(startedAt).inSeconds;
    return (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
  }
}
