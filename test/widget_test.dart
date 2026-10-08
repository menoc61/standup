import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/data/models/daily_analytics.dart';
import 'package:standup_app/data/models/reminder_log.dart';
import 'package:standup_app/data/models/user_preferences.dart';
import 'package:standup_app/ui/widgets/countdown_ring.dart';
import 'package:standup_app/ui/widgets/posture_avatar.dart';
import 'package:standup_app/ui/widgets/contribution_heatmap_widget.dart';

void main() {
  group('Domain Models Test', () {
    test('DailyAnalytics adherence and status calculation', () {
      final analytics = DailyAnalytics(
        id: 'test_1',
        userId: 'u123',
        date: '2026-10-07',
        remindersSent: 8,
        remindersCompleted: 6,
        remindersSnoozed: 1,
        remindersSkipped: 1,
        totalStandTime: 30,
      );

      expect(analytics.adherenceRate, 75.0);
      expect(analytics.heatmapStatus, 'completed');
      expect(analytics.totalStandTime, 30);
    });

    test('UserPreferences default and copyWith', () {
      final prefs = UserPreferences.defaultPreferences('user_1');
      expect(prefs.notificationFrequency, 60);
      // The default accent follows the logo. Asserted explicitly so a change of
      // default is a deliberate edit rather than an accident.
      expect(prefs.colorSystem, 'brand');
      expect(prefs.colorSystem, AppColors.defaultAccentId);
      expect(prefs.soundEnabled, true);

      final updated = prefs.copyWith(
        notificationFrequency: 30,
        colorSystem: 'violet',
      );
      expect(updated.notificationFrequency, 30);
      expect(updated.colorSystem, 'violet');
    });

    test('a retired accent id falls back to the brand on load', () {
      // Profiles created before the rebrand still store 'emerald'. Loading one
      // must not put the user back into the palette they moved away from.
      final legacy = UserPreferences.fromJson({
        'id': 'p1',
        'user_id': 'user_1',
        'color_system': 'emerald',
      });
      expect(legacy.colorSystem, 'brand');
    });

    test('normalizeAccent keeps current ids and repairs the rest', () {
      expect(normalizeAccent('violet'), 'violet');
      expect(normalizeAccent('brand'), 'brand');
      expect(normalizeAccent('emerald'), 'brand');
      expect(normalizeAccent('coral'), 'brand');
      expect(normalizeAccent(''), 'brand');
      expect(normalizeAccent(null), 'brand');
    });

    test('ReminderLog serialization', () {
      final now = DateTime.now();
      final log = ReminderLog(
        id: 'log_1',
        userId: 'u1',
        scheduledTime: now,
        actionTaken: 'completed',
        snoozeDuration: 0,
      );

      expect(log.isCompleted, true);
      expect(log.isSnoozed, false);
      expect(log.isSkipped, false);

      final json = log.toJson();
      final fromJson = ReminderLog.fromJson(json);
      expect(fromJson.id, 'log_1');
      expect(fromJson.actionTaken, 'completed');
    });
  });

  group('Widget Smoke Tests', () {
    testWidgets('CountdownRing renders time properly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountdownRing(
              remainingTime: Duration(minutes: 45, seconds: 30),
              progress: 0.25,
              accentColor: AppColors.emeraldAccent,
            ),
          ),
        ),
      );

      expect(find.text('45:30'), findsOneWidget);
      expect(find.text('FOCUS CADENCE'), findsOneWidget);
    });

    testWidgets('PostureAvatar renders without error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PostureAvatar(
              isStanding: true,
              stretchProgress: 0.5,
              accentColor: AppColors.emeraldAccent,
            ),
          ),
        ),
      );

      expect(find.byType(PostureAvatar), findsOneWidget);
    });

    testWidgets('ContributionHeatmapWidget renders cells and legend', (
      WidgetTester tester,
    ) async {
      final sampleData = [
        DailyAnalytics(
          id: '1',
          userId: 'u1',
          date: '2026-10-07',
          remindersSent: 8,
          remindersCompleted: 7,
          totalStandTime: 35,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContributionHeatmapWidget(
              dailyData: sampleData,
              weeksToShow: 12,
            ),
          ),
        ),
      );

      expect(find.text('Less'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
    });
  });
}
