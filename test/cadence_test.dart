import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_cadence.dart';
import 'package:standup_app/core/app_identity.dart';
import 'package:standup_app/data/models/stand_window.dart';
import 'package:standup_app/data/models/user_preferences.dart';

/// Locks `AppCadence` to every other layer that has to agree with it.
///
/// ## Why this test exists
///
/// A cadence default is written down five times, because most of the layers
/// that need it cannot see the Dart constant:
///
///  1. the Drift column default
///  2. the hand-written `ALTER TABLE` in the v2→v3 and v3→v4 migrations
///  3. `UserPreferences`'s constructor default
///  4. `UserPreferences.fromJson`'s `??` fallback
///  5. the widget payload's `fromMap` fallback
///
/// A disagreement between any two is invisible until a user gets a setting they
/// did not choose, and it is invisible *especially* for the SQL, because a
/// wrong `DEFAULT` only ever applies to rows created by a migration — never to
/// the rows an install already has. So the check is textual rather than
/// behavioural: the SQL literally cannot reference a Dart constant, so the only
/// way to keep them in step is to assert the numbers match.
void main() {
  group('cadence defaults', () {
    test('UserPreferences constructor defaults match AppCadence', () {
      final prefs = UserPreferences(
        id: 'pref_test',
        userId: 'test',
        notificationFrequency: AppCadence.defaultCadenceMinutes,
      );
      expect(prefs.actionWindowMinutes, AppCadence.defaultActionWindowMinutes);
      expect(prefs.streakGoal, AppCadence.defaultDailyGoal);
      expect(prefs.preludeEnabled, isTrue);
      expect(prefs.preludeMinutes, AppCadence.defaultPreludeMinutes);
      expect(prefs.breakBlockingEnabled, isFalse);
      expect(prefs.dailyLimitMinutes, AppCadence.defaultDailyLimitMinutes);
    });

    test('fromJson falls back to AppCadence for missing keys', () {
      final prefs = UserPreferences.fromJson(const {
        'id': 'pref_test',
        'user_id': 'test',
      });
      expect(prefs.notificationFrequency, AppCadence.defaultCadenceMinutes);
      expect(prefs.actionWindowMinutes, AppCadence.defaultActionWindowMinutes);
      expect(prefs.streakGoal, AppCadence.defaultDailyGoal);
      expect(prefs.preludeEnabled, isTrue);
      expect(prefs.preludeMinutes, AppCadence.defaultPreludeMinutes);
      expect(prefs.breakBlockingEnabled, isFalse);
      expect(prefs.dailyLimitMinutes, AppCadence.defaultDailyLimitMinutes);
    });

    test('defaultPreferences matches AppCadence', () {
      final prefs = UserPreferences.defaultPreferences('test');
      expect(prefs.notificationFrequency, AppCadence.defaultCadenceMinutes);
      expect(prefs.actionWindowMinutes, AppCadence.defaultActionWindowMinutes);
      expect(prefs.streakGoal, AppCadence.defaultDailyGoal);
      expect(prefs.preludeEnabled, isTrue);
      expect(prefs.preludeMinutes, AppCadence.defaultPreludeMinutes);
      expect(prefs.breakBlockingEnabled, isFalse);
      expect(prefs.dailyLimitMinutes, AppCadence.defaultDailyLimitMinutes);
    });
  });

  group('migrations agree with the schema', () {
    /// The migration SQL is a list of raw statements, so the values are checked
    /// by reading them out of the source rather than by running them.
    final databaseSource = File('lib/data/local/app_database.dart')
        .readAsStringSync();

    test('streak_goal column default matches AppCadence.defaultDailyGoal', () {
      expect(
        databaseSource,
        contains(
          'ADD COLUMN streak_goal INTEGER NOT NULL '
          'DEFAULT ${AppCadence.defaultDailyGoal}',
        ),
        reason:
            'The v4 migration writes DEFAULT ${AppCadence.defaultDailyGoal} for '
            'streak_goal. Changing AppCadence.defaultDailyGoal without updating '
            'this SQL means new installs get a different goal than old ones.',
      );
    });

    test('action_window_minutes column default matches '
        'AppCadence.defaultActionWindowMinutes', () {
      expect(
        databaseSource,
        contains(
          'ADD COLUMN action_window_minutes INTEGER NOT NULL '
          'DEFAULT ${AppCadence.defaultActionWindowMinutes}',
        ),
        reason:
            'The v4 migration writes '
            'DEFAULT ${AppCadence.defaultActionWindowMinutes} for '
            'action_window_minutes.',
      );
    });

    test('no bare integer defaults remain in the Drift schema', () {
      // Scheduling and goal defaults must be single-sourced. Counter defaults
      // of zero are intentionally literal and do not belong to AppCadence.
      for (final staleDefault in [
        'notificationFrequency => integer().withDefault(const Constant(60))',
        'streakGoal => integer().withDefault(const Constant(8))',
        'actionWindowMinutes => integer().withDefault(const Constant(5))',
        'preludeMinutes => integer().withDefault(const Constant(5))',
      ]) {
        expect(databaseSource, isNot(contains(staleDefault)));
      }
    });

    test('prelude_minutes column default matches '
        'AppCadence.defaultPreludeMinutes', () {
      expect(
        databaseSource,
        contains(
          'ADD COLUMN prelude_minutes INTEGER NOT NULL '
          'DEFAULT ${AppCadence.defaultPreludeMinutes}',
        ),
        reason:
            'The v8 migration writes '
            'DEFAULT ${AppCadence.defaultPreludeMinutes} for prelude_minutes.',
      );
    });

    test('break_blocking_enabled migrates in as opted out', () {
      // A forced screen takeover must never arrive as a side effect of an
      // upgrade, so the migration default is the interesting value here rather
      // than the column default.
      expect(
        databaseSource,
        contains(
          'ADD COLUMN break_blocking_enabled INTEGER NOT NULL DEFAULT 0',
        ),
      );
    });

    test('daily_limit_minutes migrates in as off', () {
      // A cut-off applied by an upgrade would end somebody's afternoon without
      // them asking, so the migration must write the same "off" the Dart default
      // means.
      expect(
        databaseSource,
        contains(
          'ADD COLUMN daily_limit_minutes INTEGER NOT NULL '
          'DEFAULT ${AppCadence.defaultDailyLimitMinutes}',
        ),
        reason:
            'The v11 migration writes '
            'DEFAULT ${AppCadence.defaultDailyLimitMinutes} for '
            'daily_limit_minutes.',
      );
      expect(AppCadence.defaultDailyLimitMinutes, 0);
    });
  });

  group('option sets contain the default', () {
    // If a list of choices is ever edited without the default, a user can pick
    // options but can never get back to the value they started with.
    test('cadenceOptions contains defaultCadenceMinutes', () {
      expect(
        AppCadence.cadenceOptions,
        contains(AppCadence.defaultCadenceMinutes),
      );
    });

    test('dailyGoalOptions contains defaultDailyGoal', () {
      expect(
        AppCadence.dailyGoalOptions,
        contains(AppCadence.defaultDailyGoal),
      );
    });

    test('actionWindowOptions contains defaultActionWindowMinutes', () {
      expect(
        AppCadence.actionWindowOptions,
        contains(AppCadence.defaultActionWindowMinutes),
      );
    });

    test('preludeOptions contains defaultPreludeMinutes', () {
      expect(
        AppCadence.preludeOptions,
        contains(AppCadence.defaultPreludeMinutes),
      );
    });

    test('dailyLimitOptions spans hours and covers the bounds', () {
      expect(AppCadence.dailyLimitOptions, contains(60));
      expect(
        AppCadence.dailyLimitOptions,
        contains(AppCadence.enabledDailyLimitMinutes),
        reason:
            'the value the switch turns on must be one the picker can show, or '
            'turning the limit on would jump to a setting the user cannot see',
      );
      expect(
        AppCadence.dailyLimitOptions.first,
        AppCadence.minDailyLimitMinutes,
      );
      expect(
        AppCadence.dailyLimitOptions.last,
        AppCadence.maxDailyLimitMinutes,
      );
      // Zero is not an option: "off" is the switch, not a length.
      expect(AppCadence.dailyLimitOptions, isNot(contains(0)));
    });

    test('options are strictly ascending', () {
      for (final list in [
        AppCadence.cadenceOptions,
        AppCadence.dailyGoalOptions,
        AppCadence.actionWindowOptions,
        AppCadence.preludeOptions,
        AppCadence.dailyLimitOptions,
      ]) {
        for (var i = 1; i < list.length; i++) {
          expect(
            list[i],
            greaterThan(list[i - 1]),
            reason:
                'Options must ascend so the picker reads left to right: $list',
          );
        }
      }
    });
  });

  group('clamping', () {
    test('clampCadence bounds to one minute and one day', () {
      expect(AppCadence.clampCadence(0), AppCadence.minCadenceMinutes);
      expect(AppCadence.clampCadence(-90), AppCadence.minCadenceMinutes);
      expect(AppCadence.clampCadence(99999), AppCadence.maxCadenceMinutes);
      expect(AppCadence.clampCadence(60), 60);
    });

    test('a window can never exceed its cadence', () {
      expect(AppCadence.resolveActionWindow(15, 60), 15);
      expect(AppCadence.resolveActionWindow(90, 60), 60);
    });

    test('non-positive input falls back to the default, not to zero', () {
      expect(
        AppCadence.resolveActionWindow(0, 60),
        AppCadence.defaultActionWindowMinutes,
      );
      expect(
        AppCadence.resolveActionWindow(-5, 60),
        AppCadence.defaultActionWindowMinutes,
      );
    });

    test('a cadence shorter than the default window yields the cadence', () {
      // Otherwise the window is longer than the gap it sits in and the maths in
      // StandWindow produces a span that ends before it starts.
      expect(AppCadence.resolveActionWindow(0, 3), 3);
      expect(AppCadence.resolveActionWindow(5, 3), 3);
    });

    test('every offered action window is reachable at the default cadence', () {
      // This is the claim the defect backlog used to get wrong: it said the
      // picker offered 10 and 15 but the engine clamped them away. It only
      // clamps values longer than the cadence.
      for (final option in AppCadence.actionWindowOptions) {
        expect(
          AppCadence.resolveActionWindow(
            option,
            AppCadence.defaultCadenceMinutes,
          ),
          option,
          reason: '$option should survive at a 60-minute cadence',
        );
      }
    });

    test('resolvePrelude bounds the warning to the cadence', () {
      expect(
        AppCadence.resolvePrelude(10, 60),
        10,
        reason: 'a prelude shorter than the cadence survives',
      );
      expect(
        AppCadence.resolvePrelude(90, 60),
        60,
        reason: 'a prelude longer than the cadence is clamped to it',
      );
      expect(
        AppCadence.resolvePrelude(0, 60),
        AppCadence.defaultPreludeMinutes,
        reason: 'non-positive input falls back to the default',
      );
      expect(
        AppCadence.resolvePrelude(-5, 60),
        AppCadence.defaultPreludeMinutes,
      );
    });

    test('clampDailyLimit leaves zero alone and bounds the rest', () {
      // Zero is "off", not "the shortest day": collapsing it to an hour would
      // turn the default into a cut-off nobody chose.
      expect(AppCadence.clampDailyLimit(0), 0);
      expect(AppCadence.clampDailyLimit(-30), 0);
      expect(
        AppCadence.clampDailyLimit(30),
        AppCadence.minDailyLimitMinutes,
        reason: 'a hand-edited 30-minute day rounds up to the shortest offered',
      );
      expect(AppCadence.clampDailyLimit(9999), AppCadence.maxDailyLimitMinutes);
      expect(AppCadence.clampDailyLimit(480), 480);
    });
  });

  group('scheduling', () {
    test('the queue stays under the iOS outstanding-request limit', () {
      // iOS caps pending notification requests at 64 per app. Scheduling past
      // that gets requests silently dropped with no error.
      expect(AppCadence.scheduledReminderQueueSize, lessThan(64));
      expect(AppCadence.scheduledReminderQueueSize, greaterThan(24));
    });

    test('notification ids do not collide across the queue', () {
      final last =
          AppCadence.reminderNotificationIdBase +
          AppCadence.scheduledReminderQueueSize;
      expect(last, lessThan(4242), reason: '4242 is the live countdown id');
    });

    test('the prelude id range does not overlap the reminder range', () {
      final reminderEnd =
          AppCadence.reminderNotificationIdBase +
          AppCadence.scheduledReminderQueueSize;
      expect(
        AppCadence.preludeNotificationIdBase,
        greaterThanOrEqualTo(reminderEnd),
        reason: 'the two series must be cancellable independently',
      );
      final preludeEnd =
          AppCadence.preludeNotificationIdBase +
          AppCadence.scheduledReminderQueueSize;
      expect(preludeEnd, lessThan(4242));
    });

    test('guided stretch divides evenly into steps', () {
      expect(
        AppCadence.guidedStretchStepSeconds * AppCadence.guidedStretchStepCount,
        AppCadence.guidedStretchSeconds,
      );
    });

    test('the step lasts one step, and the last step lasts the rest', () {
      // The ticker decrements before asking, so step 0 starts on second 299 of
      // 300 and step 4 begins with the final minute. These are the boundaries
      // the routine's progress dots are drawn from.
      int step(int remaining) =>
          AppCadence.guidedStretchStepFor(secondsRemaining: remaining);

      expect(step(AppCadence.guidedStretchSeconds), 0);
      expect(step(241), 0);
      expect(step(240), 0);
      expect(step(239), 1);
      expect(step(180), 1);
      expect(step(179), 2);
      expect(step(120), 2);
      expect(step(119), 3);
      expect(step(60), 3);
      expect(step(59), 4);
      expect(step(1), 4);
      expect(step(0), 4);
    });

    test('every step index is one the routine can render', () {
      // The constant used to say four while the routine shows five, so this is
      // the assertion that keeps a future edit from making the last exercise
      // unreachable.
      for (
        var remaining = 0;
        remaining <= AppCadence.guidedStretchSeconds;
        remaining++
      ) {
        final index = AppCadence.guidedStretchStepFor(
          secondsRemaining: remaining,
        );
        expect(
          index,
          inInclusiveRange(0, AppCadence.guidedStretchStepCount - 1),
        );
      }
      expect(AppCadence.guidedStretchStepCount, 5);
    });

    test('a long break repeats the routine instead of stretching it', () {
      // Ten minutes is the five movements twice. A movement that lasted two
      // minutes would silently change what the routine asks the user to do.
      int step(int remaining) => AppCadence.guidedStretchStepFor(
        secondsRemaining: remaining,
        totalSeconds: 600,
      );

      expect(step(600), 0);
      expect(step(539), 1);
      expect(step(301), 4);
      // The last second of the first pass is still step 4, and the second after
      // it starts the routine again from the top.
      expect(step(300), 4);
      expect(step(299), 0);
      expect(step(1), 4);
    });

    test('the step is renderable whatever length the break has', () {
      for (final minutes in AppCadence.longBreakMinutesOptions) {
        final total = minutes * 60;
        for (var remaining = 0; remaining <= total; remaining++) {
          final index = AppCadence.guidedStretchStepFor(
            secondsRemaining: remaining,
            totalSeconds: total,
          );
          expect(
            index,
            inInclusiveRange(0, AppCadence.guidedStretchStepCount - 1),
          );
        }
      }
    });

    group('long breaks', () {
      test('are off by default, and off is the first offered period', () {
        expect(AppCadence.defaultLongBreakEvery, 0);
        expect(AppCadence.longBreakEveryOptions.first, 0);
      });

      test('a period of one rounds up rather than meaning every break', () {
        // "Every break" is not one of the offered periods, and quietly turning
        // every break into a ten-minute one is a far bigger change than the user
        // asked for.
        expect(AppCadence.clampLongBreakEvery(0), 0);
        expect(AppCadence.clampLongBreakEvery(-2), 0);
        expect(AppCadence.clampLongBreakEvery(1), 2);
        expect(AppCadence.clampLongBreakEvery(3), 3);
        expect(
          AppCadence.clampLongBreakEvery(9),
          AppCadence.longBreakEveryOptions.last,
        );
      });

      test('a broken length falls back to the default, never to zero', () {
        // A break with no length is not a smaller break, it is a broken one.
        expect(AppCadence.clampLongBreakMinutes(10), 10);
        expect(
          AppCadence.clampLongBreakMinutes(0),
          AppCadence.defaultLongBreakMinutes,
        );
        expect(
          AppCadence.clampLongBreakMinutes(7),
          AppCadence.defaultLongBreakMinutes,
        );
      });

      test('the break is the standard routine unless the window is long', () {
        expect(
          AppCadence.breakSecondsFor(longBreak: false),
          AppCadence.guidedStretchSeconds,
        );
        expect(
          AppCadence.breakSecondsFor(longBreak: true, longBreakMinutes: 15),
          900,
        );
      });
    });
  });

  group('StandWindow.isLongBreakWindow', () {
    // Boundaries are anchored to local midnight and spaced by the cadence, so a
    // boundary's ordinal is how many cadence steps past midnight it sits.
    final midnight = DateTime(2026, 5, 6);

    test('a period of zero or one means there are no long breaks', () {
      for (final hour in [1, 2, 3, 6]) {
        for (final period in [0, 1]) {
          expect(
            StandWindow.isLongBreakWindow(
              boundary: midnight.add(Duration(hours: hour)),
              everyNth: period,
            ),
            isFalse,
          );
        }
      }
    });

    test('every third window is a long break', () {
      bool isLong(int hour) => StandWindow.isLongBreakWindow(
        boundary: midnight.add(Duration(hours: hour)),
        everyNth: 3,
      );

      expect(isLong(1), isFalse);
      expect(isLong(2), isFalse);
      expect(isLong(3), isTrue);
      expect(isLong(4), isFalse);
      expect(isLong(5), isFalse);
      expect(isLong(6), isTrue);
      expect(isLong(9), isTrue);
    });

    test('the answer belongs to the window, not to the session', () {
      // Counting from midnight rather than from the last break taken makes the
      // same window a long break for everyone, whenever the app was launched and
      // however many breaks were actually taken — which is what lets the OS queue
      // schedule it ahead of time and what stops a stored counter drifting from
      // the clock.
      expect(
        StandWindow.isLongBreakWindow(
          boundary: DateTime(2026, 5, 6, 3),
          everyNth: 3,
        ),
        isTrue,
      );
      expect(
        StandWindow.isLongBreakWindow(
          boundary: DateTime(2026, 5, 7, 3),
          everyNth: 3,
        ),
        isTrue,
      );
    });

    test('midnight itself has no ordinal and is never a long break', () {
      expect(
        StandWindow.isLongBreakWindow(boundary: midnight, everyNth: 3),
        isFalse,
      );
    });

    test('the period follows the cadence, not the hour', () {
      // A 90-minute cadence puts its boundaries at 00:00, 01:30, 03:00, 04:30…,
      // so its third window closes at 04:30, where a 60-minute cadence's third
      // closes at 03:00. Reading the cadence is what keeps the two agreeing.
      expect(
        StandWindow.isLongBreakWindow(
          boundary: DateTime(2026, 5, 6, 4, 30),
          everyNth: 3,
          cadenceMinutes: 90,
        ),
        isTrue,
      );
      expect(
        StandWindow.isLongBreakWindow(
          boundary: DateTime(2026, 5, 6, 3),
          everyNth: 3,
          cadenceMinutes: 90,
        ),
        isFalse,
      );
    });
  });

  group('version is single-sourced', () {
    // `AppCadence` mentions the version only to keep the drift guard honest;
    // the real assertion lives in identity_test.dart.
    test('AppIdentity carries the version AppCadence docs refer to', () {
      expect(AppIdentity.version, isNotEmpty);
    });
  });
}
