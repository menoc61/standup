import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

typedef NotificationActionCallback = void Function(String action, int id);

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Map<int, Timer> _linuxTimers = {};
  bool _initialized = false;
  NotificationActionCallback? onActionReceived;
  String _languageCode = 'fr';

  Future<void> initialize({
    NotificationActionCallback? onAction,
    String languageCode = 'fr',
  }) async {
    final previousLanguage = _languageCode;
    _languageCode = languageCode == 'en' ? 'en' : 'fr';
    if (_initialized && previousLanguage == _languageCode) return;
    if (onAction != null) onActionReceived = onAction;
    final french = _languageCode == 'fr';

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Timezone initialization notice: $e');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          notificationCategories: <DarwinNotificationCategory>[
            DarwinNotificationCategory(
              'standup_reminder',
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  'complete',
                  french ? 'Je me suis levé·e !' : 'I stood up!',
                ),
                DarwinNotificationAction.plain(
                  'snooze',
                  french ? 'Dans 10 min' : 'Snooze 10m',
                ),
                DarwinNotificationAction.plain(
                  'skip',
                  french ? 'Passer' : 'Skip',
                ),
              ],
            ),
          ],
        );

    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open StandUp');

    const WindowsInitializationSettings windowsSettings =
        WindowsInitializationSettings(
          appName: 'StandUp Wellness Reminder',
          appUserModelId: 'com.healthwellness.standup_app',
          guid: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
      windows: windowsSettings,
      web: const WebInitializationSettings(),
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final action = response.actionId ?? 'complete';
          final id = response.id ?? 1;
          onActionReceived?.call(action, id);
        },
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Notification service initialization notice: $e');
    }
  }

  Future<void> setLanguageCode(String languageCode) {
    return initialize(languageCode: languageCode, onAction: onActionReceived);
  }

  Future<bool> requestPermissions() async {
    try {
      bool? granted;
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        granted = await androidImplementation.requestNotificationsPermission();
        final exactAllowed = await androidImplementation
            .requestExactAlarmsPermission();
        return (granted ?? true) && (exactAllowed ?? true);
      }

      final iosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImplementation != null) {
        granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      final macosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macosImplementation != null) {
        granted = await macosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      // Linux and Windows use the operating system notification service and
      // don't expose a runtime permission prompt through this plugin.
      return _initialized;
    } catch (e) {
      debugPrint('Permission request notice: $e');
      return false;
    }
  }

  Future<void> scheduleStandupReminder({
    required int id,
    required DateTime scheduledTime,
    String? title,
    String? body,
  }) async {
    final french = _languageCode == 'fr';
    final effectiveTitle =
        title ?? (french ? 'C’est le moment de bouger !' : 'Time to stand up!');
    final effectiveBody =
        body ??
        (french
            ? 'Prenez 5 minutes pour vous étirer, respirer et bouger.'
            : 'Take a 5-minute break to stretch, breathe, and move.');

    final androidDetails = AndroidNotificationDetails(
      'standup_reminders_channel',
      french ? 'Rappels de mouvement' : 'Posture & Movement Reminders',
      channelDescription: french
          ? 'Rappels pour bouger et réduire la fatigue liée à la sédentarité'
          : 'Hourly reminders to move and prevent sedentary fatigue',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'complete',
          french ? 'Je me suis levé·e !' : 'I stood up!',
        ),
        AndroidNotificationAction(
          'snooze',
          french ? 'Dans 10 min' : 'Snooze 10m',
        ),
        AndroidNotificationAction('skip', french ? 'Passer' : 'Skip'),
      ],
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      categoryIdentifier: 'standup_reminder',
    );

    final linuxDetails = LinuxNotificationDetails(
      actions: <LinuxNotificationAction>[
        LinuxNotificationAction(
          key: 'complete',
          label: french ? 'Je me suis levé·e !' : 'I stood up!',
        ),
        LinuxNotificationAction(
          key: 'snooze',
          label: french ? 'Dans 10 min' : 'Snooze 10m',
        ),
        LinuxNotificationAction(key: 'skip', label: french ? 'Passer' : 'Skip'),
      ],
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
      windows: const WindowsNotificationDetails(),
    );

    try {
      if (defaultTargetPlatform == TargetPlatform.linux) {
        // The Linux desktop notification backend only supports immediate
        // notifications. Keep a foreground timer and emit at the due time.
        _linuxTimers.remove(id)?.cancel();
        final delay = scheduledTime.difference(DateTime.now());
        _linuxTimers[id] = Timer(delay.isNegative ? Duration.zero : delay, () {
          _linuxTimers.remove(id);
          _plugin.show(
            id: id,
            title: effectiveTitle,
            body: effectiveBody,
            notificationDetails: notificationDetails,
          );
        });
        return;
      }

      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      await _plugin.zonedSchedule(
        id: id,
        title: effectiveTitle,
        body: effectiveBody,
        scheduledDate: tzTime,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      // Fallback: show immediate notification if in foreground test
    }
  }

  Future<void> showNudgeNotification({required int id, String? message}) async {
    final french = _languageCode == 'fr';
    final androidDetails = AndroidNotificationDetails(
      'standup_nudge_channel',
      french ? 'Encouragements bien-être' : 'Gentle Wellness Nudges',
      channelDescription: french
          ? 'Des encouragements pour garder une routine régulière'
          : 'Supportive encouragements to stay consistent',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'complete',
          french ? 'Bouger' : 'Stand Up Now',
        ),
        AndroidNotificationAction('snooze', french ? 'Plus tard' : 'Later'),
      ],
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );

    try {
      await _plugin.show(
        id: id,
        title: french ? 'Petit rappel bien-être ✨' : 'Gentle Check-in ✨',
        body: message ?? "We noticed a few skipped reminders. Even 2 minutes of stretching resets your energy!",
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing nudge notification: $e');
    }
  }

  Future<void> cancelReminder(int id) async {
    _linuxTimers.remove(id)?.cancel();
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Error canceling notification: $e');
    }
  }

  Future<void> cancelAll() async {
    for (final timer in _linuxTimers.values) {
      timer.cancel();
    }
    _linuxTimers.clear();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }

  void dispose() {
    for (final timer in _linuxTimers.values) {
      timer.cancel();
    }
    _linuxTimers.clear();
  }

  /// Keeps a rolling queue of OS-owned reminders. They can still be delivered
  /// while the app is suspended or closed; no periodic Dart worker is needed.
  /// The 48-item queue stays below iOS's pending local notification limit.
  ///
  /// [quietHours] is a `"HH:MM-HH:MM"` window during which no reminder is
  /// scheduled. The window may wrap past midnight (for example 22:00-06:00).
  ///
  /// [actionWindowMinutes] shifts each alert to the start of the actionable
  /// window rather than the cadence boundary, so the user is notified exactly
  /// when the stand action becomes valid.
  Future<void> scheduleReminderSeries({
    required DateTime firstReminder,
    required int frequencyMinutes,
    required String title,
    required String body,
    String? quietHours,
    int actionWindowMinutes = 0,
  }) async {
    const firstId = 101;
    const count = 48;
    for (var i = 0; i < count; i++) {
      await cancelReminder(firstId + i);
    }

    final window = _parseQuietWindow(quietHours);
    final offset = actionWindowMinutes > 0
        ? Duration(minutes: actionWindowMinutes)
        : Duration.zero;

    for (var i = 0; i < count; i++) {
      final boundary = firstReminder.add(
        Duration(minutes: frequencyMinutes * i),
      );
      final when = boundary.subtract(offset);
      if (when.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
        continue;
      }
      if (_isInsideQuietWindow(when, window)) continue;
      await scheduleStandupReminder(
        id: firstId + i,
        scheduledTime: when,
        title: title,
        body: body,
      );
    }
  }

  /// Parses `"HH:MM-HH:MM"` into minutes-from-midnight bounds. A malformed or
  /// absent value returns null, which disables quiet hours.
  static ({int start, int end})? _parseQuietWindow(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 2) return null;
    final start = _parseHhMm(parts[0]);
    final end = _parseHhMm(parts[1]);
    if (start == null || end == null) return null;
    return (start: start, end: end);
  }

  static int? _parseHhMm(String value) {
    final bits = value.split(':');
    if (bits.length != 2) return null;
    final hours = int.tryParse(bits[0]);
    final minutes = int.tryParse(bits[1]);
    if (hours == null || minutes == null) return null;
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
    return hours * 60 + minutes;
  }

  static bool _isInsideQuietWindow(
    DateTime when,
    ({int start, int end})? window,
  ) {
    if (window == null) return false;
    final local = when.toLocal();
    final minutes = local.hour * 60 + local.minute;
    final start = window.start;
    final end = window.end;
    // Wrapping windows such as 22:00-06:00 cover the whole overnight span.
    if (start <= end) {
      return minutes >= start && minutes < end;
    }
    return minutes >= start || minutes < end;
  }

  Future<void> dispatchLaunchAction() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final response = details?.notificationResponse;
      if (details?.didNotificationLaunchApp == true && response != null) {
        onActionReceived?.call(
          response.actionId ?? 'complete',
          response.id ?? 1,
        );
      }
    } catch (e) {
      debugPrint('Unable to read notification launch action: $e');
    }
  }
}
