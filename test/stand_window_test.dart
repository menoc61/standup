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
    test('classifies ordinary elapsed time as ok', () {
      expect(
        ClockIntegrityGuard.classify(
          wallDelta: const Duration(seconds: 1),
          monotonicDelta: const Duration(seconds: 1),
        ),
        ClockVerdict.ok,
      );
    });

    test('a backwards wall clock is a violation', () {
      expect(
        ClockIntegrityGuard.classify(
          wallDelta: const Duration(seconds: -30),
          monotonicDelta: const Duration(seconds: 1),
        ),
        ClockVerdict.violation,
      );
    });

    test(
      'a forward jump with a matching monotonic reference is a violation',
      () {
        // The wall clock claims four hours passed while the process was only up
        // for one second.
        expect(
          ClockIntegrityGuard.classify(
            wallDelta: const Duration(hours: 4),
            monotonicDelta: const Duration(seconds: 1),
          ),
          ClockVerdict.violation,
        );
      },
    );

    test('an OS suspend is a reset, not tampering', () {
      // This is the regression that would otherwise get a diligent user flagged
      // every morning after a normal night of sleep: the wall clock advances by
      // the sleep duration while the monotonic stopwatch does not move at all.
      expect(
        ClockIntegrityGuard.classify(
          wallDelta: const Duration(hours: 8),
          monotonicDelta: Duration.zero,
        ),
        ClockVerdict.reset,
      );
    });

    test('a long foreground gap with no clock movement is still a reset', () {
      expect(
        ClockIntegrityGuard.classify(
          wallDelta: const Duration(hours: 2),
          monotonicDelta: const Duration(milliseconds: 100),
        ),
        ClockVerdict.reset,
      );
    });

    test('small divergence from timer imprecision is tolerated', () {
      expect(
        ClockIntegrityGuard.classify(
          wallDelta: const Duration(seconds: 75),
          monotonicDelta: const Duration(seconds: 1),
        ),
        ClockVerdict.ok,
      );
    });
  });

  group('ClockIntegrityTracker', () {
    test('three consecutive violations mark the device as distrusted', () {
      final tracker = ClockIntegrityTracker();
      var wall = DateTime(2026, 1, 1, 9);

      // First observation establishes the reference point.
      tracker.observe(
        wallNow: wall,
        monotonicDelta: const Duration(seconds: 1),
      );

      // Each subsequent reading jumps the wall clock forward by four hours
      // relative to the previous reading, while the app is demonstrably live.
      for (var i = 1; i <= ClockIntegrityGuard.tolerance; i++) {
        wall = wall.add(const Duration(hours: 4));
        tracker.observe(
          wallNow: wall,
          monotonicDelta: const Duration(seconds: 1),
        );
        if (i < ClockIntegrityGuard.tolerance) {
          expect(
            tracker.isDistrusted,
            isFalse,
            reason: 'not distrusted after $i violations',
          );
        }
      }
      expect(tracker.isDistrusted, isTrue);
      expect(tracker.streak, ClockIntegrityGuard.tolerance);
    });

    test('a suspend clears the streak so sleep is never punished', () {
      final tracker = ClockIntegrityTracker();
      var now = DateTime(2026, 1, 1, 22);
      tracker.observe(wallNow: now, monotonicDelta: const Duration(seconds: 1));
      now = now.add(const Duration(seconds: 1));
      tracker.observe(wallNow: now, monotonicDelta: const Duration(seconds: 1));
      expect(tracker.streak, 0, reason: 'clean readings stay at zero');

      // Night: eight hours of wall clock, monotonic frozen.
      now = now.add(const Duration(hours: 8));
      tracker.observe(wallNow: now, monotonicDelta: Duration.zero);
      expect(tracker.isDistrusted, isFalse);
      expect(tracker.streak, 0);
    });

    test('clean readings decay an existing streak', () {
      final tracker = ClockIntegrityTracker();
      var wall = DateTime(2026, 1, 1, 12);

      // Baseline.
      tracker.observe(
        wallNow: wall,
        monotonicDelta: const Duration(seconds: 1),
      );

      // One clear violation.
      wall = wall.add(const Duration(hours: 5));
      tracker.observe(
        wallNow: wall,
        monotonicDelta: const Duration(seconds: 1),
      );
      expect(tracker.streak, 1);

      // Then honest readings: one per second, matching monotonic time.
      for (var i = 0; i < 3; i++) {
        wall = wall.add(const Duration(seconds: 1));
        tracker.observe(
          wallNow: wall,
          monotonicDelta: const Duration(seconds: 1),
        );
      }
      expect(tracker.streak, 0);
      expect(tracker.isDistrusted, isFalse);
    });
  });
}
