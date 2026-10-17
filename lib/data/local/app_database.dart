import 'package:standup_app/core/app_cadence.dart';
import 'package:drift/drift.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/data/models/work_schedule.dart';

import 'database_connection_native.dart'
    if (dart.library.js_interop) 'database_connection_web.dart'
    as connection;

part 'app_database.g.dart';

class UserProfilesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get designation => text().nullable()();
  TextColumn get department => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get organizationId => text().nullable()();
  TextColumn get role => text().withDefault(const Constant('employee'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'user_preferences_user_id_idx', columns: {#userId})
class UserPreferencesTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  // Defaults to 'light' to match `UserPreferences.themeMode`. The app is a
  // workplace tool used on shared and borrowed devices, where a device left in
  // dark mode would otherwise hand a new user a dark screen they did not ask
  // for. 'system' stays available as an explicit choice.
  TextColumn get themeMode => text().withDefault(const Constant('light'))();
  TextColumn get colorSystem =>
      text().withDefault(const Constant(AppColors.defaultAccentId))();
  IntColumn get notificationFrequency =>
      integer().withDefault(const Constant(AppCadence.defaultCadenceMinutes))();
  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get hapticsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get statisticsOptIn =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get aiGuidanceOptIn =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get selectedSound => text().withDefault(const Constant('chime'))();
  TextColumn get quietHours => text().nullable()();
  IntColumn get streakGoal =>
      integer().withDefault(const Constant(AppCadence.defaultDailyGoal))();
  IntColumn get actionWindowMinutes => integer().withDefault(
    const Constant(AppCadence.defaultActionWindowMinutes),
  )();
  BoolColumn get enforceActionWindow =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get preludeEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get preludeMinutes =>
      integer().withDefault(const Constant(AppCadence.defaultPreludeMinutes))();
  BoolColumn get breakBlockingEnabled =>
      boolean().withDefault(const Constant(false))();
  // What the employee said about the guidance they were shown. Stored as text
  // rather than an index so a later category is a Dart change, not a table
  // rewrite; an unrecognised value reads back as `none`.
  TextColumn get guidanceFeedback =>
      text().withDefault(const Constant('none'))();
  // Minutes after the start of the work day when breaks stop being offered.
  // Zero means no cut-off, which is the default: this is a behaviour change the
  // employee asks for, not one an upgrade makes for them.
  IntColumn get dailyLimitMinutes => integer().withDefault(const Constant(0))();
  TextColumn get workDays => text().withDefault(const Constant('1,2,3,4,5'))();
  IntColumn get workStartMinute =>
      integer().withDefault(const Constant(WorkSchedule.defaultStartMinute))();
  IntColumn get workEndMinute =>
      integer().withDefault(const Constant(WorkSchedule.defaultEndMinute))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'reminder_logs_user_timestamp_idx',
  columns: {#userId, #timestamp},
)
@TableIndex(
  name: 'reminder_logs_user_action_timestamp_idx',
  columns: {#userId, #actionTaken, #timestamp},
)
class ReminderLogsTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get scheduledTime => dateTime()();
  TextColumn get actionTaken => text()(); // completed, snoozed, skipped
  IntColumn get snoozeDuration => integer().withDefault(const Constant(0))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get syncedToCloud =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'analytics_daily_user_date_idx', columns: {#userId, #date})
@TableIndex(
  name: 'analytics_daily_user_synced_idx',
  columns: {#userId, #syncedToCloud},
)
class AnalyticsDailyTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get remindersSent => integer().withDefault(const Constant(0))();
  IntColumn get remindersCompleted =>
      integer().withDefault(const Constant(0))();
  IntColumn get remindersSnoozed => integer().withDefault(const Constant(0))();
  IntColumn get remindersSkipped => integer().withDefault(const Constant(0))();
  IntColumn get totalStandTime => integer().withDefault(const Constant(0))();
  TextColumn get organizationId => text().nullable()();
  BoolColumn get syncedToCloud =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    UserProfilesTable,
    UserPreferencesTable,
    ReminderLogsTable,
    AnalyticsDailyTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connection.openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Earlier builds treated statistics contribution as enabled by
        // default. Require an explicit opt-in after this upgrade.
        await customStatement(
          'UPDATE user_preferences_table SET statistics_opt_in = 0',
        );
      }
      if (from < 3) {
        // Add selected_sound, quiet_hours, streak_goal columns
        await customStatement(
          "ALTER TABLE user_preferences_table ADD COLUMN selected_sound TEXT NOT NULL DEFAULT 'chime'",
        );
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN quiet_hours TEXT',
        );
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN streak_goal INTEGER NOT NULL DEFAULT 8',
        );
      }
      if (from < 4) {
        // The action-window rule: a break counts only in the final
        // `action_window_minutes` before each cadence boundary.
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN action_window_minutes INTEGER NOT NULL DEFAULT 5',
        );
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN enforce_action_window INTEGER NOT NULL DEFAULT 1',
        );
      }
      if (from < 5) {
        // Existing preferences receive the confirmed local work schedule.
        await customStatement(
          "ALTER TABLE user_preferences_table ADD COLUMN work_days TEXT NOT NULL DEFAULT '1,2,3,4,5'",
        );
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN work_start_minute INTEGER NOT NULL DEFAULT 540',
        );
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN work_end_minute INTEGER NOT NULL DEFAULT 1020',
        );
      }
      if (from < 6) {
        await customStatement(
          'CREATE INDEX user_preferences_user_id_idx ON user_preferences_table (user_id)',
        );
        await customStatement(
          'CREATE INDEX reminder_logs_user_timestamp_idx ON reminder_logs_table (user_id, timestamp)',
        );
        await customStatement(
          'CREATE INDEX reminder_logs_user_action_timestamp_idx ON reminder_logs_table (user_id, action_taken, timestamp)',
        );
        await customStatement(
          'CREATE INDEX analytics_daily_user_date_idx ON analytics_daily_table (user_id, date)',
        );
        await customStatement(
          'CREATE INDEX analytics_daily_user_synced_idx ON analytics_daily_table (user_id, synced_to_cloud)',
        );
      }
      if (from < 7) {
        // Remote AI is a distinct, explicit opt-in. Existing users remain
        // local-only until they enable it in Settings.
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN ai_guidance_opt_in INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 8) {
        // The prelude warning: a "get ready to stop" notice that fires before
        // each window opens. It is advisory only and does not change whether a
        // break counts, so every existing user keeps the same counting rule and
        // simply gains the warning.
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN prelude_enabled INTEGER NOT NULL DEFAULT 1',
        );
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN prelude_minutes INTEGER NOT NULL DEFAULT 5',
        );
      }
      if (from < 9) {
        // Full-screen break blocking. Defaults to 0 so no existing user has
        // their screen taken over by an upgrade they did not ask for.
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN break_blocking_enabled INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 10) {
        // Explicit guidance feedback. It used to live in memory only, so a
        // "these suggestions come too often" answer stopped steering anything
        // at the next launch. Existing users start at 'none' — no feedback was
        // ever recorded, so nothing is invented for them.
        await customStatement(
          "ALTER TABLE user_preferences_table ADD COLUMN guidance_feedback TEXT NOT NULL DEFAULT 'none'",
        );
      }
      if (from < 11) {
        // The daily cut-off. Defaults to 0 (off) so no existing user loses the
        // reminders they have today: a limit silently applied by an upgrade
        // would end someone's afternoon without them asking for it.
        await customStatement(
          'ALTER TABLE user_preferences_table ADD COLUMN daily_limit_minutes INTEGER NOT NULL DEFAULT 0',
        );
      }
    },
  );
}
