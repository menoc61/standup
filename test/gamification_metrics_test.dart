import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/models/daily_analytics.dart';
import 'package:standup_app/data/models/gamification_metrics.dart';

void main() {
  DailyAnalytics day(String date, {int completed = 0}) => DailyAnalytics(
    id: 'id_$date',
    userId: 'user',
    date: date,
    remindersSent: completed,
    remindersCompleted: completed,
  );

  group('GamificationMetrics', () {
    test('awards ten XP per completed break', () {
      final days = [
        day('2026-01-01', completed: 3),
        day('2026-01-02', completed: 2),
      ];
      expect(GamificationMetrics.totalXp(days), 50);
    });

    test('starts at level one and advances as XP accumulates', () {
      expect(GamificationMetrics.levelFor(0), 1);
      expect(GamificationMetrics.levelFor(99), 1);
      expect(GamificationMetrics.levelFor(100), 2);
      // Level 2 requires 150 XP, so 250 XP is partway through level 3.
      expect(GamificationMetrics.levelFor(250), 3);
    });

    test('reports progress within the current level', () {
      expect(GamificationMetrics.levelProgress(0), 0);
      expect(GamificationMetrics.levelProgress(50), closeTo(0.5, 0.001));
      expect(GamificationMetrics.levelProgress(150), closeTo(1 / 3, 0.001));
    });

    test('reports remaining XP to the next level', () {
      expect(GamificationMetrics.xpToNextLevel(0), 100);
      expect(GamificationMetrics.xpToNextLevel(40), 60);
      expect(GamificationMetrics.xpToNextLevel(100), 150);
    });

    test('caps daily goal progress and detects completion', () {
      expect(GamificationMetrics.dailyGoalProgress(day('2026-01-01'), 8), 0);
      expect(
        GamificationMetrics.dailyGoalProgress(
          day('2026-01-01', completed: 12),
          8,
        ),
        1.0,
      );
      expect(
        GamificationMetrics.dailyGoalMet(day('2026-01-01', completed: 8), 8),
        isTrue,
      );
      expect(
        GamificationMetrics.dailyGoalMet(day('2026-01-01', completed: 3), 8),
        isFalse,
      );
    });
  });
}
