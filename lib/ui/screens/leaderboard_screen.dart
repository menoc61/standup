import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/data/models/daily_analytics.dart';
import 'package:standup_app/data/models/gamification_metrics.dart';
import 'package:standup_app/data/models/leaderboard.dart';
import 'package:standup_app/data/models/workday_metrics.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/ui/widgets/glass_card.dart';

class LeaderboardScreen extends StatelessWidget {
  final AppState appState;

  const LeaderboardScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final prefs = appState.preferences;
    final today = appState.todayAnalytics;
    final history = appState.dailyHistory;

    final totalXp = GamificationMetrics.totalXp(history);
    final level = GamificationMetrics.levelFor(totalXp);
    final levelProgress = GamificationMetrics.levelProgress(totalXp);
    final xpToNext = GamificationMetrics.xpToNextLevel(totalXp);
    final streak = WorkdayMetrics.currentStreak(history, DateTime.now());
    final goalProgress = GamificationMetrics.dailyGoalProgress(
      today,
      prefs.streakGoal,
    );

    final online = appState.orgAnalytics != null;
    final entries = online
        ? LeaderboardBuilder.fromDepartments(appState.orgAnalytics!)
        : _personalEntries(context, history, today.remindersCompleted);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => appState.triggerCloudSync(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: [
              // Level & XP hero
              _LevelHero(
                level: level,
                progress: levelProgress,
                xp: totalXp,
                xpToNext: xpToNext,
                accent: accent,
              ),
              const SizedBox(height: 16),

              // Daily goal + streak
              Row(
                children: [
                  Expanded(
                    child: _GoalCard(
                      progress: goalProgress,
                      completed: today.remindersCompleted,
                      goal: prefs.streakGoal,
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StreakCard(streak: streak, accent: accent),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Standings
              Text(
                appString(context, 'Weekly ranking'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                online
                    ? appString(
                        context,
                        'Department standings from anonymized daily totals.',
                      )
                    : appString(
                        context,
                        'Offline — showing your personal bests',
                      ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),

              if (entries.isEmpty)
                GlassCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        appString(
                          context,
                          'Complete your first break to join the standings.',
                        ),
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                ...entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LeaderboardRow(
                      entry: row,
                      accent: accent,
                      medal: index < 3 ? index : null,
                    ),
                  );
                }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  List<LeaderboardEntry> _personalEntries(
    BuildContext context,
    List<DailyAnalytics> history,
    int todayCompleted,
  ) {
    final formatter = DateFormat('MMM d');
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final rows = history
        .map(
          (d) => DailyAnalyticsLike(
            label: formatter.format(DateTime.parse('${d.date}T00:00:00')),
            completed: d.remindersCompleted,
            unit: appString(context, 'breaks'),
            isCurrentUser: d.date == todayKey,
          ),
        )
        .toList();

    if (todayCompleted > 0 && !rows.any((r) => r.isCurrentUser)) {
      rows.insert(
        0,
        DailyAnalyticsLike(
          label: formatter.format(today),
          completed: todayCompleted,
          unit: appString(context, 'breaks'),
          isCurrentUser: true,
        ),
      );
    }
    return LeaderboardBuilder.fromPersonalHistory(rows);
  }
}

class _LevelHero extends StatelessWidget {
  final int level;
  final double progress;
  final int xp;
  final int xpToNext;
  final Color accent;

  const _LevelHero({
    required this.level,
    required this.progress,
    required this.xp,
    required this.xpToNext,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${appString(context, 'Level')} $level',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$xp ${appString(context, 'XP')} • $xpToNext ${appString(context, 'XP')} ${appString(context, 'to next level')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(height: 10, color: accent.withValues(alpha: 0.15)),
                FractionallySizedBox(
                  widthFactor: progress <= 0 ? 0.01 : progress,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.65)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final double progress;
  final int completed;
  final int goal;
  final Color accent;

  const _GoalCard({
    required this.progress,
    required this.completed,
    required this.goal,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress <= 0 ? 0.001 : progress,
                  strokeWidth: 5,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
                Text(
                  '$completed',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            appString(context, 'Daily stand goal'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          Text('$completed / $goal', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final Color accent;

  const _StreakCard({required this.streak, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 34,
            color: streak > 0 ? Colors.orange.shade700 : accent,
          ),
          const SizedBox(height: 10),
          Text(
            appString(context, 'Day streak'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          Text('$streak', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final Color accent;
  final int? medal;

  const _LeaderboardRow({
    required this.entry,
    required this.accent,
    this.medal,
  });

  static const _medalColors = [
    Color(0xFFD4AF37),
    Color(0xFFB8C0C7),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      tintColor: entry.isCurrentUser ? accent.withValues(alpha: 0.1) : null,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: medal != null && medal! < 3
                ? Icon(
                    Icons.emoji_events_rounded,
                    color: _medalColors[medal!],
                    size: 22,
                  )
                : Text(
                    entry.rank,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isCurrentUser
                      ? '${entry.name} • ${appString(context, 'You')}'
                      : entry.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.subtitle != null && entry.subtitle!.isNotEmpty)
                  Text(entry.subtitle!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              '${entry.xp}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
