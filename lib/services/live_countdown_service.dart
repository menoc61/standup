import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/services/notification_service.dart';

/// A persistent, non-dismissible notification that counts down to the next
/// movement break.
///
/// ## Why an ongoing notification rather than a silent background timer
///
/// The countdown is the whole point of the product: the user should be able to
/// glance at the shade and see that the next break is three minutes away, without
/// opening the app. A scheduled notification only appears at the due time, so it
/// cannot express "almost time", and Android would show nothing at all between
/// breaks.
///
/// An ongoing notification stays in the shade until it is explicitly cancelled,
/// which makes it the only notification type that can carry a live countdown.
///
/// ## Rendering constraints
///
/// The liquid-glass treatment is applied with [AndroidNotificationDetails.style]
/// rather than by building a custom layout. A `RemoteViews`-based notification
/// layout cannot be tinted from Dart, and the accent colour has to come from the
/// user's saved preference, so the platform's own `BigTextStyle` is tinted per
/// notification by passing the resolved colour through the channel-free
/// `colorized`/`color` fields. This is what makes the shade pick up the crimson
/// brand accent without a second channel per user.
///
/// The same accent drives the chronometer text, so the shade matches the app and
/// the home-screen widget at the same time.
class LiveCountdownService {
  /// Notification id for the single ongoing countdown.
  ///
  /// A fixed id means posting again replaces the existing notification instead of
  /// stacking a new one on every tick.
  static const int _notificationId = 4242;

  /// Channel for the countdown.
  ///
  /// Low importance and a null sound: this is ambient information, and it must
  /// never buzz the phone while the user is working. The actual break reminder
  /// uses a separate, high-importance channel.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'standup_countdown_channel',
    'Next break countdown',
    description: 'Persistent countdown to your next movement break',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin _plugin;

  /// Throttles redraws so the countdown text does not wake the CPU every frame.
  static const Duration _refreshInterval = Duration(seconds: 30);

  /// How often to rewrite the notification text while the window is open.
  static const Duration _openWindowTick = Duration(seconds: 5);

  Timer? _timer;
  DateTime? _target;
  String _languageCode = 'fr';
  bool _isAndroid = false;

  LiveCountdownService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Whether the countdown is currently being shown.
  bool get isCountingDown => _timer?.isActive ?? false;

  /// Selects the accent used for the countdown text.
  ///
  /// Resolved from the user's preference by the caller so this service does not
  /// depend on `AppColors` and stays unit-testable.
  Color? Function()? accentResolver;

  Future<void> initialize({
    required bool isAndroid,
    String languageCode = 'fr',
  }) async {
    _isAndroid = isAndroid;
    _languageCode = languageCode == 'en' ? 'en' : 'fr';
    if (!isAndroid) return;

    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    } catch (e) {
      debugPrint('Live countdown channel notice: $e');
    }
  }

  void setLanguageCode(String languageCode) {
    _languageCode = languageCode == 'en' ? 'en' : 'fr';
    final target = _target;
    if (target != null && isCountingDown) {
      unawaited(_post(target));
    }
  }

  /// Starts, or restarts, the countdown to [target].
  ///
  /// Safe to call every time app state recomputes: posting the same id replaces
  /// the notification rather than adding a second one.
  Future<void> start(DateTime target) async {
    if (!_isAndroid) return;

    _target = target;
    _timer?.cancel();

    await _post(target);

    // Tick fast while the break window is open so the countdown reaches zero on
    // time, and slowly the rest of the time so it costs almost nothing.
    final now = DateTime.now();
    final millisToTarget = target.difference(now).inMilliseconds;
    final inWindow = millisToTarget <= _openWindowTick.inMilliseconds;
    final interval = inWindow ? _openWindowTick : _refreshInterval;

    _timer = Timer.periodic(interval, (_) async {
      final current = _target;
      if (current == null) {
        cancel();
        return;
      }
      await _post(current);
    });
  }

  /// Removes the countdown from the shade.
  ///
  /// Called when the break fires, is completed, snoozed or skipped, so the user
  /// never sees a stale "0:00" left sitting in the shade.
  Future<void> cancel() async {
    _timer?.cancel();
    _timer = null;
    _target = null;
    if (!_isAndroid) return;

    try {
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      debugPrint('Live countdown cancel notice: $e');
    }
  }

  Future<void> _post(DateTime target) async {
    final french = _languageCode == 'fr';
    // Round up rather than truncate, so a break due in 300ms reads as "0:01" and
    // never as "0:00" while it is still in the future. formatClock truncates, so
    // the rounding has to happen before it is called — the alternative is a
    // second copy of the mm:ss formatting that will drift.
    final remaining = target.difference(DateTime.now());
    final accent = accentResolver?.call();
    final rounded = remaining.isNegative
        ? Duration.zero
        : Duration(seconds: (remaining.inMilliseconds / 1000).ceil());
    final countdown = formatClock(rounded);

    final title = french
        ? 'Prochaine pause dans $countdown'
        : 'Next break in $countdown';
    final body = french
        ? 'Levez-vous, étirez-vous, respirez.'
        : 'Stand up, stretch, and breathe.';

    final details = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.low,
      priority: Priority.low,
      // Same white silhouette the reminder notifications use. Android tints it
      // with the system colour, so the brand mark cannot be carried here; the
      // colour comes from the system, not from the artwork.
      icon: NotificationService.androidSmallIcon,
      largeIcon: await NotificationService.notificationLargeIcon,
      // Ongoing means the user cannot swipe it away by accident; the countdown
      // is not a transient event they should be able to lose.
      ongoing: true,
      autoCancel: false,
      // Redrawing every tick must not re-alert, or the phone buzzes continuously.
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showWhen: true,
      // UsingWhen: shows the system clock, which updates for free instead of
      // needing our own redraw.
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: french ? 'Prochaine pause' : 'Next break',
      ),
      color: accent,
      colorized: false,
    );

    try {
      await _plugin.show(
        id: _notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: details,
          iOS: const DarwinNotificationDetails(presentAlert: false),
          macOS: const DarwinNotificationDetails(presentAlert: false),
        ),
      );
    } catch (e) {
      debugPrint('Live countdown post notice: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _target = null;
  }
}
