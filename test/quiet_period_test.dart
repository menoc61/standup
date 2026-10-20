import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/quiet_mode.dart';

/// The arithmetic behind a timed quiet mode.
///
/// A pause that ends at the wrong instant is worse than no pause at all: the
/// user trusts it, stops watching for reminders, and either gets interrupted
/// anyway or stays silent past the moment they expected to be back. The day
/// boundary is the case with a real trap in it — "until tomorrow" is not
/// twenty-four hours.
void main() {
  group('QuietPeriod', () {
    final now = DateTime(2026, 3, 14, 14, 30);

    test('an indefinite pause is active whenever it is asked', () {
      const period = QuietPeriod.indefinite();

      expect(period.isActiveAt(now), isTrue);
      expect(period.isActiveAt(now.add(const Duration(days: 365))), isTrue);
      expect(period.remainingAt(now), isNull);
    });

    test('a timed pause is active until its instant and not at it', () {
      final period = QuietPeriod.until(now.add(const Duration(minutes: 30)));

      expect(period.isActiveAt(now), isTrue);
      expect(period.isActiveAt(now.add(const Duration(minutes: 29))), isTrue);
      expect(period.isActiveAt(now.add(const Duration(minutes: 30))), isFalse);
    });

    test('remaining counts down and never goes negative', () {
      final period = QuietPeriod.until(now.add(const Duration(minutes: 5)));

      expect(period.remainingAt(now), const Duration(minutes: 5));
      expect(
        period.remainingAt(now.add(const Duration(minutes: 3))),
        const Duration(minutes: 2),
      );
      // Clamped, not negative: the bar reads this value while the tick that
      // clears the pause may still be a fraction of a second away.
      expect(
        period.remainingAt(now.add(const Duration(minutes: 9))),
        Duration.zero,
      );
    });

    test('the next day begins at local midnight', () {
      final midnight = QuietPeriod.nextLocalMidnight(
        DateTime(2026, 3, 14, 23, 59),
      );

      expect(midnight.day, 15);
      expect(midnight.hour, 0);
      expect(midnight.minute, 0);
      expect(midnight.second, 0);
    });

    test('it is midnight, not twenty-four hours later', () {
      // Two different times on the same day must land on the same instant. With
      // `add(Duration(days: 1))` they would not on a clock-change night, and the
      // pause would end an hour early or an hour late exactly then.
      expect(
        QuietPeriod.nextLocalMidnight(DateTime(2026, 3, 14, 6, 0)),
        QuietPeriod.nextLocalMidnight(DateTime(2026, 3, 14, 23, 0)),
      );
    });

    test('the day, month and year all roll over', () {
      final midnight = QuietPeriod.nextLocalMidnight(
        DateTime(2026, 12, 31, 22, 10),
      );

      expect(midnight.year, 2027);
      expect(midnight.month, 1);
      expect(midnight.day, 1);
      expect(midnight.hour, 0);
    });
  });
}
