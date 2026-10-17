import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/models/work_schedule.dart';

/// The daily cut-off decides when the app stops interrupting, so the cases that
/// matter are the ones where a wrong answer is invisible: a limit longer than the
/// work day (where nothing should happen at all), the boundary instant itself,
/// and a window that straddles the cut-off.
void main() {
  // 09:00–17:00, Monday to Friday: an eight-hour day.
  final schedule = WorkSchedule();

  group('WorkSchedule.dailyLimitInstant', () {
    test('no limit, and a limit as long as the day, both mean no cut-off', () {
      final monday = DateTime(2026, 5, 4, 11);
      expect(
        schedule.dailyLimitInstant(when: monday, limitMinutes: 0),
        isNull,
        reason: 'zero is the off switch',
      );
      expect(
        schedule.dailyLimitInstant(when: monday, limitMinutes: -60),
        isNull,
      );
      expect(
        schedule.dailyLimitInstant(
          when: monday,
          limitMinutes: schedule.lengthMinutes,
        ),
        isNull,
        reason:
            'a six-hour limit on a six-hour day is the schedule already saying '
            'it; a line drawn at the closing time would be a cut-off no window '
            'could ever cross',
      );
      expect(
        schedule.dailyLimitInstant(when: monday, limitMinutes: 12 * 60),
        isNull,
      );
    });

    test('the cut-off is measured from the start of the work day', () {
      // 09:00 + 6h = 15:00, not "six hours after the app was opened".
      expect(
        schedule.dailyLimitInstant(
          when: DateTime(2026, 5, 4, 11),
          limitMinutes: 6 * 60,
        ),
        DateTime(2026, 5, 4, 15),
      );
    });

    test('the cut-off belongs to the day of the window, not of the clock', () {
      // The OS queue spans days, so a candidate must be judged against its own
      // date. Computing this once from `now` would stop applying after midnight.
      expect(
        schedule.dailyLimitInstant(
          when: DateTime(2026, 5, 5, 8, 58),
          limitMinutes: 60,
        ),
        DateTime(2026, 5, 5, 10),
      );
      expect(
        schedule.dailyLimitInstant(
          when: DateTime(2026, 5, 6, 23),
          limitMinutes: 60,
        ),
        DateTime(2026, 5, 6, 10),
      );
    });

    test('a different work day moves the cut-off with it', () {
      final early = WorkSchedule(startMinute: 6 * 60, endMinute: 18 * 60);
      expect(
        early.dailyLimitInstant(
          when: DateTime(2026, 5, 4),
          limitMinutes: 4 * 60,
        ),
        DateTime(2026, 5, 4, 10),
      );
    });
  });

  group('WorkSchedule.isPastDailyLimit', () {
    test('the cut-off instant itself is past the limit', () {
      // A window starting exactly at 15:00 is *not* offered: the limit is the
      // first instant the app is done, and letting the boundary window through
      // would make "breaks stop at 15:00" mean 15:05.
      expect(
        schedule.isPastDailyLimit(
          windowStart: DateTime(2026, 5, 4, 15),
          limitMinutes: 6 * 60,
        ),
        isTrue,
      );
      expect(
        schedule.isPastDailyLimit(
          windowStart: DateTime(2026, 5, 4, 14, 55),
          limitMinutes: 6 * 60,
        ),
        isFalse,
      );
    });

    test('a window that opened before the cut-off is not revoked by it', () {
      // The rule compares the window's start, so this is the same assertion
      // stated from the other side: a window at 14:55 remains offered for its
      // whole length, and its closing instant sits exactly on the cut-off.
      final windowStart = DateTime(2026, 5, 4, 14, 55);
      expect(
        schedule.isPastDailyLimit(
          windowStart: windowStart,
          limitMinutes: 6 * 60,
        ),
        isFalse,
      );
      expect(
        windowStart.add(const Duration(minutes: 5)),
        DateTime(2026, 5, 4, 15),
        reason: 'the window closes at the cut-off rather than before it',
      );
    });

    test('without a limit nothing is ever past it', () {
      expect(
        schedule.isPastDailyLimit(
          windowStart: DateTime(2026, 5, 4, 23, 59),
          limitMinutes: 0,
        ),
        isFalse,
      );
    });
  });

  group('lengthMinutes', () {
    test('is the scheduled span of one day', () {
      expect(schedule.lengthMinutes, 8 * 60);
      expect(
        WorkSchedule(
          startMinute: 8 * 60,
          endMinute: 16 * 60 + 30,
        ).lengthMinutes,
        510,
      );
    });
  });
}
