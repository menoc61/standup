import 'gamification_metrics.dart';
import 'org_analytics.dart';

/// One row in the standings.
class LeaderboardEntry {
  final String rank;
  final String name;
  final String? subtitle;
  final int xp;
  final double progress;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.xp,
    required this.progress,
    this.subtitle,
    this.isCurrentUser = false,
  });
}

/// Builds the weekly standings.
///
/// Online, the board ranks the anonymized department aggregates the app is
/// already allowed to read through `org_analytics_daily`; individual members
/// are never exposed, which keeps the existing privacy contract intact.
/// Offline, it falls back to the employee's own best days so the tab still
/// shows something meaningful.
class LeaderboardBuilder {
  const LeaderboardBuilder._();

  /// Ranks are competition-style throughout this file: two rows on the same
  /// score share a rank and the following rank skips, the way a sports table
  /// does. Numbering strictly by position printed "2" and "3" for an identical
  /// pair, which quietly implied one was ahead of the other.
  static List<LeaderboardEntry> fromDepartments(OrgAnalytics org) {
    final rows =
        org.departmentMetrics
            // A department with no breaks is not "in last place", it simply has no
            // data yet. Dropping it keeps the board meaningful.
            .where((d) => d.totalCompleted > 0)
            .toList()
          ..sort((a, b) => b.totalCompleted.compareTo(a.totalCompleted));

    if (rows.isEmpty) return const [];

    final topScore = rows.first.totalCompleted;
    final entries = <LeaderboardEntry>[];
    var previousScore = -1;
    var lastRank = 1;

    for (var i = 0; i < rows.length; i++) {
      final department = rows[i];
      final score = department.totalCompleted;

      lastRank = i == 0 || score != previousScore ? i + 1 : lastRank;
      previousScore = score;

      entries.add(
        LeaderboardEntry(
          rank: '$lastRank',
          name: department.department,
          subtitle:
              '${department.activeUsers} • ${(department.adherenceRate * 100).round()}%',
          xp: score * GamificationMetrics.xpPerBreak,
          progress: topScore <= 0 ? 0 : (score / topScore).clamp(0.0, 1.0),
        ),
      );
    }
    return entries;
  }

  /// Personal bests: the strongest days on record, ranked by completed breaks.
  ///
  /// Days with no completed breaks are excluded. Ranking them alongside real
  /// achievements was the clearest defect on this screen: an empty history made
  /// the board a list of zeros, which reads as either a bug or an accusation.
  static List<LeaderboardEntry> fromPersonalHistory(
    List<DailyAnalyticsLike> days,
  ) {
    final sorted = days.where((d) => d.completed > 0).toList()
      ..sort((a, b) {
        // Strongest day first; ties broken by date so the order is stable
        // between rebuilds rather than depending on database row order.
        final byScore = b.completed.compareTo(a.completed);
        if (byScore != 0) return byScore;
        return a.label.compareTo(b.label);
      });

    if (sorted.isEmpty) return const [];

    final topScore = sorted.first.completed;
    final entries = <LeaderboardEntry>[];
    var previousScore = -1;
    var lastRank = 1;

    for (var i = 0; i < sorted.length && i < 7; i++) {
      final day = sorted[i];
      final score = day.completed;

      lastRank = i == 0 || score != previousScore ? i + 1 : lastRank;
      previousScore = score;

      entries.add(
        LeaderboardEntry(
          rank: '$lastRank',
          name: day.label,
          subtitle: '${day.completed} ${day.unit}',
          xp: score * GamificationMetrics.xpPerBreak,
          progress: topScore <= 0 ? 0 : (score / topScore).clamp(0.0, 1.0),
          isCurrentUser: day.isCurrentUser,
        ),
      );
    }
    return entries;
  }
}

/// Minimal view of a daily record so the leaderboard does not need to know how
/// analytics are stored.
class DailyAnalyticsLike {
  final String label;
  final int completed;
  final String unit;
  final bool isCurrentUser;

  const DailyAnalyticsLike({
    required this.label,
    required this.completed,
    required this.unit,
    this.isCurrentUser = false,
  });
}
