import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_cadence.dart';
import 'package:standup_app/core/escalation.dart';

/// The counting rules behind escalation, pinned one at a time.
///
/// Every one of these is a judgement about somebody's working day: when the app
/// is allowed to conclude that a break was ignored. Getting one wrong either
/// nags a user who did nothing wrong or, worse, covers the screen of an empty
/// desk. So each rule is stated here rather than inferred from the UI.
void main() {
  group('IgnoredPromptTracker', () {
    late IgnoredPromptTracker tracker;
    late Set<int> acted;

    setUp(() {
      tracker = IgnoredPromptTracker();
      acted = <int>{};
    });

    /// Feeds one tick: the window open right now (its closing instant, or null
    /// between windows), whether the user is away, and whether this platform can
    /// report presence at all.
    void tick(int? windowKey, {bool away = false, bool presence = true}) {
      tracker.observe(
        windowKey: windowKey,
        away: away,
        presenceAvailable: presence,
        wasActed: acted.contains,
      );
    }

    /// Runs one whole window that nobody acted on.
    void ignoredWindow(int key, {bool away = false, bool presence = true}) {
      tick(key, away: away, presence: presence);
      tick(null, presence: presence);
    }

    test('a window that closes with nothing recorded counts as ignored', () {
      ignoredWindow(1000);
      expect(tracker.ignoredStreak, 1);
    });

    test('a window the user acted on resets the streak to zero', () {
      ignoredWindow(1000);
      expect(tracker.ignoredStreak, 1);

      acted.add(2000);
      tick(2000);
      tick(null);

      expect(tracker.ignoredStreak, 0);
    });

    test('a window that saw the user away is neutral, not an ignore', () {
      // Absence is not ignoring, and it is not a reset either: nobody ignored a
      // prompt, so there is nothing to punish and nothing to forgive. The streak
      // simply survives the walk.
      ignoredWindow(1000);
      expect(tracker.ignoredStreak, 1);

      tick(2000);
      tick(2000, away: true);
      tick(null);

      expect(tracker.ignoredStreak, 1);
    });

    test('a window that opened over an empty desk never counts', () {
      tick(1000, away: true);
      tick(null);

      expect(tracker.ignoredStreak, 0);
    });

    test('without a presence reading nothing is counted at all', () {
      // Where the platform cannot answer "is anybody there?", an ignored break
      // and an empty chair are indistinguishable. Doing nothing is the only
      // honest option, so escalation stays inert rather than guessing.
      ignoredWindow(1000, presence: false);
      ignoredWindow(2000, presence: false);

      expect(tracker.ignoredStreak, 0);
    });

    test('acting mid-window drops the streak at once', () {
      // Not at the next window close: the cover this streak raised has to get
      // out of the way on the same tap that satisfies it.
      ignoredWindow(1000);
      tick(2000);
      expect(tracker.ignoredStreak, 1);

      tracker.acted();

      expect(tracker.ignoredStreak, 0);
    });

    test('resetting forgets the window as well as the count', () {
      ignoredWindow(1000);
      tick(2000);

      tracker.reset();

      expect(tracker.ignoredStreak, 0);
      expect(tracker.openWindowKey, isNull);
    });

    test('a limit of zero can never escalate, however long the streak', () {
      for (var i = 0; i < 5; i++) {
        ignoredWindow(1000 + i * 1000);
      }
      expect(tracker.ignoredStreak, 5);
      expect(tracker.isDue(0), isFalse);
    });

    test('the streak becomes due exactly at the configured limit', () {
      ignoredWindow(1000);
      ignoredWindow(2000);
      expect(tracker.isDue(3), isFalse);

      ignoredWindow(3000);
      expect(tracker.isDue(3), isTrue);
      expect(tracker.isDue(5), isFalse);
    });

    test('the tracker survives ticks that change nothing', () {
      // The ticker runs at 1 Hz, so most ticks see the same window. None of them
      // may count as a second close, or every window would escalate instantly.
      ignoredWindow(1000);
      tick(null);
      tick(null);
      tick(null);

      expect(tracker.ignoredStreak, 1);
    });
  });

  group('AppCadence.clampEscalationPromptLimit', () {
    test('zero and anything below it mean off', () {
      expect(AppCadence.defaultEscalationPromptLimit, 0);
      expect(AppCadence.clampEscalationPromptLimit(0), 0);
      expect(AppCadence.clampEscalationPromptLimit(-3), 0);
    });

    test('an offered limit is kept as it is', () {
      for (final option in AppCadence.escalationOptions) {
        expect(AppCadence.clampEscalationPromptLimit(option), option);
      }
    });

    test('a hand-edited value rounds up, never quietly off', () {
      // Failing in the "still enforced" direction is the safe one for a setting
      // whose whole point is enforcement: silently disabling it would undo the
      // choice the user made when they turned it on.
      expect(AppCadence.clampEscalationPromptLimit(1), 2);
      expect(AppCadence.clampEscalationPromptLimit(4), 5);
      expect(
        AppCadence.clampEscalationPromptLimit(9),
        AppCadence.escalationOptions.last,
      );
    });
  });
}
