import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_spacing.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/ui/layout/adaptive.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/ui/widgets/glass_card.dart';

class OrgAdminScreen extends StatelessWidget {
  final AppState appState;

  const OrgAdminScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = AppColors.getAccentColor(appState.preferences.colorSystem);
    final org = appState.orgAnalytics;
    if (org == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(appString(context, 'Organization Insights')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 42),
                const SizedBox(height: AppSpace.xxl),
                Text(
                  appString(context, 'Organization insights are unavailable'),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  appString(
                    context,
                    'This requires a Supabase account with an organization administrator role and a linked workspace.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appString(context, 'Organization Insights')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => appState.triggerCloudSync(),
            tooltip: appString(context, 'Refresh Org Aggregates'),
          ),
        ],
      ),
      body: SafeArea(
        // This screen is a pushed route, so it sits outside the shell's
        // constrainContent. Without a ceiling the two-up stat rows stretch to
        // the full width of a desktop window.
        child: constrainContent(
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.huge,
              vertical: AppSpace.xl,
            ),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Organization Header Card
                Container(
                  padding: const EdgeInsets.all(AppSpace.huge),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.18),
                        accent.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // The organisation name is user-supplied and can be
                          // arbitrarily long; an unbounded Text next to a fixed
                          // badge overflows on a narrow screen.
                          Expanded(
                            child: Text(
                              org.organizationName,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.md,
                              vertical: AppSpace.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.completed.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              appString(context, 'ADMIN VIEW'),
                              style: TextStyle(
                                fontSize: AppFontSize.micro,
                                fontWeight: FontWeight.bold,
                                color: AppColors.completed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        appString(
                          context,
                          'Aggregated anonymized health benchmarks powered by Supabase views.',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpace.xxl),
                      // Privacy Guarantee Shield Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.lg,
                          vertical: AppSpace.sm,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black38 : Colors.white60,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_user,
                              color: AppColors.completed,
                              size: 14,
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Text(
                                appString(
                                  context,
                                  'Privacy-Enforced: RLS hides individual timestamps & employee names.',
                                ),
                                style: TextStyle(
                                  fontSize: AppFontSize.micro,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.huge),

                // Key Benchmark Figures
                Row(
                  children: [
                    _buildStatCard(
                      context,
                      title: appString(context, 'Active Employees'),
                      value: '${org.activeUsers}',
                      subtitle: appString(context, 'Enrolled teammates'),
                      icon: Icons.people_outline,
                      color: accent,
                    ),
                    const SizedBox(width: AppSpace.xl),
                    _buildStatCard(
                      context,
                      title: appString(context, 'Org Completion Rate'),
                      value: '${org.adherenceRate.toStringAsFixed(1)}%',
                      subtitle: appString(context, 'Of recorded actions'),
                      icon: Icons.trending_up,
                      color: AppColors.completed,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                Row(
                  children: [
                    _buildStatCard(
                      context,
                      title: appString(context, 'Stands Logged'),
                      value: '${org.totalCompleted}',
                      subtitle:
                          '${org.totalStandMinutes} ${appString(context, 'mins movement')}',
                      icon: Icons.accessibility_new,
                      color: accent,
                    ),
                    const SizedBox(width: AppSpace.xl),
                    _buildStatCard(
                      context,
                      title: appString(context, 'Skipped Breaks'),
                      value: '${org.totalSkipped}',
                      subtitle:
                          '${org.totalSnoozed} ${appString(context, 'snoozed')}',
                      icon: Icons.alarm_off,
                      color: AppColors.snoozed,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.section),

                // Department Leaderboard
                Text(
                  appString(context, 'Department Completion Leaderboard'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpace.xl),
                ...org.departmentMetrics.map((dept) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.lg),
                    child: GlassCard(
                      padding: const EdgeInsets.all(AppSpace.xxl),
                      borderRadius: BorderRadius.circular(18),
                      blur: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: AppSpace.lg,
                                      height: AppSpace.lg,
                                      decoration: BoxDecoration(
                                        color: dept.adherenceRate >= 85
                                            ? AppColors.completed
                                            : (dept.adherenceRate >= 80
                                                  ? accent
                                                  : AppColors.snoozed),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpace.lg),
                                    // Department names come from the database, so
                                    // their length is not ours to bound.
                                    Expanded(
                                      child: Text(
                                        dept.department,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: AppFontSize.body,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpace.md),
                              Text(
                                '${dept.adherenceRate.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.lg),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            child: LinearProgressIndicator(
                              value: (dept.adherenceRate / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.withValues(
                                alpha: 0.2,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                dept.adherenceRate >= 85
                                    ? AppColors.completed
                                    : (dept.adherenceRate >= 80
                                          ? accent
                                          : AppColors.snoozed),
                              ),
                              minHeight: AppSpace.sm,
                            ),
                          ),
                          const SizedBox(height: AppSpace.md),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${dept.activeUsers} ${appString(context, 'active members')}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: AppFontSize.caption,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpace.md),
                              Flexible(
                                child: Text(
                                  // Reaches three or four digits on a busy
                                  // organisation, which is what pushes this pair
                                  // past the card width.
                                  '${dept.totalCompleted} ${appString(context, 'stands completed')}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: AppFontSize.caption,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpace.huge),

                const SizedBox(height: AppSpace.section),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpace.xxl),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        blur: 8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Two of these cards sit side by side, so each title gets roughly
                // half the phone width. The French labels ("Collaborateurs
                // actifs", "Pauses enregistrées") are longer than the icons
                // allow for.
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppFontSize.footnote,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: AppFontSize.micro,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
