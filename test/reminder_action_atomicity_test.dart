import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/local/app_database.dart';
import 'package:standup_app/data/local/local_repository.dart';
import 'package:standup_app/data/models/reminder_log.dart';

void main() {
  late AppDatabase db;
  late LocalDatabaseRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalDatabaseRepository(db);
  });

  tearDown(() => db.close());

  test(
    'concurrent completion attempts claim a window and count once',
    () async {
      final start = DateTime(2026, 10, 13, 11, 55);
      final end = DateTime(2026, 10, 13, 12);
      final timestamp = DateTime(2026, 10, 13, 11, 57);

      Future<dynamic> record(String id) => repository.recordReminderAction(
        ReminderLog(
          id: id,
          userId: 'user-1',
          scheduledTime: timestamp,
          timestamp: timestamp,
          actionTaken: 'completed',
        ),
        completionWindowStart: start,
        completionWindowEnd: end,
        standMinutes: 7,
      );

      final results = await Future.wait([record('first'), record('second')]);

      expect(results.where((result) => result != null), hasLength(1));
      final analytics = await repository.getAnalyticsForDate(
        'user-1',
        '2026-10-13',
      );
      expect(analytics.remindersSent, 1);
      expect(analytics.remindersCompleted, 1);
      expect(analytics.totalStandTime, 7);
      expect(
        await repository.hasCompletedReminderInWindow('user-1', start, end),
        isTrue,
      );
    },
  );

  test('snooze event and its daily counter commit together', () async {
    final timestamp = DateTime(2026, 10, 13, 11, 30);
    final analytics = await repository.recordReminderAction(
      ReminderLog(
        id: 'snooze-1',
        userId: 'user-1',
        scheduledTime: timestamp,
        timestamp: timestamp,
        actionTaken: 'snoozed',
        snoozeDuration: 30,
      ),
    );

    expect(analytics?.remindersSent, 1);
    expect(analytics?.remindersSnoozed, 1);
  });

  test('the window lookup is scoped to the window it is asked about', () async {
    // `AppState._hydrateActedWindow` uses this query to decide whether the
    // current window was already logged, and a `true` in the wrong window would
    // silently switch the forced break off for a break nobody took.
    final completed = DateTime(2026, 10, 13, 11, 57);
    await repository.recordReminderAction(
      ReminderLog(
        id: 'completed-1',
        userId: 'user-1',
        scheduledTime: completed,
        timestamp: completed,
        actionTaken: 'completed',
      ),
      completionWindowStart: DateTime(2026, 10, 13, 11, 55),
      completionWindowEnd: DateTime(2026, 10, 13, 12),
      standMinutes: 5,
    );

    expect(
      await repository.hasCompletedReminderInWindow(
        'user-1',
        DateTime(2026, 10, 13, 11, 55),
        DateTime(2026, 10, 13, 12),
      ),
      isTrue,
      reason: 'the window the break was logged in',
    );
    expect(
      await repository.hasCompletedReminderInWindow(
        'user-1',
        DateTime(2026, 10, 13, 12, 55),
        DateTime(2026, 10, 13, 13),
      ),
      isFalse,
      reason: 'a later window must not inherit the earlier completion',
    );
    expect(
      await repository.hasCompletedReminderInWindow(
        'user-2',
        DateTime(2026, 10, 13, 11, 55),
        DateTime(2026, 10, 13, 12),
      ),
      isFalse,
      reason: 'another account on the same device has its own record',
    );
  });
}
