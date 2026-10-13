import 'package:standup_app/core/app_cadence.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/data/models/work_schedule.dart';

/// Resolves a stored accent id to one the current palette offers.
///
/// The rebrand retired the botanical accents (`emerald`, `teal`, `amber`,
/// `indigo`, `coral`) in favour of a monochrome base with a single accent.
/// Profiles created before that change still carry the old id, and without this
/// they would render in the colour the user is complaining about — the value
/// would be perfectly valid, just no longer offered.
///
/// Falling back to the default here rather than mutating the stored row keeps
/// the change non-destructive and reversible: if the old palette ever comes
/// back, nothing has been overwritten.
String normalizeAccent(String? stored) {
  if (stored == null || stored.isEmpty) return AppColors.defaultAccentId;
  if (AppColors.isKnownAccent(stored)) return stored;
  return AppColors.defaultAccentId;
}

class UserPreferences {
  final String id;
  final String userId;
  final String themeMode; // 'system', 'light', 'dark'
  final String colorSystem; // accent id; see AppColors.accents. Default is the brand crimson.
  final int notificationFrequency; // 30, 60, 90 minutes
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool statisticsOptIn;

  /// Separate consent for sending coarse daily guidance counts to the
  /// authenticated company AI endpoint. Off by default and never implied by
  /// organization analytics consent.
  final bool aiGuidanceOptIn;
  final bool onboardingCompleted;
  final String selectedSound; // 'chime', 'success', 'nudge', 'click'
  final String? quietHours; // e.g. '22:00-07:00' or null
  final int streakGoal; // target stands per day

  /// Length in minutes of the actionable window before each cadence boundary.
  /// The product default is 5: a break counts only in the last five minutes of
  /// the hour.
  final int actionWindowMinutes;

  /// When false the action window is advisory only and a stand action is
  /// accepted at any time. Useful for pilots that need a softer rule.
  final bool enforceActionWindow;

  /// Workdays as sorted comma-separated DateTime weekday numbers (1=Monday).
  final String workDays;
  final int workStartMinute;
  final int workEndMinute;

  WorkSchedule get workSchedule => WorkSchedule.fromStored(
    days: workDays,
    startMinute: workStartMinute,
    endMinute: workEndMinute,
  );

  final DateTime updatedAt;

  UserPreferences({
    required this.id,
    required this.userId,
    this.themeMode = 'light',
    this.colorSystem = AppColors.defaultAccentId,
    this.notificationFrequency = 60,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.statisticsOptIn = false,
    this.aiGuidanceOptIn = false,
    this.onboardingCompleted = false,
    this.selectedSound = 'chime',
    this.quietHours,
    this.streakGoal = 8,
    this.actionWindowMinutes = 5,
    this.enforceActionWindow = true,
    this.workDays = '1,2,3,4,5',
    this.workStartMinute = WorkSchedule.defaultStartMinute,
    this.workEndMinute = WorkSchedule.defaultEndMinute,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  UserPreferences copyWith({
    String? id,
    String? userId,
    String? themeMode,
    String? colorSystem,
    int? notificationFrequency,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? statisticsOptIn,
    bool? aiGuidanceOptIn,
    bool? onboardingCompleted,
    String? selectedSound,
    String? quietHours,
    bool clearQuietHours = false,
    int? streakGoal,
    int? actionWindowMinutes,
    bool? enforceActionWindow,
    String? workDays,
    int? workStartMinute,
    int? workEndMinute,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      themeMode: themeMode ?? this.themeMode,
      colorSystem: colorSystem ?? this.colorSystem,
      notificationFrequency:
          notificationFrequency ?? this.notificationFrequency,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      statisticsOptIn: statisticsOptIn ?? this.statisticsOptIn,
      aiGuidanceOptIn: aiGuidanceOptIn ?? this.aiGuidanceOptIn,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      selectedSound: selectedSound ?? this.selectedSound,
      quietHours: clearQuietHours ? null : (quietHours ?? this.quietHours),
      streakGoal: streakGoal ?? this.streakGoal,
      actionWindowMinutes: actionWindowMinutes ?? this.actionWindowMinutes,
      enforceActionWindow: enforceActionWindow ?? this.enforceActionWindow,
      workDays: workDays ?? this.workDays,
      workStartMinute: workStartMinute ?? this.workStartMinute,
      workEndMinute: workEndMinute ?? this.workEndMinute,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'theme_mode': themeMode,
      'color_system': colorSystem,
      'notification_frequency': notificationFrequency,
      'sound_enabled': soundEnabled,
      'haptics_enabled': hapticsEnabled,
      'statistics_opt_in': statisticsOptIn,
      'ai_guidance_opt_in': aiGuidanceOptIn,
      'onboarding_completed': onboardingCompleted,
      'selected_sound': selectedSound,
      'quiet_hours': quietHours,
      'streak_goal': streakGoal,
      'action_window_minutes': actionWindowMinutes,
      'enforce_action_window': enforceActionWindow,
      'work_days': workDays,
      'work_start_minute': workStartMinute,
      'work_end_minute': workEndMinute,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final workSchedule = WorkSchedule.fromStored(
      days: json['work_days'] as String?,
      startMinute: json['work_start_minute'] as int?,
      endMinute: json['work_end_minute'] as int?,
    );
    return UserPreferences(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      themeMode: json['theme_mode'] as String? ?? 'light',
      colorSystem: normalizeAccent(json['color_system'] as String?),
      notificationFrequency:
          json['notification_frequency'] as int? ??
          AppCadence.defaultCadenceMinutes,
      soundEnabled: json['sound_enabled'] as bool? ?? true,
      hapticsEnabled: json['haptics_enabled'] as bool? ?? true,
      statisticsOptIn: json['statistics_opt_in'] as bool? ?? false,
      aiGuidanceOptIn: json['ai_guidance_opt_in'] as bool? ?? false,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      selectedSound: json['selected_sound'] as String? ?? 'chime',
      quietHours: json['quiet_hours'] as String?,
      streakGoal: json['streak_goal'] as int? ?? AppCadence.defaultDailyGoal,
      actionWindowMinutes:
          json['action_window_minutes'] as int? ??
          AppCadence.defaultActionWindowMinutes,
      enforceActionWindow: json['enforce_action_window'] as bool? ?? true,
      workDays: workSchedule.storedDays,
      workStartMinute: workSchedule.startMinute,
      workEndMinute: workSchedule.endMinute,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  factory UserPreferences.defaultPreferences(String userId) {
    return UserPreferences(
      id: 'pref_$userId',
      userId: userId,
      themeMode: 'light',
      colorSystem: AppColors.defaultAccentId,
      notificationFrequency: AppCadence.defaultCadenceMinutes,
      soundEnabled: true,
      hapticsEnabled: true,
      statisticsOptIn: false,
      onboardingCompleted: false,
      selectedSound: 'chime',
      quietHours: null,
      streakGoal: AppCadence.defaultDailyGoal,
      actionWindowMinutes: AppCadence.defaultActionWindowMinutes,
      enforceActionWindow: true,
    );
  }
}
