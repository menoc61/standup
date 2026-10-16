import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

/// Port for the few window-manager properties the app needs to set.
///
/// The forced break can already cover the app's own window, but a window that
/// sits behind another application has nothing to cover. Keeping the window
/// above its siblings is the difference between "the app is hidden for five
/// minutes" and "the break actually stands in the way", and it is the one piece
/// that cannot be done from Dart.
///
/// Everything here degrades to a no-op, so a platform whose native side is not
/// built behaves exactly as it did before rather than throwing into the ticker.
abstract interface class WindowChrome {
  /// Requests that the main window stay above other windows ([value] true) or
  /// return to normal stacking (false).
  Future<void> setKeepAbove(bool value);
}

/// The chrome used wherever the window cannot be manipulated.
class UnsupportedWindowChrome implements WindowChrome {
  const UnsupportedWindowChrome();

  @override
  Future<void> setKeepAbove(bool value) async {}
}

/// Drives the native window over a method channel.
class PlatformWindowChrome implements WindowChrome {
  static const MethodChannel _channel = MethodChannel('standup/window');

  const PlatformWindowChrome();

  /// Whether this platform has a native implementation. Checked before the
  /// channel call so unsupported builds never pay for a round-trip that can only
  /// answer "no implementation".
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  Future<void> setKeepAbove(bool value) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setKeepAbove', {'value': value});
    } on MissingPluginException {
      // Expected until the native side is built for this platform.
    } catch (_) {
      // A window-manager refusal must never surface as a crash mid-break.
    }
  }
}
