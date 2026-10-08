import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/models/daily_analytics.dart';
import 'package:standup_app/data/models/workday_metrics.dart';

void main() {
  group('WorkdayMetrics', () {
    test('calculates the standing target within an eight-hour day', () {
      expect(WorkdayMetrics.standTargetMinutes(60), 40);
      expect(WorkdayMetrics.standTargetMinutes(30), 80);
      expect(WorkdayMetrics.standTargetMinutes(90), 25);
      expect(WorkdayMetrics.standTargetMinutes(0), 0);
    });

    test('averages only days with recorded reminder activity', () {
      final days = [
        _day('2026-10-07', sent: 8, standMinutes: 40),
        _day('2026-10-06', sent: 8, standMinutes: 20),
        _day('2026-10-05', sent: 0, standMinutes: 0),
      ];

      expect(WorkdayMetrics.averageStandMinutesPerActiveDay(days), 30);
      expect(WorkdayMetrics.averageStandMinutesPerActiveDay(const []), 0);
    });

    test('caps target progress and calculates an actual completion streak', () {
      expect(WorkdayMetrics.targetProgress(20, 40), 0.5);
      expect(WorkdayMetrics.targetProgress(50, 40), 1.0);
      expect(WorkdayMetrics.targetProgress(0, 0), 0);
      expect(
        WorkdayMetrics.currentStreak([
          _day('2026-10-07', sent: 8, completed: 1),
          _day('2026-10-06', sent: 8, completed: 1),
          _day('2026-10-04', sent: 8, completed: 1),
        ], DateTime(2026, 10, 7)),
        2,
      );
    });
  });

  group('ReminderClock', () {
    final start = DateTime(2026, 10, 7, 9);
    final due = DateTime(2026, 10, 7, 10);

    test('counts down by absolute time and stays at zero after due time', () {
      expect(
        ReminderClock.remaining(DateTime(2026, 10, 7, 9, 30), due),
        const Duration(minutes: 30),
      );
      expect(
        ReminderClock.remaining(DateTime(2026, 10, 7, 10, 1), due),
        Duration.zero,
      );
    });

    test('progress catches up after suspension and remains bounded', () {
      expect(
        ReminderClock.progress(
          now: DateTime(2026, 10, 7, 9, 15),
          startedAt: start,
          dueAt: due,
        ),
        0.25,
      );
      expect(
        ReminderClock.progress(
          now: DateTime(2026, 10, 7, 10, 10),
          startedAt: start,
          dueAt: due,
        ),
        1,
      );
    });
  });
}

DailyAnalytics _day(
  String date, {
  int sent = 0,
  int completed = 0,
  int standMinutes = 0,
}) => DailyAnalytics(
  id: date,
  userId: 'test-user',
  date: date,
  remindersSent: sent,
  remindersCompleted: completed,
  totalStandTime: standMinutes,
);
