import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Why the app asks the user to allow background activity.
enum BackgroundRunStatus {
  /// We have no reliable way to query the state; assume it is allowed.
  unknown,

  /// The app is exempt from battery optimisation and can wake on schedule.
  allowed,

  /// The app is subject to battery optimisation; the OS may delay reminders.
  restricted,
}

/// Platform bridge for the "run in the background" opt-in.
///
/// Android is the only platform that lets an app ask the user to be exempted
/// from battery optimisation. That exemption is what keeps hourly reminders
/// exact on aggressive OEM builds. iOS and macOS deliver local notifications
/// through the OS without any extra permission, and Windows/Linux need the app
/// to stay running, so those platforms report [BackgroundRunStatus.unknown].
class BackgroundRunService {
  static const MethodChannel _channel = MethodChannel('standup/background_run');

  static Future<BackgroundRunStatus> currentStatus() async {
    try {
      final raw = await _channel.invokeMethod<String>('isExempt');
      return switch (raw) {
        'allowed' => BackgroundRunStatus.allowed,
        'restricted' => BackgroundRunStatus.restricted,
        _ => BackgroundRunStatus.unknown,
      };
    } on MissingPluginException {
      return BackgroundRunStatus.unknown;
    } catch (e) {
      debugPrint('Background run status unavailable: $e');
      return BackgroundRunStatus.unknown;
    }
  }

  /// Opens the system screen where the user can exempt StandUp from battery
  /// optimisation. Returns true when the app is exempt afterwards.
  static Future<bool> requestExemption() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestExemption') ?? false;
      return granted;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('Background run request unavailable: $e');
      return false;
    }
  }
}
