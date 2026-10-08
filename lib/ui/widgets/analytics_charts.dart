import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/data/models/daily_analytics.dart';

class WeeklyAdherenceBarChart extends StatelessWidget {
  final List<DailyAnalytics> dailyData;
  final Color accentColor;

  const WeeklyAdherenceBarChart({
    super.key,
    required this.dailyData,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;

    // Pick past 7 days
    final now = DateTime.now();
    final dataMap = {for (var e in dailyData) e.date: e};

    final barGroups = <BarChartGroupData>[];
    final dayLabels = <String>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd', locale).format(date);
      final item = dataMap[dateKey];
      final label = DateFormat('E', locale).format(date).substring(0, 1);
      dayLabels.add(label);

      final completed = (item?.remindersCompleted ?? 0).toDouble();
      final snoozed = (item?.remindersSnoozed ?? 0).toDouble();
      final skipped = (item?.remindersSkipped ?? 0).toDouble();

      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: completed,
              color: AppColors.completed,
              width: 10,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: snoozed,
              color: AppColors.snoozed,
              width: 10,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: skipped,
              color: AppColors.skipped,
              width: 10,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.8,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) =>
                  isDark ? const Color(0xFF1E293B) : Colors.white,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final type = rodIndex == 0
                    ? 'Completed'
                    : rodIndex == 1
                    ? 'Snoozed'
                    : 'Skipped';
                return BarTooltipItem(
                  '$type: ${rod.toY.toInt()}',
                  TextStyle(
                    color: rod.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 2,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final index = val.toInt();
                  if (index >= 0 && index < dayLabels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        dayLabels[index],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (val) => FlLine(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }
}

class TrendStandDurationLineChart extends StatelessWidget {
  final List<DailyAnalytics> dailyData;
  final Color accentColor;

  const TrendStandDurationLineChart({
    super.key,
    required this.dailyData,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;

    // Last 14 days of data
    final sortedData = List<DailyAnalytics>.from(dailyData)
      ..sort((a, b) => a.date.compareTo(b.date));

    final recent14 = sortedData.length > 14
        ? sortedData.sublist(sortedData.length - 14)
        : sortedData;

    final spots = <FlSpot>[];
    for (int i = 0; i < recent14.length; i++) {
      spots.add(FlSpot(i.toDouble(), recent14[i].totalStandTime.toDouble()));
    }

    if (spots.isEmpty) {
      spots.add(const FlSpot(0, 0));
    }

    return AspectRatio(
      aspectRatio: 2.0,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  isDark ? const Color(0xFF1E293B) : Colors.white,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toInt()} mins',
                    TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (val) => FlLine(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 15,
                getTitlesWidget: (val, meta) => Text(
                  '${val.toInt()}m',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 3,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < recent14.length) {
                    final dt = DateTime.parse(recent14[idx].date);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        DateFormat('d MMM', locale).format(dt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: accentColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: accentColor,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.28),
                    accentColor.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
