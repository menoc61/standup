import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_spacing.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/data/models/org_analytics.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/ui/widgets/glass_card.dart';

/// Organisation dashboard for workspace administrators.
///
/// Two compositions, chosen by width rather than by platform: a desktop window
/// gets a two-column reading layout with a compact department table; a phone
/// gets one column of cards. The data is identical — the difference is how much
/// can be compared at a glance, which is what a wide screen is for.
class OrgAdminScreen extends StatelessWidget {
  final AppState appState;

  const OrgAdminScreen({super.key, required this.appState});

  /// Below this width the table becomes unreadable and the columns would each
  /// hold two or three characters, so the card layout is not a fallback for
  /// phones — it is the correct layout for anything narrower than a tablet.
  static const double wideBreakpoint = 980;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            // Push first, then read: the local day's counters may not have
            // reached the server yet, and a refresh that only re-read the
            // aggregates would show the user their own action as missing.
            onPressed: () async {
              await appState.triggerCloudSync();
              await appState.refreshOrgAnalytics();
            },
            tooltip: appString(context, 'Refresh Org Aggregates'),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= wideBreakpoint;
            final horizontal = wide ? AppSpace.section : AppSpace.xl;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: AppSpace.xl,
              ),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: wide
                      ? _wideBody(context, org, accent, theme)
                      : _narrowBody(context, org, accent, theme),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Desktop: reading column on the left, comparison column on the right.
  Widget _wideBody(
    BuildContext context,
    OrgAnalytics org,
    Color accent,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, org, accent, theme, compact: false),
              const SizedBox(height: AppSpace.xl),
              _statGrid(context, org, accent, columns: 2),
              const SizedBox(height: AppSpace.xl),
              _activityMix(context, org, accent, theme),
              const SizedBox(height: AppSpace.xl),
              _TrendSection(trend: appState.orgTrend, accent: accent),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.section),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appString(context, 'Department breakdown'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                appString(
                  context,
                  'Department activity, still cohort-protected and never per person.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpace.xl),
              _departmentTable(context, org, accent, theme),
            ],
          ),
        ),
      ],
    );
  }

  /// Phone: one column, ordered by what an admin checks first.
  Widget _narrowBody(
    BuildContext context,
    OrgAnalytics org,
    Color accent,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context, org, accent, theme, compact: true),
        const SizedBox(height: AppSpace.xl),
        _statGrid(context, org, accent, columns: 2),
        const SizedBox(height: AppSpace.xl),
        _activityMix(context, org, accent, theme),
        const SizedBox(height: AppSpace.section),
        _TrendSection(trend: appState.orgTrend, accent: accent),
        const SizedBox(height: AppSpace.section),
        Text(
          appString(context, 'Department breakdown'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          appString(
            context,
            'Department activity, still cohort-protected and never per person.',
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpace.xl),
        ...org.departmentMetrics.map(
          (dept) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.lg),
            child: _departmentCard(context, dept, accent, theme),
          ),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    OrgAnalytics org,
    Color accent,
    ThemeData theme, {
    required bool compact,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(compact ? AppSpace.xxl : AppSpace.huge),
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
              // The organisation name is user-supplied and can be arbitrarily
              // long; an unbounded Text next to a fixed badge overflows.
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
    );
  }

  /// Four benchmark cards. [columns] is 2 on every width we support: four
  /// narrow cards in one row would each lose their subtitle on a phone, and the
  /// desktop column is not wide enough to earn a fourth.
  Widget _statGrid(
    BuildContext context,
    OrgAnalytics org,
    Color accent, {
    required int columns,
  }) {
    final cards = <Widget>[
      _statCard(
        context,
        title: appString(context, 'Contributing Employees'),
        value: '${org.activeUsers}',
        // The view counts distinct contributors among rows that passed the
        // server's checks and the five-person cohort floor. "Enrolled" would
        // have claimed more than the number can support.
        subtitle: appString(context, 'Teammates with recorded activity'),
        icon: Icons.people_outline,
        color: accent,
      ),
      _statCard(
        context,
        title: appString(context, 'Org Completion Rate'),
        value: '${org.adherenceRate.toStringAsFixed(1)}%',
        subtitle: appString(context, 'Of recorded actions'),
        icon: Icons.trending_up,
        color: AppColors.completed,
      ),
      _statCard(
        context,
        title: appString(context, 'Stands Logged'),
        value: '${org.totalCompleted}',
        subtitle:
            '${org.totalStandMinutes} ${appString(context, 'mins movement')}',
        icon: Icons.accessibility_new,
        color: accent,
      ),
      _statCard(
        context,
        title: appString(context, 'Skipped Breaks'),
        value: '${org.totalSkipped}',
        subtitle: '${org.totalSnoozed} ${appString(context, 'snoozed')}',
        icon: Icons.alarm_off,
        color: AppColors.snoozed,
      ),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += columns) {
      final slice = cards.skip(i).take(columns).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < columns; j++) ...[
              if (j > 0) const SizedBox(width: AppSpace.xl),
              Expanded(
                child: j < slice.length ? slice[j] : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
      if (i + columns < cards.length) {
        rows.add(const SizedBox(height: AppSpace.xl));
      }
    }
    return Column(children: rows);
  }

  /// What happened to every reminder that was sent.
  ///
  /// The completion rate alone hides whether people are snoozing (deferring) or
  /// skipping (declining), which are different signals: a team that snoozes is
  /// still engaged, a team that skips has stopped using the reminder. All four
  /// numbers come from the same cohort-protected row.
  Widget _activityMix(
    BuildContext context,
    OrgAnalytics org,
    Color accent,
    ThemeData theme,
  ) {
    final mix = OrgActivityMix.from(org);
    final sent = mix.sent;
    final completed = mix.completed;
    final snoozed = mix.snoozed;
    final skipped = mix.skipped;
    final unanswered = mix.unanswered;
    final base = mix.denominator;

    double share(int value) => mix.shareOf(value);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.xxl),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      blur: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appString(context, 'Activity mix'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            appString(
              context,
              'Every reminder sent, split by what the teammate did with it.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.lg),
          if (base > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: SizedBox(
                height: AppSpace.sm,
                child: Row(
                  children: [
                    for (final segment in [
                      (completed, AppColors.completed),
                      (snoozed, AppColors.snoozed),
                      (skipped, theme.colorScheme.error),
                      (unanswered, Colors.grey.withValues(alpha: 0.35)),
                    ])
                      if (segment.$1 > 0)
                        Expanded(
                          flex: segment.$1,
                          child: ColoredBox(color: segment.$2),
                        ),
                  ],
                ),
              ),
            ),
          if (base > 0) const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: AppSpace.xxl,
            runSpacing: AppSpace.md,
            children: [
              _activityItem(
                context,
                label: appString(context, 'Reminders sent'),
                value: '$sent',
                color: accent,
                theme: theme,
              ),
              _activityItem(
                context,
                label: appString(context, 'Completed'),
                value: '${(share(completed) * 100).toStringAsFixed(0)}%',
                detail: '$completed',
                color: AppColors.completed,
                theme: theme,
              ),
              _activityItem(
                context,
                label: appString(context, 'Snoozed'),
                value: '${(share(snoozed) * 100).toStringAsFixed(0)}%',
                detail: '$snoozed',
                color: AppColors.snoozed,
                theme: theme,
              ),
              _activityItem(
                context,
                label: appString(context, 'Skipped'),
                value: '${(share(skipped) * 100).toStringAsFixed(0)}%',
                detail: '$skipped',
                color: theme.colorScheme.error,
                theme: theme,
              ),
              if (unanswered > 0)
                _activityItem(
                  context,
                  label: appString(context, 'No action recorded'),
                  value: '${(share(unanswered) * 100).toStringAsFixed(0)}%',
                  detail: '$unanswered',
                  color: Colors.grey,
                  theme: theme,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
    String? detail,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpace.sm,
          height: AppSpace.sm,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpace.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: AppFontSize.micro,
              ),
            ),
            Text(
              detail == null ? value : '$value · $detail',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: AppFontSize.footnote,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.xxl),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      blur: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
    );
  }

  /// Desktop department comparison. A table is the right control when the job
  /// is comparing six numbers across eight departments; the card list below is
  /// the right control when the job is reading one department at a time.
  Widget _departmentTable(
    BuildContext context,
    OrgAnalytics org,
    Color accent,
    ThemeData theme,
  ) {
    if (org.departmentMetrics.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpace.xxl),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Text(
          appString(
            context,
            'No department has reached the five-person cohort yet.',
          ),
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    Widget cell(String text, {int flex = 1, TextAlign align = TextAlign.end}) {
      return Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.xxl),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      blur: 8,
      child: Column(
        children: [
          Row(
            children: [
              cell(
                appString(context, 'Department'),
                flex: 3,
                align: TextAlign.start,
              ),
              cell(appString(context, 'People'), flex: 2),
              cell(appString(context, 'Sent')),
              cell(appString(context, 'Completed')),
              cell(appString(context, 'Skipped')),
              cell(appString(context, 'Rate'), flex: 2),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Divider(color: theme.dividerColor.withValues(alpha: 0.4), height: 1),
          for (final dept in org.departmentMetrics) ...[
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        width: AppSpace.sm,
                        height: AppSpace.sm,
                        decoration: BoxDecoration(
                          color: _rateColor(dept.adherenceRate, accent),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          dept.department,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: AppFontSize.footnote,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                cell('${dept.activeUsers}', flex: 2),
                cell('${dept.totalSent}'),
                cell('${dept.totalCompleted}'),
                cell('${dept.totalSkipped}'),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${dept.adherenceRate.toStringAsFixed(1)}%',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: AppFontSize.footnote,
                      color: _rateColor(dept.adherenceRate, accent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _departmentCard(
    BuildContext context,
    DepartmentMetric dept,
    Color accent,
    ThemeData theme,
  ) {
    final color = _rateColor(dept.adherenceRate, accent);
    return GlassCard(
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
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpace.lg),
                    // Department names come from the database, so their length
                    // is not ours to bound.
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
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: AppSpace.sm,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${dept.activeUsers} ${appString(context, 'contributing members')}',
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
          const SizedBox(height: AppSpace.xxs),
          Text(
            '${dept.totalSent} ${appString(context, 'sent')} · '
            '${dept.totalSnoozed} ${appString(context, 'snoozed')} · '
            '${dept.totalSkipped} ${appString(context, 'skipped')}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: AppFontSize.caption,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  static Color _rateColor(double rate, Color accent) {
    if (rate >= 85) return AppColors.completed;
    if (rate >= 80) return accent;
    return AppColors.snoozed;
  }
}

/// The measured days, oldest to newest.
///
/// ## Why this is here
///
/// The stat cards answer "how are we doing?" with one day, which cannot say
/// which way anything is moving: a rate of 78% is encouraging after a week at
/// 60% and alarming after a week at 90%. The bars are the same cohort-protected,
/// server-validated rows the cards use — the rest of the window rather than one
/// row of it, so no new data is exposed and no new rule is needed.
class _TrendSection extends StatelessWidget {
  /// Newest first, the order the query returns.
  final List<OrgAnalytics> trend;
  final Color accent;

  const _TrendSection({required this.trend, required this.accent});

  /// The drawing height of the strip; the tallest bar fills it exactly.
  static const double _stripHeight = 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (trend.isEmpty) return const SizedBox.shrink();

    // Oldest first so the strip reads like a calendar.
    final days = trend.reversed.toList();
    final summary = OrgTrendSummary.of(trend);
    final delta = summary.deltaPoints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appString(context, 'Participating days'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          appString(
            context,
            'One bar per measured day. Any day below five contributing teammates is omitted by the server.',
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpace.xl),
        GlassCard(
          padding: const EdgeInsets.all(AppSpace.xxl),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          blur: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _stripHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Tooltip(
                            message:
                                '${days[i].date} · '
                                '${days[i].adherenceRate.toStringAsFixed(1)}%',
                            // A rate of zero must still be visible as a mark:
                            // an empty slot reads as "no data" rather than as
                            // "nobody stood up".
                            child: Container(
                              height:
                                  (_stripHeight *
                                          (days[i].adherenceRate / 100).clamp(
                                            0.02,
                                            1.0,
                                          ))
                                      .toDouble(),
                              decoration: BoxDecoration(
                                color: i == days.length - 1
                                    ? accent
                                    : accent.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${days.length} ${appString(context, 'days shown')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (delta != null)
                    Text(
                      delta >= 0
                          ? '${delta.abs().toStringAsFixed(1)} '
                                '${appString(context, 'pts above the earlier average')}'
                          : '${delta.abs().toStringAsFixed(1)} '
                                '${appString(context, 'pts below the earlier average')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: delta >= 0
                            ? AppColors.completed
                            : AppColors.snoozed,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
