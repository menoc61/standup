class DailyAnalytics {
  final String id;
  final String userId;
  final String date; // YYYY-MM-DD
  final int remindersSent;
  final int remindersCompleted;
  final int remindersSnoozed;
  final int remindersSkipped;
  final int totalStandTime; // in minutes (e.g. remindersCompleted * 5)
  final String? organizationId;
  final bool syncedToCloud;

  DailyAnalytics({
    required this.id,
    required this.userId,
    required this.date,
    this.remindersSent = 0,
    this.remindersCompleted = 0,
    this.remindersSnoozed = 0,
    this.remindersSkipped = 0,
    this.totalStandTime = 0,
    this.organizationId,
    this.syncedToCloud = false,
  });

  /// Adherence rate as a percentage [0 - 100]
  double get adherenceRate {
    if (remindersSent == 0) return 0.0;
    return ((remindersCompleted / remindersSent) * 100).clamp(0.0, 100.0);
  }

  /// Heatmap status categorization:
  /// - 'completed': at least one completed and completed >= skipped
  /// - 'snoozed': snoozes recorded without completion dominance
  /// - 'skipped': skips occurred with no completions
  /// - 'empty': no activity recorded
  String get heatmapStatus {
    if (remindersCompleted > 0) return 'completed';
    if (remindersSnoozed > 0) return 'snoozed';
    if (remindersSkipped > 0) return 'skipped';
    return 'empty';
  }

  DailyAnalytics copyWith({
    String? id,
    String? userId,
    String? date,
    int? remindersSent,
    int? remindersCompleted,
    int? remindersSnoozed,
    int? remindersSkipped,
    int? totalStandTime,
    String? organizationId,
    bool? syncedToCloud,
  }) {
    return DailyAnalytics(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      remindersSent: remindersSent ?? this.remindersSent,
      remindersCompleted: remindersCompleted ?? this.remindersCompleted,
      remindersSnoozed: remindersSnoozed ?? this.remindersSnoozed,
      remindersSkipped: remindersSkipped ?? this.remindersSkipped,
      totalStandTime: totalStandTime ?? this.totalStandTime,
      organizationId: organizationId ?? this.organizationId,
      syncedToCloud: syncedToCloud ?? this.syncedToCloud,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date,
      'reminders_sent': remindersSent,
      'reminders_completed': remindersCompleted,
      'reminders_snoozed': remindersSnoozed,
      'reminders_skipped': remindersSkipped,
      'total_stand_time': totalStandTime,
      'organization_id': organizationId,
    };
  }

  factory DailyAnalytics.fromJson(Map<String, dynamic> json) {
    return DailyAnalytics(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: json['date'] as String,
      remindersSent: json['reminders_sent'] as int? ?? 0,
      remindersCompleted: json['reminders_completed'] as int? ?? 0,
      remindersSnoozed: json['reminders_snoozed'] as int? ?? 0,
      remindersSkipped: json['reminders_skipped'] as int? ?? 0,
      totalStandTime: json['total_stand_time'] as int? ?? 0,
      organizationId: json['organization_id'] as String?,
      syncedToCloud: json['synced_to_cloud'] as bool? ?? false,
    );
  }

  factory DailyAnalytics.empty(String userId, String date) {
    return DailyAnalytics(
      id: 'analytics_${userId}_$date',
      userId: userId,
      date: date,
      remindersSent: 0,
      remindersCompleted: 0,
      remindersSnoozed: 0,
      remindersSkipped: 0,
      totalStandTime: 0,
    );
  }
}
