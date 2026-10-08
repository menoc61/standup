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
  final String hour;
  final int skipCount;
  final String primaryReason;

  HourlySkipMetric({
    required this.hour,
    required this.skipCount,
    required this.primaryReason,
  });

  factory HourlySkipMetric.fromJson(Map<String, dynamic> json) {
    return HourlySkipMetric(
      hour: json['hour'] as String? ?? '12:00 PM',
      skipCount: json['skip_count'] as int? ?? 0,
      primaryReason: json['primary_reason'] as String? ?? 'Work focus',
    );
  }
}
