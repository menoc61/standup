import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_cadence.dart';
import 'package:standup_app/data/local/app_database.dart';
import 'package:standup_app/data/local/local_repository.dart';
import 'package:standup_app/data/models/guidance_feedback.dart';

void main() {
  test(
    'schema v4 data migrates without loss and receives indexes and AI opt-in',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (db) {
            db.execute('''
            CREATE TABLE user_preferences_table (
              id TEXT NOT NULL PRIMARY KEY,
              user_id TEXT NOT NULL,
              theme_mode TEXT NOT NULL,
              color_system TEXT NOT NULL,
              notification_frequency INTEGER NOT NULL,
              sound_enabled INTEGER NOT NULL,
              haptics_enabled INTEGER NOT NULL,
              statistics_opt_in INTEGER NOT NULL,
              onboarding_completed INTEGER NOT NULL,
              selected_sound TEXT NOT NULL,
              quiet_hours TEXT,
              streak_goal INTEGER NOT NULL,
              action_window_minutes INTEGER NOT NULL,
              enforce_action_window INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
            db.execute('''
            INSERT INTO user_preferences_table (
              id, user_id, theme_mode, color_system,
              notification_frequency, sound_enabled, haptics_enabled,
              statistics_opt_in, onboarding_completed, selected_sound,
              quiet_hours, streak_goal, action_window_minutes,
              enforce_action_window, updated_at
            ) VALUES (
              'pref_local_legacy', 'local_legacy', 'dark', 'crimson',
              90, 0, 1, 0, 1, 'chime', '22:00-06:00', 6, 10, 1, 1791849600000
            )
          ''');
            db.execute('''
            CREATE TABLE reminder_logs_table (
              id TEXT NOT NULL PRIMARY KEY,
              user_id TEXT NOT NULL,
              scheduled_time INTEGER NOT NULL,
              action_taken TEXT NOT NULL,
              snooze_duration INTEGER NOT NULL DEFAULT 0,
              timestamp INTEGER NOT NULL,
              synced_to_cloud INTEGER NOT NULL DEFAULT 0
            )
          ''');
            db.execute('''
            CREATE TABLE analytics_daily_table (
              id TEXT NOT NULL PRIMARY KEY,
              user_id TEXT NOT NULL,
              date TEXT NOT NULL,
              reminders_sent INTEGER NOT NULL DEFAULT 0,
              reminders_completed INTEGER NOT NULL DEFAULT 0,
              reminders_snoozed INTEGER NOT NULL DEFAULT 0,
              reminders_skipped INTEGER NOT NULL DEFAULT 0,
              total_stand_time INTEGER NOT NULL DEFAULT 0,
              organization_id TEXT,
              synced_to_cloud INTEGER NOT NULL DEFAULT 0
            )
          ''');
            db.execute('PRAGMA user_version = 4');
          },
        ),
      );
      final repository = LocalDatabaseRepository(database);

      final migrated = await repository.getUserPreferences('local_legacy');
      expect(migrated, isNotNull);
      expect(migrated!.id, 'pref_local_legacy');
      expect(migrated.themeMode, 'dark');
      expect(migrated.notificationFrequency, 90);
      expect(migrated.streakGoal, 6);
      expect(migrated.actionWindowMinutes, 10);
      expect(migrated.quietHours, '22:00-06:00');
      expect(migrated.workDays, '1,2,3,4,5');
      expect(migrated.workStartMinute, 540);
      expect(migrated.workEndMinute, 1020);
      expect(migrated.aiGuidanceOptIn, isFalse);
      // The prelude columns arrive at v8. A row written by any earlier schema
      // must receive the defaults without losing the values it already had.
      expect(migrated.preludeEnabled, isTrue);
      expect(migrated.preludeMinutes, AppCadence.defaultPreludeMinutes);
      // The forced-break column arrives at v9 and must default to opted out.
      expect(migrated.breakBlockingEnabled, isFalse);
      // The guidance-feedback column arrives at v10. No feedback was ever
      // recorded before it existed, so "none" is the only honest value — not
      // "helpful", which would be inventing an opinion for the user.
      expect(migrated.guidanceFeedback, GuidanceFeedback.none);
      // The daily cut-off arrives at v11 and must default to off: a limit
      // applied by an upgrade would end somebody's afternoon unasked.
      expect(migrated.dailyLimitMinutes, AppCadence.defaultDailyLimitMinutes);
      // Escalation arrives at v12 for the same reason, only more so: it is the
      // setting that lets the break screen raise itself, so an upgrade must
      // never arm it on somebody's behalf.
      expect(migrated.escalationPromptLimit, 0);
      expect(
        migrated.escalationPromptLimit,
        AppCadence.defaultEscalationPromptLimit,
      );

      final edited = migrated.copyWith(
        aiGuidanceOptIn: true,
        workDays: '1,3,5',
        workStartMinute: 8 * 60 + 30,
        workEndMinute: 16 * 60 + 30,
        preludeEnabled: false,
        preludeMinutes: 10,
        breakBlockingEnabled: true,
        guidanceFeedback: GuidanceFeedback.suggestionsTooFrequent,
        dailyLimitMinutes: 6 * 60,
        escalationPromptLimit: 3,
      );
      await repository.saveUserPreferences(edited);
      final reloaded = await repository.getUserPreferences('local_legacy');
      expect(reloaded?.workSchedule, edited.workSchedule);
      expect(reloaded?.aiGuidanceOptIn, isTrue);
      // The prelude choice round-trips through the real schema, not just JSON.
      expect(reloaded?.preludeEnabled, isFalse);
      expect(reloaded?.preludeMinutes, 10);
      expect(reloaded?.breakBlockingEnabled, isTrue);
      // So does the cut-off, which is meaningless unless it outlives the
      // session that set it.
      expect(reloaded?.dailyLimitMinutes, 6 * 60);
      // And so does the escalation limit: a streak rule that forgot itself on
      // restart would be a promise the app cannot keep.
      expect(reloaded?.escalationPromptLimit, 3);
      // So does the feedback the employee gave, which is the whole point of
      // storing it: it has to survive the process that collected it.
      expect(
        reloaded?.guidanceFeedback,
        GuidanceFeedback.suggestionsTooFrequent,
      );

      final indexes = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final indexNames = indexes.map((row) => row.read<String>('name')).toSet();
      expect(
        indexNames,
        containsAll({
          'user_preferences_user_id_idx',
          'reminder_logs_user_timestamp_idx',
          'reminder_logs_user_action_timestamp_idx',
          'analytics_daily_user_date_idx',
          'analytics_daily_user_synced_idx',
        }),
      );

      await database.close();
    },
  );
}
