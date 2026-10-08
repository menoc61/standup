class ReminderLog {
  final String id;
  final String userId;
  final DateTime scheduledTime;
  final String actionTaken; // 'completed', 'snoozed', 'skipped'
  final int snoozeDuration; // in minutes
  final DateTime timestamp;
  final bool syncedToCloud;

  ReminderLog({
    required this.id,
    required this.userId,
    required this.scheduledTime,
    required this.actionTaken,
    this.snoozeDuration = 0,
    DateTime? timestamp,
    this.syncedToCloud = false,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isCompleted => actionTaken == 'completed';
  bool get isSnoozed => actionTaken == 'snoozed';
  bool get isSkipped => actionTaken == 'skipped';

  ReminderLog copyWith({
    String? id,
    String? userId,
    DateTime? scheduledTime,
    String? actionTaken,
    int? snoozeDuration,
    DateTime? timestamp,
    bool? syncedToCloud,
  }) {
    return ReminderLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      actionTaken: actionTaken ?? this.actionTaken,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      timestamp: timestamp ?? this.timestamp,
      syncedToCloud: syncedToCloud ?? this.syncedToCloud,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'scheduled_time': scheduledTime.toIso8601String(),
      'action_taken': actionTaken,
      'snooze_duration': snoozeDuration,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ReminderLog.fromJson(Map<String, dynamic> json) {
    return ReminderLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      scheduledTime: DateTime.parse(json['scheduled_time'] as String),
      actionTaken: json['action_taken'] as String,
      snoozeDuration: json['snooze_duration'] as int? ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      syncedToCloud: json['synced_to_cloud'] as bool? ?? false,
    );
  }
}
