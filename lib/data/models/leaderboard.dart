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

  static List<LeaderboardEntry> fromDepartments(OrgAnalytics org) {
    final rows = [...org.departmentMetrics]
      ..sort((a, b) => b.totalCompleted.compareTo(a.totalCompleted));

    final topXp = rows.isEmpty ? 1 : rows.first.totalCompleted;
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < rows.length; i++) {
      final department = rows[i];
      entries.add(
        LeaderboardEntry(
          rank: '${i + 1}',
          name: department.department,
          subtitle:
              '${department.activeUsers} • ${(department.adherenceRate * 100).round()}%',
          xp: department.totalCompleted * GamificationMetrics.xpPerBreak,
          progress: topXp <= 0
              ? 0
              : (department.totalCompleted / topXp).clamp(0.0, 1.0),
        ),
      );
    }
    return entries;
  }

  /// Personal bests: the strongest days on record, ranked by completed breaks.
  static List<LeaderboardEntry> fromPersonalHistory(
    List<DailyAnalyticsLike> days,
  ) {
    final sorted = [...days]
      ..sort((a, b) => b.completed.compareTo(a.completed));
    final topXp = sorted.isEmpty ? 1 : sorted.first.completed;
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < sorted.length && i < 7; i++) {
      final day = sorted[i];
      entries.add(
        LeaderboardEntry(
          rank: '${i + 1}',
          name: day.label,
          subtitle: '${day.completed} ${day.unit}',
          xp: day.completed * GamificationMetrics.xpPerBreak,
          progress: topXp <= 0 ? 0 : (day.completed / topXp).clamp(0.0, 1.0),
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
