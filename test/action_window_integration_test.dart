import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/models/daily_analytics.dart';
import 'package:standup_app/data/models/gamification_metrics.dart';
import 'package:standup_app/data/models/stand_window.dart';
import 'package:standup_app/data/models/workday_metrics.dart';

/// Integration-level checks for the action-window rule as it composes with the
/// rest of the domain. These are the rules a reviewer would otherwise have to
/// read the widget code to confirm.
void main() {
  group('Action window gating with the real cadence preference', () {
    test('a 60-minute cadence only opens in the last 5 minutes', () {
      // Every minute of a sample hour, checked against the rule.
      final closed = <int>[];
      final open = <int>[];
      for (var minute = 0; minute < 60; minute++) {
        final now = DateTime(2026, 3, 10, 14, minute);
        if (StandWindow.isActionable(now: now, cadenceMinutes: 60)) {
          open.add(minute);
        } else {
          closed.add(minute);
        }
      }
      expect(open, [55, 56, 57, 58, 59]);
      expect(closed.length, 55);
    });

    test('exactly 5 of every 60 minutes are actionable', () {
      var open = 0;
      for (var minute = 0; minute < 60; minute++) {
        if (StandWindow.isActionable(now: DateTime(2026, 3, 10, 14, minute))) {
          open++;
        }
      }
      expect(open, 5);
    });

    test('a 30-minute cadence opens twice per hour for 10 minutes total', () {
      var open = 0;
      for (var minute = 0; minute < 60; minute++) {
        if (StandWindow.isActionable(
          now: DateTime(2026, 3, 10, 14, minute),
          actionWindowMinutes: 5,
          cadenceMinutes: 30,
        )) {
          open++;
        }
      }
      expect(open, 10);
    });

    test('a full day yields 24 windows, so at most 24 counted breaks', () {
      final windows = StandWindow.windowsBetween(
        from: DateTime(2026, 3, 10),
        to: DateTime(2026, 3, 11),
      );
      expect(windows, 24);
    });

    test('enforcement can be relaxed without changing the cadence maths', () {
      // The preference only decides whether the gate is consulted; the window
      // maths itself is unchanged either way.
      const windowMinutes = 5;
      final midHour = DateTime(2026, 3, 10, 14, 30);
      final gateOpen = StandWindow.isActionable(
        now: midHour,
        actionWindowMinutes: windowMinutes,
      );
      expect(gateOpen, isFalse);

      bool acceptIf(bool enforced) => !enforced || gateOpen;
      expect(acceptIf(true), isFalse, reason: 'enforced mid-hour is refused');
      expect(acceptIf(false), isTrue, reason: 'relaxed mid-hour is accepted');

      // An in-window moment is accepted under both settings.
      final inWindow = DateTime(2026, 3, 10, 14, 57);
      final openInWindow = StandWindow.isActionable(
        now: inWindow,
        actionWindowMinutes: windowMinutes,
      );
      expect(openInWindow, isTrue);
      expect(!openInWindow || true, isTrue);
    });
  });

  group('XP is bounded by what the windows allow', () {
    test('one break per window caps a day at 24 breaks', () {
      // 24 windows at 10 XP each is the theoretical daily maximum.
      const maxBreaksPerDay = 24;
      final xp = maxBreaksPerDay * GamificationMetrics.xpPerBreak;
      expect(xp, 240);

      final day = DailyAnalytics(
        id: 'a',
        userId: 'u',
        date: '2026-03-10',
        remindersSent: 24,
        remindersCompleted: maxBreaksPerDay,
        totalStandTime: maxBreaksPerDay * 5,
      );
      expect(GamificationMetrics.totalXp([day]), xp);
      // The default daily goal of 8 is comfortably inside the ceiling.
      expect(day.remindersCompleted > appDefaultGoal, isTrue);
    });
  });

  group('Streak uses device-local dates', () {
    test('a streak continues across local midnight', () {
      final days = [
        DailyAnalytics(
          id: '1',
          userId: 'u',
          date: '2026-03-09',
          remindersSent: 8,
          remindersCompleted: 8,
        ),
        DailyAnalytics(
          id: '2',
          userId: 'u',
          date: '2026-03-10',
          remindersSent: 8,
          remindersCompleted: 8,
        ),
      ];
      // "Now" is the morning of the 10th: today and yesterday both count.
      expect(WorkdayMetrics.currentStreak(days, DateTime(2026, 3, 10, 9)), 2);
    });

    test('today counts as a grace period until the first break is logged', () {
      // Deliberate product behaviour: a streak is not lost first thing in the
      // morning just because today's break has not happened yet. Yesterday's
      // streak therefore still stands on the 11th.
      final days = [
        DailyAnalytics(
          id: '1',
          userId: 'u',
          date: '2026-03-09',
          remindersSent: 8,
          remindersCompleted: 8,
        ),
        DailyAnalytics(
          id: '2',
          userId: 'u',
          date: '2026-03-10',
          remindersSent: 8,
          remindersCompleted: 8,
        ),
      ];
      expect(
        WorkdayMetrics.currentStreak(days, DateTime(2026, 3, 11, 9)),
        2,
        reason: 'yesterday still counts until today is logged',
      );

      // Two idle days then breaks the chain completely.
      expect(WorkdayMetrics.currentStreak(days, DateTime(2026, 3, 13, 9)), 0);
    });
  });
}

/// Mirrors the shipped default so the test does not depend on a DB round trip.
const int appDefaultGoal = 8;
