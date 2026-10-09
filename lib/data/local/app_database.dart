import 'package:drift/drift.dart';
import 'package:standup_app/core/app_colors.dart';

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
      integer().withDefault(const Constant(60))();
  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get hapticsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get statisticsOptIn =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get selectedSound => text().withDefault(const Constant('chime'))();
  TextColumn get quietHours => text().nullable()();
  IntColumn get streakGoal => integer().withDefault(const Constant(8))();
  IntColumn get actionWindowMinutes =>
      integer().withDefault(const Constant(5))();
  BoolColumn get enforceActionWindow =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

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
  int get schemaVersion => 4;

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
    },
  );
}
