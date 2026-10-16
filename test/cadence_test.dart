import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_cadence.dart';
import 'package:standup_app/core/app_identity.dart';
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
    });

    test('defaultPreferences matches AppCadence', () {
      final prefs = UserPreferences.defaultPreferences('test');
      expect(prefs.notificationFrequency, AppCadence.defaultCadenceMinutes);
      expect(prefs.actionWindowMinutes, AppCadence.defaultActionWindowMinutes);
      expect(prefs.streakGoal, AppCadence.defaultDailyGoal);
      expect(prefs.preludeEnabled, isTrue);
      expect(prefs.preludeMinutes, AppCadence.defaultPreludeMinutes);
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

    test('options are strictly ascending', () {
      for (final list in [
        AppCadence.cadenceOptions,
        AppCadence.dailyGoalOptions,
        AppCadence.actionWindowOptions,
        AppCadence.preludeOptions,
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
  });

  group('version is single-sourced', () {
    // `AppCadence` mentions the version only to keep the drift guard honest;
    // the real assertion lives in identity_test.dart.
    test('AppIdentity carries the version AppCadence docs refer to', () {
      expect(AppIdentity.version, isNotEmpty);
    });
  });
}
