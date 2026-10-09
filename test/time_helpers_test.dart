import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/data/models/stand_window.dart';
import 'package:standup_app/data/models/workday_metrics.dart';

void main() {
  group('dateKey', () {
    test('pads to the stored width', () {
      // The stored form is zero-padded, because the column is a TEXT key that
      // gets compared as a string. '2026-1-7' would not match '2026-01-07'.
      expect(WorkdayMetrics.dateKey(DateTime(2026, 1, 7)), '2026-01-07');
      expect(WorkdayMetrics.dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('round-trips through DateTime.parse', () {
      final date = DateTime(2026, 3, 9);
      expect(DateTime.parse(WorkdayMetrics.dateKey(date)), date);
    });

    test('the key does not depend on the time of day', () {
      // Analytics is one row per day, so two rows on either side of midnight
      // local must produce the same key or a streak splits in two.
      final morning = DateTime(2026, 5, 4, 0, 0, 1);
      final evening = DateTime(2026, 5, 4, 23, 59, 59);
      expect(WorkdayMetrics.dateKey(morning), WorkdayMetrics.dateKey(evening));
    });

    test('a leap day is handled', () {
      expect(WorkdayMetrics.dateKey(DateTime(2028, 2, 29)), '2028-02-29');
    });
  });

  group('formatClock', () {
    test('pads both components', () {
      expect(formatClock(const Duration(minutes: 5, seconds: 7)), '05:07');
      expect(formatClock(const Duration(minutes: 45, seconds: 30)), '45:30');
    });

    test('handles an exact minute boundary without rolling over', () {
      // The bug this guards: computing seconds as `d.inSeconds % 60` after
      // rounding the whole duration renders 60 seconds as "1:60".
      expect(formatClock(const Duration(minutes: 1)), '01:00');
      expect(formatClock(const Duration(seconds: 59)), '00:59');
      expect(formatClock(const Duration(seconds: 60)), '01:00');
      expect(
        formatClock(const Duration(minutes: 1, milliseconds: 900)),
        '01:00',
      );
    });

    test('does not wrap minutes past an hour', () {
      // A 90-minute duration is 90:00, not 30:00. Rolling over silently would
      // make a long countdown read as a short one.
      expect(formatClock(const Duration(minutes: 90)), '90:00');
    });

    test('a negative duration clamps to zero rather than going negative', () {
      // The countdown passes the remainder after the due time, which goes
      // briefly negative before the state machine resets it.
      expect(formatClock(const Duration(seconds: -5)), '00:00');
    });

    test('zero is zero-padded', () {
      expect(formatClock(Duration.zero), '00:00');
    });
  });

  group('QuietHours', () {
    test('parses a well-formed window', () {
      final window = QuietHours.parse('22:00-06:00');
      expect(window, isNotNull);
      expect(window!.start, 22 * 60);
      expect(window.end, 6 * 60);
    });

    test('rejects malformed input rather than throwing', () {
      // The value is user-editable and persisted, so a corrupt row must not be
      // able to stop the app launching.
      for (final bad in <String?>[
        null,
        '',
        '22:00',
        '22:00-06:00-08:00',
        '25:00-06:00',
        '22:70-06:00',
        'aa:bb-06:00',
        'not-a-window',
      ]) {
        expect(QuietHours.parse(bad), isNull, reason: 'accepted "$bad"');
      }
    });

    test('a same-day window contains its own range', () {
      final window = QuietHours.parse('09:00-17:00')!;
      expect(window.contains(DateTime(2026, 1, 1, 9, 0)), isTrue);
      expect(window.contains(DateTime(2026, 1, 1, 16, 59)), isTrue);
      expect(window.contains(DateTime(2026, 1, 1, 17, 0)), isFalse);
      expect(window.contains(DateTime(2026, 1, 1, 8, 59)), isFalse);
    });

    test('a wrapping window covers both sides of midnight', () {
      // This is the case the duplicated scheduler-side parser got wrong, which
      // is why the rule now lives in one place.
      final window = QuietHours.parse('22:00-06:00')!;
      expect(window.contains(DateTime(2026, 1, 1, 23, 30)), isTrue);
      expect(window.contains(DateTime(2026, 1, 2, 2, 0)), isTrue);
      expect(window.contains(DateTime(2026, 1, 2, 5, 59)), isTrue);
      expect(window.contains(DateTime(2026, 1, 2, 6, 0)), isFalse);
      expect(window.contains(DateTime(2026, 1, 2, 12, 0)), isFalse);
    });

    test('an empty window never suppresses anything', () {
      expect(QuietHours.isQuietAt(null, DateTime(2026, 1, 1, 3)), isFalse);
      expect(QuietHours.isQuietAt('', DateTime(2026, 1, 1, 3)), isFalse);
    });
  });
}
