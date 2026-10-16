class OrgAnalytics {
  final String organizationId;
  final String organizationName;
  final String date;
  final int activeUsers;
  final int totalSent;
  final int totalCompleted;
  final int totalSnoozed;
  final int totalSkipped;
  final int totalStandMinutes;
  final double adherenceRate;
  final List<DepartmentMetric> departmentMetrics;
  final List<HourlySkipMetric> peakSkipHours;

  OrgAnalytics({
    required this.organizationId,
    required this.organizationName,
    required this.date,
    required this.activeUsers,
    required this.totalSent,
    required this.totalCompleted,
    required this.totalSnoozed,
    required this.totalSkipped,
    required this.totalStandMinutes,
    required this.adherenceRate,
    this.departmentMetrics = const [],
    this.peakSkipHours = const [],
  });

  factory OrgAnalytics.fromJson(Map<String, dynamic> json) {
    return OrgAnalytics(
      organizationId: json['organization_id'] as String? ?? '',
      organizationName: json['organization_name'] as String? ?? 'Organization',
      date: json['date'] as String? ?? '',
      activeUsers: json['active_users'] as int? ?? 0,
      totalSent: json['total_sent'] as int? ?? 0,
      totalCompleted: json['total_completed'] as int? ?? 0,
      totalSnoozed: json['total_snoozed'] as int? ?? 0,
      totalSkipped: json['total_skipped'] as int? ?? 0,
      totalStandMinutes: json['total_stand_minutes'] as int? ?? 0,
      adherenceRate: (json['adherence_rate'] as num?)?.toDouble() ?? 0.0,
      departmentMetrics:
          (json['departments'] as List<dynamic>?)
              ?.map((e) => DepartmentMetric.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      peakSkipHours:
          (json['peak_skip_hours'] as List<dynamic>?)
              ?.map((e) => HourlySkipMetric.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DepartmentMetric {
  final String department;
  final int activeUsers;
  final int totalCompleted;
  final int totalSkipped;
  final double adherenceRate;

  DepartmentMetric({
    required this.department,
    required this.activeUsers,
    required this.totalCompleted,
    required this.totalSkipped,
    required this.adherenceRate,
  });

  factory DepartmentMetric.fromJson(Map<String, dynamic> json) {
    return DepartmentMetric(
      department: json['department'] as String? ?? 'General',
      activeUsers: json['active_users'] as int? ?? 0,
      totalCompleted: json['total_completed'] as int? ?? 0,
      totalSkipped: json['total_skipped'] as int? ?? 0,
      adherenceRate: (json['adherence_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HourlySkipMetric {
  final String? hour;
  final int skipCount;

  /// Why skips happened, or `null` when the user declined to say.
  ///
  /// Skipping is optional and the reason is free text, so an absent value is
  /// normal. Substituting a plausible-sounding default here would invent data
  /// about real people on an anonymised dashboard, which is exactly the sort of
  /// thing the aggregation policy exists to prevent.
  final String? primaryReason;

  HourlySkipMetric({this.hour, this.skipCount = 0, this.primaryReason});

  factory HourlySkipMetric.fromJson(Map<String, dynamic> json) {
    return HourlySkipMetric(
      // Absent stays absent. A fabricated "12:00 PM" would render as a measured
      // peak hour that was never measured.
      hour: _nonEmpty(json['hour']),
      skipCount: json['skip_count'] as int? ?? 0,
      primaryReason: _nonEmpty(json['primary_reason']),
    );
  }

  /// Trims a JSON string and returns `null` when it carries no information.
  ///
  /// An empty or whitespace-only value is an absent value, and letting it
  /// through would put a blank line in the UI that looks like a rendering bug.
  static String? _nonEmpty(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// The shape of a measured window, rather than of any single day in it.
///
/// ## Why this is a model and not a widget calculation
///
/// A dashboard that shows only the newest day cannot answer the question an
/// organisation actually asks — "better or worse?" — and the arithmetic that
/// answers it is the easiest thing in the screen to get subtly wrong: an
/// average of one, a division by a window that is not full, a comparison
/// against a period that does not exist. It lives here, pure, so the tests pin
/// it rather than an eyeballed bar chart.
class OrgTrendSummary {
  /// How many measured days the window holds.
  final int dayCount;

  /// The newest day's completion rate.
  final double latestRate;

  /// The mean of every *other* day in the window, or null when there is only
  /// one. Excluding the newest day is what makes [deltaPoints] a comparison
  /// rather than a day's distance from a number it helped compute.
  final double? earlierAverageRate;

  /// How many points the newest day sits above that average; negative is below.
  final double? deltaPoints;

  const OrgTrendSummary({
    required this.dayCount,
    required this.latestRate,
    this.earlierAverageRate,
    this.deltaPoints,
  });

  /// One day is not a trend, so a single-day window reports no direction rather
  /// than a delta of zero, which would read as "flat" when nothing was compared.
  bool get hasDirection => deltaPoints != null;

  factory OrgTrendSummary.of(List<OrgAnalytics> trendNewestFirst) {
    if (trendNewestFirst.isEmpty) {
      return const OrgTrendSummary(dayCount: 0, latestRate: 0);
    }
    final latestRate = trendNewestFirst.first.adherenceRate;
    final earlier = trendNewestFirst.skip(1).toList();
    if (earlier.isEmpty) {
      return OrgTrendSummary(dayCount: 1, latestRate: latestRate);
    }
    final average =
        earlier.fold<double>(0, (sum, day) => sum + day.adherenceRate) /
        earlier.length;
    return OrgTrendSummary(
      dayCount: trendNewestFirst.length,
      latestRate: latestRate,
      earlierAverageRate: average,
      deltaPoints: latestRate - average,
    );
  }
}
