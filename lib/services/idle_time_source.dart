import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

/// Port for "how long has the machine been untouched".
///
/// The desktop implementations (Windows `GetLastInputInfo`, Linux X11
/// `XScreenSaverQueryInfo`) land with the native channel; this file is the seam
/// so the decision logic and its tests never depend on them.
///
/// Returning `null` is a first-class answer meaning "this platform cannot tell
/// you". Callers must treat that as "no information", never as "present" or
/// "away" — a guess here would either nag an empty desk or block a present user.
abstract interface class IdleTimeSource {
  Future<Duration?> currentIdleTime();
}

/// The source used wherever presence cannot be detected.
///
/// Deliberately returns `null` on every call rather than a fabricated zero, so
/// the absence of a platform implementation shows up as "unknown" instead of as
/// a confident "the user is here".
class UnsupportedIdleTimeSource implements IdleTimeSource {
  const UnsupportedIdleTimeSource();

  @override
  Future<Duration?> currentIdleTime() async => null;
}

/// Reads idle time from the native side over a method channel.
///
/// Kept separate from the service that owns it so a widget test can inject a
/// fake without a platform handler. Any platform exception degrades to `null`
/// (unknown) rather than propagating into the 1 Hz ticker.
///
/// The desktop check happens before the channel call, so a mobile or web build
/// does not pay for a platform round-trip every polling interval only to be told
/// no implementation is registered.
class PlatformIdleTimeSource implements IdleTimeSource {
  static const MethodChannel _channel = MethodChannel('standup/presence');

  const PlatformIdleTimeSource();

  /// Whether a native reader exists. Both desktop runners have one
  /// (`GetLastInputInfo` in `windows/runner/flutter_window.cpp`, the XScreenSaver
  /// extension in `linux/runner/my_application.cc`); everywhere else, and on a
  /// Linux build without `libxss-dev`, this answers `null` without a call.
  ///
  /// A `true` here only means the platform *can* answer. Whether it actually
  /// did is what `AppState.presenceDetectionAvailable` reports.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  Future<Duration?> currentIdleTime() async {
    if (!isSupported) return null;
    try {
      final milliseconds = await _channel.invokeMethod<int>('getIdleTime');
      if (milliseconds == null || milliseconds < 0) return null;
      return Duration(milliseconds: milliseconds);
    } on MissingPluginException {
      // Expected on any platform whose native side is not built yet.
      return null;
    } catch (_) {
      return null;
    }
  }
}
