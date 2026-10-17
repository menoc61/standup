import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/models/user_preferences.dart';
import 'package:standup_app/data/models/work_schedule.dart';
import 'package:standup_app/services/notification_service.dart';

void main() {
  group('WorkSchedule', () {
    final schedule = WorkSchedule();

    test('defaults to Monday through Friday, 09:00 to 17:00', () {
      expect(schedule.days, {1, 2, 3, 4, 5});
      expect(schedule.startMinute, 540);
      expect(schedule.endMinute, 1020);
      expect(schedule.isWorkingAt(DateTime(2026, 10, 12, 9)), isTrue);
      expect(schedule.isWorkingAt(DateTime(2026, 10, 12, 17)), isFalse);
      expect(schedule.isWorkingAt(DateTime(2026, 10, 10, 10)), isFalse);
    });

    test('schedule range is start-inclusive and end-exclusive', () {
      expect(schedule.isWorkingAt(DateTime(2026, 10, 12, 8, 59)), isFalse);
      expect(schedule.isWorkingAt(DateTime(2026, 10, 12, 9)), isTrue);
      expect(schedule.isWorkingAt(DateTime(2026, 10, 12, 16, 59)), isTrue);
      expect(schedule.isWorkingAt(DateTime(2026, 10, 12, 17)), isFalse);
    });

    test('only accepts action windows fully inside work hours', () {
      expect(
        schedule.allowsWindow(
          DateTime(2026, 10, 12, 9, 55),
          DateTime(2026, 10, 12, 10),
        ),
        isTrue,
      );
      expect(
        schedule.allowsWindow(
          DateTime(2026, 10, 12, 16, 55),
          DateTime(2026, 10, 12, 17),
        ),
        isTrue,
      );
      expect(
        schedule.allowsWindow(
          DateTime(2026, 10, 12, 16, 56),
          DateTime(2026, 10, 12, 17, 1),
        ),
        isFalse,
      );
      expect(
        schedule.allowsWindow(
          DateTime(2026, 10, 10, 9, 55),
          DateTime(2026, 10, 10, 10),
        ),
        isFalse,
      );
    });

    test('notification candidates skip weekends and close-time windows', () {
      final reminders = reminderTimesForSchedule(
        firstBoundary: DateTime(2026, 10, 16, 17), // Friday
        frequencyMinutes: 60,
        actionWindowMinutes: 5,
        schedule: schedule,
        now: DateTime(2026, 10, 16, 16),
        count: 3,
      );

      expect(reminders, [
        DateTime(2026, 10, 16, 16, 55),
        DateTime(2026, 10, 19, 9, 55),
        DateTime(2026, 10, 19, 10, 55),
      ]);
    });

    test('notification candidates also respect quiet hours', () {
      final reminders = reminderTimesForSchedule(
        firstBoundary: DateTime(2026, 10, 16, 17),
        frequencyMinutes: 60,
        actionWindowMinutes: 5,
        schedule: schedule,
        now: DateTime(2026, 10, 16, 16),
        quietHours: '16:00-17:00',
        count: 1,
      );

      expect(reminders, [DateTime(2026, 10, 19, 9, 55)]);
    });

    test('notification candidates stop at the daily cut-off', () {
      // The schedule is 09:00–17:00, so a six-hour cut-off ends the day at
      // 15:00: nothing after 14:55 may be queued, on any day.
      final reminders = reminderTimesForSchedule(
        firstBoundary: DateTime(2026, 10, 16, 15), // Friday
        frequencyMinutes: 60,
        actionWindowMinutes: 5,
        schedule: schedule,
        now: DateTime(2026, 10, 16, 14),
        count: 8,
        dailyLimitMinutes: 6 * 60,
      );

      expect(reminders.first, DateTime(2026, 10, 16, 14, 55));
      for (final reminder in reminders) {
        expect(
          reminder.isBefore(
            DateTime(reminder.year, reminder.month, reminder.day, 15),
          ),
          isTrue,
          reason:
              'a window starting at or after the cut-off was queued: $reminder',
        );
      }
      // The cut-off is not the end of the queue: the next work day resumes at
      // its own 09:55 and stops at its own 14:55.
      final monday = reminders.where(
        (r) => r.year == 2026 && r.month == 10 && r.day == 19,
      );
      expect(monday.first, DateTime(2026, 10, 19, 9, 55));
      expect(monday.last, DateTime(2026, 10, 19, 14, 55));
    });

    test('the cut-off is re-applied to every day in the queue', () {
      // The queue spans 90 days; a limit tested once against `now` would apply
      // to the first day and be forgotten after midnight. This asserts the
      // property on later days rather than on the first.
      final capped = reminderTimesForSchedule(
        firstBoundary: DateTime(2026, 10, 16, 17),
        frequencyMinutes: 60,
        actionWindowMinutes: 5,
        schedule: schedule,
        now: DateTime(2026, 10, 16, 16),
        count: 20,
        dailyLimitMinutes: 2 * 60,
      );
      final days = capped.map((r) => DateTime(r.year, r.month, r.day)).toSet();
      expect(
        days.length,
        greaterThanOrEqualTo(5),
        reason: 'the test has to reach several days to prove anything',
      );
      for (final reminder in capped) {
        expect(
          reminder.isBefore(
            DateTime(reminder.year, reminder.month, reminder.day, 11),
          ),
          isTrue,
          reason: 'a window past the cut-off was queued: $reminder',
        );
      }
      // Two windows a day, on every day: 09:55 and 10:55.
      expect(capped.length, 20);
      expect(
        capped.where((r) => r.hour == 10 && r.minute == 55).length,
        days.length,
      );
    });

    test('a cut-off as long as the work day changes nothing', () {
      // 8 hours on a 09:00–17:00 schedule is the schedule already saying it,
      // so the queue must be identical to one built with no limit at all.
      final withLimit = reminderTimesForSchedule(
        firstBoundary: DateTime(2026, 10, 16, 17),
        frequencyMinutes: 60,
        actionWindowMinutes: 5,
        schedule: schedule,
        now: DateTime(2026, 10, 16, 16),
        count: 10,
        dailyLimitMinutes: 8 * 60,
      );
      final withoutLimit = reminderTimesForSchedule(
        firstBoundary: DateTime(2026, 10, 16, 17),
        frequencyMinutes: 60,
        actionWindowMinutes: 5,
        schedule: schedule,
        now: DateTime(2026, 10, 16, 16),
        count: 10,
      );
      expect(withLimit, withoutLimit);
      expect(withLimit, isNotEmpty);
    });

    test('prelude times sit the configured lead time before each reminder', () {
      final reminders = [
        DateTime(2026, 10, 16, 16, 55),
        DateTime(2026, 10, 16, 17, 55),
      ];
      final preludes = preludeTimesForReminders(
        reminders: reminders,
        preludeMinutes: 5,
        now: DateTime(2026, 10, 16, 16),
      );

      expect(preludes, [
        DateTime(2026, 10, 16, 16, 50),
        DateTime(2026, 10, 16, 17, 50),
      ]);
    });

    test(
      'a prelude that would fire in the past is dropped, not fired late',
      () {
        // The next reminder is only two minutes away, so a five-minute warning
        // could only be delivered after the break had begun.
        final preludes = preludeTimesForReminders(
          reminders: [DateTime(2026, 10, 16, 16, 2)],
          preludeMinutes: 5,
          now: DateTime(2026, 10, 16, 16),
        );

        expect(preludes, isEmpty);
      },
    );

    test('a zero lead time disables the prelude queue entirely', () {
      expect(
        preludeTimesForReminders(
          reminders: [DateTime(2026, 10, 16, 17)],
          preludeMinutes: 0,
          now: DateTime(2026, 10, 16, 16),
        ),
        isEmpty,
      );
    });

    test('a prelude inside quiet hours is withheld like the in-app cue', () {
      // The reminder sits at the quiet window's edge, but its warning would fall
      // inside it. Silence must agree across the two channels.
      final preludes = preludeTimesForReminders(
        reminders: [DateTime(2026, 10, 16, 17)],
        preludeMinutes: 5,
        now: DateTime(2026, 10, 16, 15),
        quietHours: '16:00-17:00',
      );

      expect(preludes, isEmpty);
    });

    test('a prelude outside the work schedule is withheld', () {
      // The reminder lands inside the working day, but a five-minute warning
      // would fire before it started.
      final preludes = preludeTimesForReminders(
        reminders: [DateTime(2026, 10, 16, 9)],
        preludeMinutes: 5,
        now: DateTime(2026, 10, 16, 7),
        schedule: WorkSchedule(
          days: {1, 2, 3, 4, 5},
          startMinute: 9 * 60,
          endMinute: 17 * 60,
        ),
      );

      expect(preludes, isEmpty);
    });

    test('roundtrips the persisted weekday list', () {
      final custom = WorkSchedule(days: {1, 3, 5, 7});
      expect(WorkSchedule.fromStored(days: custom.storedDays), custom);
    });

    test('roundtrips schedule fields in preference JSON', () {
      final prefs = UserPreferences.defaultPreferences('local_test').copyWith(
        workDays: '2,4,6',
        workStartMinute: 8 * 60 + 30,
        workEndMinute: 16 * 60 + 15,
      );
      final restored = UserPreferences.fromJson(prefs.toJson());
      expect(
        restored.workSchedule,
        WorkSchedule(
          days: {2, 4, 6},
          startMinute: 8 * 60 + 30,
          endMinute: 16 * 60 + 15,
        ),
      );
    });

    test('rejects empty days and invalid time ranges', () {
      expect(() => WorkSchedule(days: {}), throwsArgumentError);
      expect(
        () => WorkSchedule(startMinute: 600, endMinute: 600),
        throwsArgumentError,
      );
      expect(() => WorkSchedule(startMinute: -1), throwsArgumentError);
      expect(() => WorkSchedule(endMinute: 24 * 60), throwsArgumentError);
    });
  });
}
