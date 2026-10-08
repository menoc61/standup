import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/models/stand_window.dart';

void main() {
  group('StandWindow.activeWindow', () {
    test('opens in the last five minutes of the hour', () {
      // 09:58 is inside the 09:55 -> 10:00 window.
      final window = StandWindow.activeWindow(now: DateTime(2026, 1, 1, 9, 58));
      expect(window, isNotNull);
      expect(window!.start, DateTime(2026, 1, 1, 9, 55));
      expect(window.end, DateTime(2026, 1, 1, 10));
    });

    test('is closed at 09:54, one minute before opening', () {
      expect(
        StandWindow.activeWindow(now: DateTime(2026, 1, 1, 9, 54)),
        isNull,
      );
      expect(
        StandWindow.isActionable(now: DateTime(2026, 1, 1, 9, 54)),
        isFalse,
      );
    });

    test('treats the end boundary as exclusive so windows never overlap', () {
      // 09:59:59 is the last instant of the window.
      expect(
        StandWindow.activeWindow(now: DateTime(2026, 1, 1, 9, 59, 59))!.end,
        DateTime(2026, 1, 1, 10),
      );
      // Exactly 10:00 the window has already closed: the end is exclusive.
      expect(
        StandWindow.activeWindow(now: DateTime(2026, 1, 1, 10, 0)),
        isNull,
      );
      // The following window does not open until 10:55.
      expect(
        StandWindow.activeWindow(now: DateTime(2026, 1, 1, 10, 54)),
        isNull,
      );
      expect(
        StandWindow.activeWindow(now: DateTime(2026, 1, 1, 10, 55))!.start,
        DateTime(2026, 1, 1, 10, 55),
      );
    });

    test('wraps correctly across midnight', () {
      final window = StandWindow.activeWindow(
        now: DateTime(2026, 1, 1, 23, 58),
      );
      expect(window!.start, DateTime(2026, 1, 1, 23, 55));
      expect(window.end, DateTime(2026, 1, 2));
    });

    test('honours a 30-minute cadence by opening twice per hour', () {
      // With cadence 30 and a 5-minute window, the window opens at :25 and :55.
      final first = StandWindow.activeWindow(
        now: DateTime(2026, 1, 1, 10, 26),
        actionWindowMinutes: 5,
        cadenceMinutes: 30,
      );
      expect(first!.start, DateTime(2026, 1, 1, 10, 25));
      expect(first.end, DateTime(2026, 1, 1, 10, 30));

      final second = StandWindow.activeWindow(
        now: DateTime(2026, 1, 1, 10, 57),
        actionWindowMinutes: 5,
        cadenceMinutes: 30,
      );
      expect(second!.start, DateTime(2026, 1, 1, 10, 55));
    });

    test('rejects a window wider than the cadence', () {
      expect(
        () => StandWindow.activeWindow(
          now: DateTime(2026, 1, 1, 10),
          actionWindowMinutes: 90,
          cadenceMinutes: 60,
        ),
        throwsArgumentError,
      );
    });
  });

  group('StandWindow countdowns', () {
    test('reports remaining time inside an open window', () {
      expect(
        StandWindow.remainingInWindow(now: DateTime(2026, 1, 1, 9, 57)),
        const Duration(minutes: 3),
      );
    });

    test('reports zero remaining time when closed', () {
      expect(
        StandWindow.remainingInWindow(now: DateTime(2026, 1, 1, 9, 30)),
        Duration.zero,
      );
    });

    test('reports time until the next window when closed', () {
      expect(
        StandWindow.untilNextWindow(now: DateTime(2026, 1, 1, 9, 50)),
        const Duration(minutes: 5),
      );
    });

    test('reports zero until next window while open', () {
      expect(
        StandWindow.untilNextWindow(now: DateTime(2026, 1, 1, 9, 57)),
        Duration.zero,
      );
    });
  });

  group('StandWindow.windowsBetween', () {
    test(
      'counts whole windows in a span without trusting a stored counter',
      () {
        // From 09:30 to 11:10 spans the 10:00 and 11:00 boundaries.
        expect(
          StandWindow.windowsBetween(
            from: DateTime(2026, 1, 1, 9, 30),
            to: DateTime(2026, 1, 1, 11, 10),
          ),
          2,
        );
      },
    );

    test('returns zero for an inverted or empty range', () {
      expect(
        StandWindow.windowsBetween(
          from: DateTime(2026, 1, 1, 12),
          to: DateTime(2026, 1, 1, 11),
        ),
        0,
      );
    });
  });

  group('ClockIntegrityGuard', () {
    test('counts a backwards clock jump as a violation', () {
      expect(
        ClockIntegrityGuard.countViolations(
          previous: DateTime(2026, 1, 1, 10),
          now: DateTime(2026, 1, 1, 9, 30),
        ),
        1,
      );
    });

    test('counts a large forward jump as a violation', () {
      expect(
        ClockIntegrityGuard.countViolations(
          previous: DateTime(2026, 1, 1, 10),
          now: DateTime(2026, 1, 1, 14),
        ),
        1,
      );
    });

    test('accepts ordinary elapsed time', () {
      expect(
        ClockIntegrityGuard.countViolations(
          previous: DateTime(2026, 1, 1, 10),
          now: DateTime(2026, 1, 1, 10, 1),
        ),
        0,
      );
    });

    test('flags a device that repeatedly moves the clock', () {
      final start = DateTime(2026, 1, 1, 8);
      final now = DateTime(2026, 1, 1, 12);
      expect(
        ClockIntegrityGuard.isUnreliable(
          violations: 10,
          windowStart: start,
          now: now,
        ),
        isTrue,
      );
      expect(
        ClockIntegrityGuard.isUnreliable(
          violations: 1,
          windowStart: start,
          now: now,
        ),
        isFalse,
      );
    });
  });
}
