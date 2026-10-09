import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/data/models/workday_metrics.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/data/models/daily_analytics.dart';

class ContributionHeatmapWidget extends StatefulWidget {
  final List<DailyAnalytics> dailyData;
  final int weeksToShow;

  const ContributionHeatmapWidget({
    super.key,
    required this.dailyData,
    this.weeksToShow =
        20, // 20 weeks by default for comfortable desktop & mobile viewing
  });

  @override
  State<ContributionHeatmapWidget> createState() =>
      _ContributionHeatmapWidgetState();
}

class _ContributionHeatmapWidgetState extends State<ContributionHeatmapWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, DailyAnalytics> _buildDataMap() {
    final map = <String, DailyAnalytics>{};
    for (final item in widget.dailyData) {
      map[item.date] = item;
    }
    return map;
  }

  Color _getCellColor(DailyAnalytics? data, bool isDark) {
    if (data == null ||
        (data.remindersSent == 0 && data.remindersCompleted == 0)) {
      return isDark ? AppColors.emptyOnDark : AppColors.empty;
    }

    if (data.remindersCompleted > 0) {
      if (data.remindersCompleted >= 6) {
        return const Color(0xFF047857); // Deep Emerald
      } else if (data.remindersCompleted >= 3) {
        return const Color(0xFF10B981); // Vibrant Emerald
      } else {
        return const Color(0xFF6EE7B7); // Soft Emerald
      }
    }

    if (data.remindersSnoozed > 0) {
      return AppColors.snoozed; // Amber
    }

    if (data.remindersSkipped > 0) {
      return AppColors.skipped; // Red
    }

    return isDark ? AppColors.emptyOnDark : AppColors.empty;
  }

  void _showDayDetails(
    BuildContext context,
    DateTime date,
    DailyAnalytics? data,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final dateStr = DateFormat('EEEE, d MMM yyyy', locale).format(date);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateStr, style: theme.textTheme.titleLarge),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getCellColor(
                        data,
                        theme.brightness == Brightness.dark,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data != null && data.remindersCompleted > 0
                          ? '${data.adherenceRate.toStringAsFixed(0)}% Adherence'
                          : 'No Activity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _getCellColor(
                          data,
                          theme.brightness == Brightness.dark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildStatTile(
                    title: 'Completed',
                    value: '${data?.remindersCompleted ?? 0}',
                    subtitle: '${data?.totalStandTime ?? 0} mins standing',
                    color: AppColors.completed,
                  ),
                  const SizedBox(width: 12),
                  _buildStatTile(
                    title: 'Snoozed',
                    value: '${data?.remindersSnoozed ?? 0}',
                    subtitle: '10 min delays',
                    color: AppColors.snoozed,
                  ),
                  const SizedBox(width: 12),
                  _buildStatTile(
                    title: 'Skipped',
                    value: '${data?.remindersSkipped ?? 0}',
                    subtitle: 'Missed breaks',
                    color: AppColors.skipped,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dataMap = _buildDataMap();

    // Compute calendar grid of past `weeksToShow` weeks
    final now = DateTime.now();
    // End on upcoming Sunday or today
    final todayWeekday = now.weekday; // 1 = Mon, 7 = Sun
    final totalDays = widget.weeksToShow * 7;
    final startDate = now.subtract(
      Duration(days: totalDays - (7 - todayWeekday)),
    );

    const cellSize = 13.0;
    const cellSpacing = 3.5;

    final weekColumns = <Widget>[];

    for (int w = 0; w < widget.weeksToShow; w++) {
      final daysInWeek = <Widget>[];
      for (int d = 0; d < 7; d++) {
        final dayOffset = (w * 7) + d;
        final cellDate = startDate.add(Duration(days: dayOffset));
        final dateKey = WorkdayMetrics.dateKey(cellDate);
        final dayData = dataMap[dateKey];
        final isFuture = cellDate.isAfter(now);

        final cellColor = isFuture
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.black.withValues(alpha: 0.02))
            : _getCellColor(dayData, isDark);

        daysInWeek.add(
          Padding(
            padding: const EdgeInsets.only(bottom: cellSpacing),
            child: InkWell(
              onTap: isFuture
                  ? null
                  : () => _showDayDetails(context, cellDate, dayData),
              borderRadius: BorderRadius.circular(3),
              child: Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(3),
                  border: isDark
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 0.5,
                        )
                      : Border.all(
                          color: Colors.black.withValues(alpha: 0.04),
                          width: 0.5,
                        ),
                ),
              ),
            ),
          ),
        );
      }

      weekColumns.add(
        Padding(
          padding: const EdgeInsets.only(right: cellSpacing),
          child: Column(mainAxisSize: MainAxisSize.min, children: daysInWeek),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heatmap Grid Container with horizontal scroll
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day of week labels (Mon, Wed, Fri)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDayLabel('M', cellSize, cellSpacing),
                    _buildDayLabel('', cellSize, cellSpacing),
                    _buildDayLabel('W', cellSize, cellSpacing),
                    _buildDayLabel('', cellSize, cellSpacing),
                    _buildDayLabel('F', cellSize, cellSpacing),
                    _buildDayLabel('', cellSize, cellSpacing),
                    _buildDayLabel('S', cellSize, cellSpacing),
                  ],
                ),
              ),
              // Weeks Grid
              Row(mainAxisSize: MainAxisSize.min, children: weekColumns),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              appString(context, 'Less'),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
            const SizedBox(width: 6),
            _buildLegendBox(isDark ? AppColors.emptyOnDark : AppColors.empty),
            const SizedBox(width: 3),
            _buildLegendBox(AppColors.skipped),
            const SizedBox(width: 3),
            _buildLegendBox(AppColors.snoozed),
            const SizedBox(width: 3),
            _buildLegendBox(const Color(0xFF6EE7B7)),
            const SizedBox(width: 3),
            _buildLegendBox(const Color(0xFF10B981)),
            const SizedBox(width: 3),
            _buildLegendBox(const Color(0xFF047857)),
            const SizedBox(width: 6),
            Text(
              appString(context, 'More'),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayLabel(String label, double size, double spacing) {
    return Container(
      width: 12,
      height: size + spacing,
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLegendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
