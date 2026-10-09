import 'package:drift/drift.dart';
import 'package:standup_app/data/local/app_database.dart';
import 'package:standup_app/data/models/daily_analytics.dart';
import 'package:standup_app/data/models/reminder_log.dart';
import 'package:standup_app/data/models/workday_metrics.dart';
import 'package:standup_app/data/models/user_preferences.dart';
import 'package:standup_app/data/models/user_profile.dart';

class LocalDatabaseRepository {
  final AppDatabase _db;

  LocalDatabaseRepository(this._db);

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------
  Future<UserProfile?> getUserProfile() async {
    final query = _db.select(_db.userProfilesTable)..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return UserProfile(
      id: row.id,
      name: row.name,
      designation: row.designation,
      department: row.department,
      email: row.email,
      organizationId: row.organizationId,
      role: row.role,
      createdAt: row.createdAt,
    );
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _db
        .into(_db.userProfilesTable)
        .insertOnConflictUpdate(
          UserProfilesTableCompanion(
            id: Value(profile.id),
            name: Value(profile.name),
            designation: Value(profile.designation),
            department: Value(profile.department),
            email: Value(profile.email),
            organizationId: Value(profile.organizationId),
            role: Value(profile.role),
            createdAt: Value(profile.createdAt),
          ),
        );
  }

  /// Reassigns this device's local history to the authenticated account.
  /// The operation is atomic so a partial sign-in can never split local data.
  Future<void> reassignLocalUser(
    String localUserId,
    String accountUserId,
  ) async {
    if (localUserId == accountUserId) return;
    await _db.transaction(() async {
      final existingAccount = await (_db.select(
        _db.userProfilesTable,
      )..where((row) => row.id.equals(accountUserId))).getSingleOrNull();
      if (existingAccount != null) {
        throw StateError(
          'This device already has data for another account. Switching between local profiles is not supported yet.',
        );
      }

      await (_db.update(_db.userProfilesTable)
            ..where((row) => row.id.equals(localUserId)))
          .write(UserProfilesTableCompanion(id: Value(accountUserId)));
      await (_db.update(_db.userPreferencesTable)
            ..where((row) => row.userId.equals(localUserId)))
          .write(UserPreferencesTableCompanion(userId: Value(accountUserId)));
      await (_db.update(_db.reminderLogsTable)
            ..where((row) => row.userId.equals(localUserId)))
          .write(ReminderLogsTableCompanion(userId: Value(accountUserId)));
      await (_db.update(
        _db.analyticsDailyTable,
      )..where((row) => row.userId.equals(localUserId))).write(
        AnalyticsDailyTableCompanion(
          userId: Value(accountUserId),
          syncedToCloud: const Value(false),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------------
  Future<UserPreferences?> getUserPreferences(String userId) async {
    final query = _db.select(_db.userPreferencesTable)
      ..where((tbl) => tbl.userId.equals(userId))
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return UserPreferences(
      id: row.id,
      userId: row.userId,
      themeMode: row.themeMode,
      colorSystem: row.colorSystem,
      notificationFrequency: row.notificationFrequency,
      soundEnabled: row.soundEnabled,
      hapticsEnabled: row.hapticsEnabled,
      statisticsOptIn: row.statisticsOptIn,
      onboardingCompleted: row.onboardingCompleted,
      selectedSound: row.selectedSound,
      quietHours: row.quietHours,
      streakGoal: row.streakGoal,
      actionWindowMinutes: row.actionWindowMinutes,
      enforceActionWindow: row.enforceActionWindow,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> saveUserPreferences(UserPreferences prefs) async {
    await _db
        .into(_db.userPreferencesTable)
        .insertOnConflictUpdate(
          UserPreferencesTableCompanion(
            id: Value(prefs.id),
            userId: Value(prefs.userId),
            themeMode: Value(prefs.themeMode),
            colorSystem: Value(prefs.colorSystem),
            notificationFrequency: Value(prefs.notificationFrequency),
            soundEnabled: Value(prefs.soundEnabled),
            hapticsEnabled: Value(prefs.hapticsEnabled),
            statisticsOptIn: Value(prefs.statisticsOptIn),
            onboardingCompleted: Value(prefs.onboardingCompleted),
            selectedSound: Value(prefs.selectedSound),
            quietHours: Value(prefs.quietHours),
            streakGoal: Value(prefs.streakGoal),
            actionWindowMinutes: Value(prefs.actionWindowMinutes),
            enforceActionWindow: Value(prefs.enforceActionWindow),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // Reminder Logs
  // ---------------------------------------------------------------------------
  Future<void> logReminder(ReminderLog log) async {
    await _db
        .into(_db.reminderLogsTable)
        .insert(
          ReminderLogsTableCompanion(
            id: Value(log.id),
            userId: Value(log.userId),
            scheduledTime: Value(log.scheduledTime),
            actionTaken: Value(log.actionTaken),
            snoozeDuration: Value(log.snoozeDuration),
            timestamp: Value(log.timestamp),
            syncedToCloud: Value(log.syncedToCloud),
          ),
        );
  }

  /// Whether the user already completed a break inside the given window.
  ///
  /// This is the durable half of the one-completion-per-window rule. The
  /// in-memory guard in the app state only survives while the isolate lives, so
  /// anything that can restart the app — a launcher widget tap, a cold launch,
  /// a crash — needs this check to read the truth from the database instead.
  ///
  /// The window is matched against [ReminderLogsTable.timestamp], which is when
  /// the action was recorded, because that is the moment the rule is about. A
  /// stretch that began before the window and finished inside it therefore
  /// still counts, while a log from a previous window does not leak in.
  Future<bool> hasCompletedReminderInWindow(
    String userId,
    DateTime windowStart,
    DateTime windowEnd,
  ) async {
    final query = _db.select(_db.reminderLogsTable)
      ..where(
        (tbl) =>
            tbl.userId.equals(userId) &
            tbl.actionTaken.equals('completed') &
            tbl.timestamp.isBiggerOrEqualValue(windowStart) &
            tbl.timestamp.isSmallerThanValue(windowEnd),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  Future<List<ReminderLog>> getRecentSkips(String userId, int count) async {
    final query = _db.select(_db.reminderLogsTable)
      ..where((tbl) => tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
      ..limit(count);
    final rows = await query.get();
    final consecutiveSkips = <ReminderLog>[];
    for (final row in rows) {
      if (row.actionTaken != 'skipped') break;
      consecutiveSkips.add(
        ReminderLog(
          id: row.id,
          userId: row.userId,
          scheduledTime: row.scheduledTime,
          actionTaken: row.actionTaken,
          snoozeDuration: row.snoozeDuration,
          timestamp: row.timestamp,
          syncedToCloud: row.syncedToCloud,
        ),
      );
    }
    return consecutiveSkips;
  }

  Future<List<ReminderLog>> getUnsyncedReminderLogs(String userId) async {
    final query = _db.select(_db.reminderLogsTable)
      ..where(
        (tbl) => tbl.userId.equals(userId) & tbl.syncedToCloud.equals(false),
      );
    final rows = await query.get();
    return rows
        .map(
          (r) => ReminderLog(
            id: r.id,
            userId: r.userId,
            scheduledTime: r.scheduledTime,
            actionTaken: r.actionTaken,
            snoozeDuration: r.snoozeDuration,
            timestamp: r.timestamp,
            syncedToCloud: r.syncedToCloud,
          ),
        )
        .toList();
  }

  Future<void> markLogAsSynced(String logId) async {
    await (_db.update(_db.reminderLogsTable)
          ..where((tbl) => tbl.id.equals(logId)))
        .write(const ReminderLogsTableCompanion(syncedToCloud: Value(true)));
  }

  // ---------------------------------------------------------------------------
  // Daily Analytics
  // ---------------------------------------------------------------------------
  /// Today as the analytics table's date key.
  String getTodayDateString() => WorkdayMetrics.dateKey(DateTime.now());

  Future<DailyAnalytics> getAnalyticsForDate(String userId, String date) async {
    final query = _db.select(_db.analyticsDailyTable)
      ..where((tbl) => tbl.userId.equals(userId) & tbl.date.equals(date))
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) {
      return DailyAnalytics.empty(userId, date);
    }
    return DailyAnalytics(
      id: row.id,
      userId: row.userId,
      date: row.date,
      remindersSent: row.remindersSent,
      remindersCompleted: row.remindersCompleted,
      remindersSnoozed: row.remindersSnoozed,
      remindersSkipped: row.remindersSkipped,
      totalStandTime: row.totalStandTime,
      organizationId: row.organizationId,
      syncedToCloud: row.syncedToCloud,
    );
  }

  /// Applies one action to today's counters.
  ///
  /// The read-modify-write runs inside a transaction so that two concurrent
  /// actions (for example a notification tap racing the guided-stretch
  /// auto-completion, or a realtime merge landing at the same moment) cannot
  /// both read the same starting value and have one increment silently lost.
  Future<DailyAnalytics> updateAnalytics(
    String userId,
    String action, {
    String? orgId,
  }) {
    return _db.transaction(() async {
      final today = getTodayDateString();
      final current = await getAnalyticsForDate(userId, today);

      final sent = current.remindersSent + 1;
      var completed = current.remindersCompleted;
      var snoozed = current.remindersSnoozed;
      var skipped = current.remindersSkipped;

      if (action == 'completed') {
        completed += 1;
      } else if (action == 'snoozed') {
        snoozed += 1;
      } else if (action == 'skipped') {
        skipped += 1;
      }

      final updated = current.copyWith(
        remindersSent: sent,
        remindersCompleted: completed,
        remindersSnoozed: snoozed,
        remindersSkipped: skipped,
        totalStandTime: completed * 5,
        organizationId: orgId ?? current.organizationId,
        syncedToCloud: false,
      );

      await saveAnalyticsRecord(updated);
      return updated;
    });
  }

  Future<void> saveAnalyticsRecord(DailyAnalytics record) async {
    await _db
        .into(_db.analyticsDailyTable)
        .insertOnConflictUpdate(
          AnalyticsDailyTableCompanion(
            id: Value(record.id),
            userId: Value(record.userId),
            date: Value(record.date),
            remindersSent: Value(record.remindersSent),
            remindersCompleted: Value(record.remindersCompleted),
            remindersSnoozed: Value(record.remindersSnoozed),
            remindersSkipped: Value(record.remindersSkipped),
            totalStandTime: Value(record.totalStandTime),
            organizationId: Value(record.organizationId),
            syncedToCloud: Value(record.syncedToCloud),
          ),
        );
  }

  Future<DailyAnalytics> mergeRemoteAnalytics(DailyAnalytics remote) async {
    final local = await getAnalyticsForDate(remote.userId, remote.date);
    final merged = local.copyWith(
      remindersSent: local.remindersSent > remote.remindersSent
          ? local.remindersSent
          : remote.remindersSent,
      remindersCompleted: local.remindersCompleted > remote.remindersCompleted
          ? local.remindersCompleted
          : remote.remindersCompleted,
      remindersSnoozed: local.remindersSnoozed > remote.remindersSnoozed
          ? local.remindersSnoozed
          : remote.remindersSnoozed,
      remindersSkipped: local.remindersSkipped > remote.remindersSkipped
          ? local.remindersSkipped
          : remote.remindersSkipped,
      totalStandTime: local.totalStandTime > remote.totalStandTime
          ? local.totalStandTime
          : remote.totalStandTime,
      organizationId: remote.organizationId ?? local.organizationId,
      syncedToCloud: true,
    );
    await saveAnalyticsRecord(merged);
    return merged;
  }

  Future<List<DailyAnalytics>> getAllDailyAnalytics(String userId) async {
    final query = _db.select(_db.analyticsDailyTable)
      ..where((tbl) => tbl.userId.equals(userId))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.date)]);
    final rows = await query.get();
    return rows
        .map(
          (r) => DailyAnalytics(
            id: r.id,
            userId: r.userId,
            date: r.date,
            remindersSent: r.remindersSent,
            remindersCompleted: r.remindersCompleted,
            remindersSnoozed: r.remindersSnoozed,
            remindersSkipped: r.remindersSkipped,
            totalStandTime: r.totalStandTime,
            organizationId: r.organizationId,
            syncedToCloud: r.syncedToCloud,
          ),
        )
        .toList();
  }

  Future<List<DailyAnalytics>> getUnsyncedAnalytics(String userId) async {
    final query = _db.select(_db.analyticsDailyTable)
      ..where(
        (tbl) => tbl.userId.equals(userId) & tbl.syncedToCloud.equals(false),
      );
    final rows = await query.get();
    return rows
        .map(
          (r) => DailyAnalytics(
            id: r.id,
            userId: r.userId,
            date: r.date,
            remindersSent: r.remindersSent,
            remindersCompleted: r.remindersCompleted,
            remindersSnoozed: r.remindersSnoozed,
            remindersSkipped: r.remindersSkipped,
            totalStandTime: r.totalStandTime,
            organizationId: r.organizationId,
            syncedToCloud: r.syncedToCloud,
          ),
        )
        .toList();
  }

  Future<void> markAnalyticAsSynced(String id) async {
    await (_db.update(_db.analyticsDailyTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(const AnalyticsDailyTableCompanion(syncedToCloud: Value(true)));
  }

  Future<void> markAllAnalyticsAsUnsynced(String userId) async {
    await (_db.update(_db.analyticsDailyTable)
          ..where((tbl) => tbl.userId.equals(userId)))
        .write(const AnalyticsDailyTableCompanion(syncedToCloud: Value(false)));
  }
}
