import 'daily_analytics.dart';

/// Duolingo-inspired progression: completed breaks earn XP, XP fills levels,
/// and a daily goal ring keeps the loop visible. All of this is computed from
/// the local analytics history, so it works offline and syncs implicitly.
class GamificationMetrics {
  const GamificationMetrics._();

  /// XP awarded per completed five-minute break.
  static const int xpPerBreak = 10;

  /// XP awarded for finishing the daily stand goal.
  static const int dailyGoalBonusXp = 25;

  /// XP needed to reach level 1, then grows by a fixed step per level.
  static const int baseXpPerLevel = 100;
  static const int xpStepPerLevel = 50;

  /// Total XP across all completed breaks, plus any daily-goal bonuses already
  /// captured. This is derived from history so it survives reinstalls of state.
  static int totalXp(Iterable<DailyAnalytics> days) {
    var xp = 0;
    for (final day in days) {
      xp += day.remindersCompleted * xpPerBreak;
    }
    return xp;
  }

  /// The level a given XP total corresponds to (starting at 1).
  static int levelFor(int xp) {
    var level = 1;
    var spent = 0;
    while (xp - spent >= xpRequiredFor(level)) {
      spent += xpRequiredFor(level);
      level++;
    }
    return level;
  }

  /// XP needed to advance from [level] to the next one.
  static int xpRequiredFor(int level) =>
      baseXpPerLevel + (level - 1) * xpStepPerLevel;

  /// Progress within the current level, from 0.0 to 1.0.
  static double levelProgress(int xp) {
    final level = levelFor(xp);
    var spent = 0;
    for (var l = 1; l < level; l++) {
      spent += xpRequiredFor(l);
    }
    final intoLevel = xp - spent;
    final required = xpRequiredFor(level);
    return required <= 0 ? 0 : (intoLevel / required).clamp(0.0, 1.0);
  }

  /// XP still required to reach the next level.
  static int xpToNextLevel(int xp) {
    final level = levelFor(xp);
    var spent = 0;
    for (var l = 1; l < level; l++) {
      spent += xpRequiredFor(l);
    }
    final intoLevel = xp - spent;
    return (xpRequiredFor(level) - intoLevel).clamp(0, 1 << 31);
  }

  /// Progress toward the daily stand goal, from 0.0 to 1.0.
  static double dailyGoalProgress(DailyAnalytics today, int goal) {
    if (goal <= 0) return 0;
    return (today.remindersCompleted / goal).clamp(0.0, 1.0);
  }

  /// True once today's completed breaks meet or exceed the goal.
  static bool dailyGoalMet(DailyAnalytics today, int goal) =>
      goal > 0 && today.remindersCompleted >= goal;
}
