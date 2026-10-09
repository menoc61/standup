import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/data/remote/supabase_service.dart';
import 'package:standup_app/data/models/workday_metrics.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/ui/widgets/analytics_charts.dart';
import 'package:standup_app/ui/widgets/contribution_heatmap_widget.dart';
import 'package:standup_app/ui/widgets/glass_card.dart';

class AnalyticsScreen extends StatelessWidget {
  final AppState appState;

  const AnalyticsScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.getAccentColor(appState.preferences.colorSystem);
    final history = appState.dailyHistory;

    // Aggregates
    int totalCompleted = 0;
    int totalSnoozed = 0;
    int totalSkipped = 0;
    int totalMinutes = 0;
    for (final day in history) {
      totalCompleted += day.remindersCompleted;
      totalSnoozed += day.remindersSnoozed;
      totalSkipped += day.remindersSkipped;
      totalMinutes += day.totalStandTime;
    }
    final totalReminders = totalCompleted + totalSnoozed + totalSkipped;
    final adherence = totalReminders > 0
        ? (totalCompleted / totalReminders) * 100
        : 0.0;
    final averageMinutes = WorkdayMetrics.averageStandMinutesPerActiveDay(
      history,
    );
    final activeDays = history.where((day) => day.remindersSent > 0).length;
    final dailyTarget = WorkdayMetrics.standTargetMinutes(
      appState.preferences.notificationFrequency,
    );
    final streak = WorkdayMetrics.currentStreak(history, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(appString(context, 'Wellness Analytics')),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: appString(context, 'Sync to Supabase'),
            onPressed: () => appState.triggerCloudSync(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => await appState.triggerCloudSync(),
          color: accent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cloud Sync Status Pill
                //
                // Expanded on the title: the French badge copy is far longer than
                // the English ("Hors ligne tant que Supabase Auth n'est pas
                // configuré"), so two unbounded texts in a spaceBetween Row
                // overflow at phone widths.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appString(context, 'Consistency & Adherence'),
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _buildSyncStatusBadge(
                        context,
                        appState.syncStatus,
                        accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Top Key Metric Cards Row
                Row(
                  children: [
                    _buildMetricCard(
                      context,
                      title: appString(context, 'Adherence'),
                      value: '${adherence.toStringAsFixed(0)}%',
                      subtitle: appString(context, 'Completed breaks'),
                      icon: Icons.check_circle_outline,
                      color: AppColors.completed,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      context,
                      title: appString(context, 'Average Stand / Day'),
                      value: '${averageMinutes.round()} min',
                      subtitle:
                          '$totalMinutes min ${appString(context, 'total')} · $dailyTarget min / 8h',
                      icon: Icons.timer_outlined,
                      color: accent,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      context,
                      title: appString(context, 'Current Streak'),
                      value: '$streak ${appString(context, 'days')}',
                      subtitle:
                          '$activeDays ${appString(context, 'tracked days')}',
                      icon: Icons.local_fire_department,
                      color: AppColors.snoozed,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Section 1: GitHub-Style Contribution Heatmap
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appString(context, 'Contribution Heatmap'),
                                  style: theme.textTheme.titleMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  appString(
                                    context,
                                    'GitHub-style hourly movement matrix',
                                  ),
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.completed.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$totalCompleted ${appString(context, 'stands')}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.completed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ContributionHeatmapWidget(
                        dailyData: history,
                        weeksToShow: 20,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        appString(
                          context,
                          'Tap any square to inspect details. Green: completed • Amber: snoozed • Red: skipped',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 2: Weekly Adherence Bar Chart
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appString(context, 'Weekly Cadence Breakdown'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appString(
                          context,
                          'Daily completed vs snoozed vs skipped',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      WeeklyAdherenceBarChart(
                        dailyData: history,
                        accentColor: accent,
                      ),
                      const SizedBox(height: 12),
                      // Wrap rather than Row: three legend entries do not fit
                      // side by side on a 320px phone, and the French labels are
                      // longer than the English ones. A Row would overflow; a
                      // Wrap reflows onto a second line instead.
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildLegendDot(
                            AppColors.completed,
                            appString(context, 'Completed'),
                          ),
                          _buildLegendDot(
                            AppColors.snoozed,
                            appString(context, 'Snoozed (10m)'),
                          ),
                          _buildLegendDot(
                            AppColors.skipped,
                            appString(context, 'Skipped'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 3: 30-Day Trend Line Chart
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appString(context, 'Stand Duration Trend'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appString(
                          context,
                          'Active minutes per day over past 14 days',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      TrendStandDurationLineChart(
                        dailyData: history,
                        accentColor: accent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Distribution Card
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appString(context, 'Action Distribution'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 12,
                          child: Row(
                            children: [
                              if (totalCompleted > 0)
                                Expanded(
                                  flex: totalCompleted,
                                  child: Container(color: AppColors.completed),
                                ),
                              if (totalSnoozed > 0)
                                Expanded(
                                  flex: totalSnoozed,
                                  child: Container(color: AppColors.snoozed),
                                ),
                              if (totalSkipped > 0)
                                Expanded(
                                  flex: totalSkipped,
                                  child: Container(color: AppColors.skipped),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Wrap, like the legend above it: the French labels are
                      // longer than the English ones and three non-flex children
                      // in a spaceBetween Row overflow once the total exceeds the
                      // card width.
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          _buildDistItem(
                            appString(context, 'Completed'),
                            totalCompleted,
                            AppColors.completed,
                          ),
                          _buildDistItem(
                            appString(context, 'Snoozed'),
                            totalSnoozed,
                            AppColors.snoozed,
                          ),
                          _buildDistItem(
                            appString(context, 'Skipped'),
                            totalSkipped,
                            AppColors.skipped,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusBadge(
    BuildContext context,
    SyncStatus status,
    Color accent,
  ) {
    String text;
    Color col;
    IconData icon;

    switch (status) {
      case SyncStatus.syncing:
        text = appString(context, 'Syncing...');
        col = AppColors.snoozed;
        icon = Icons.sync;
        break;
      case SyncStatus.success:
        text = appString(context, 'Supabase Synced');
        col = AppColors.completed;
        icon = Icons.cloud_done;
        break;
      case SyncStatus.offline:
        text = appString(context, 'Offline Queue');
        col = Colors.grey;
        icon = Icons.cloud_off;
        break;
      case SyncStatus.error:
        text = appString(context, 'Sync Pending');
        col = AppColors.skipped;
        icon = Icons.sync_problem;
        break;
      case SyncStatus.idle:
        text = appString(context, 'Cloud Connected');
        col = accent;
        icon = Icons.cloud;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: col),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: col,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: BorderRadius.circular(18),
        blur: 8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDistItem(String label, int count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
