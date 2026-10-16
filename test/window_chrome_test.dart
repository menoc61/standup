import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/services/window_chrome.dart';

/// The forced break already covers the app's own window. Raising that window
/// above the others is the part that makes the break hard to ignore, and it is
/// the part that runs in native code — so what is pinned here is the Dart
/// contract: every failure mode has to end in "carry on", never in a crash
/// inside the ticker that drives the block.
void main() {
  group('platform support', () {
    test('the unsupported chrome is a no-op', () async {
      // No channel handler is registered on purpose: a no-op that secretly
      // talked to the platform would hang or throw here.
      const chrome = UnsupportedWindowChrome();
      await chrome.setKeepAbove(true);
      await chrome.setKeepAbove(false);
    });

    test('desktop platforms claim support and mobile does not', () {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          expect(PlatformWindowChrome.isSupported, isTrue);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }

      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          expect(PlatformWindowChrome.isSupported, isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
    });

    testWidgets('an unsupported platform never reaches the channel', (
      tester,
    ) async {
      var calls = 0;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('standup/window'), (
              call,
            ) async {
              calls++;
              return null;
            });

        const chrome = PlatformWindowChrome();
        await chrome.setKeepAbove(true);
        await chrome.setKeepAbove(false);
        expect(calls, 0);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('standup/window'),
              null,
            );
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('keep-above requests', () {
    testWidgets('both directions are sent as a named boolean', (tester) async {
      final requests = <Object?>[];
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('standup/window'), (
              call,
            ) async {
              expect(call.method, 'setKeepAbove');
              requests.add(call.arguments);
              return null;
            });

        const chrome = PlatformWindowChrome();
        await chrome.setKeepAbove(true);
        await chrome.setKeepAbove(false);

        expect(requests, [
          {'value': true},
          {'value': false},
        ]);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('standup/window'),
              null,
            );
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a missing native implementation is swallowed', (tester) async {
      // The state of a desktop build before its native side exists. It must not
      // surface as an exception while a break is being shown.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('standup/window'), (
              call,
            ) async {
              throw MissingPluginException('no window implementation');
            });

        const chrome = PlatformWindowChrome();
        await chrome.setKeepAbove(true);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('standup/window'),
              null,
            );
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a refusal from the window manager is swallowed', (
      tester,
    ) async {
      // A compositor that will not honour keep-above (Wayland, or a refused
      // request) must not be able to break the break.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('standup/window'), (
              call,
            ) async {
              throw PlatformException(code: 'denied');
            });

        const chrome = PlatformWindowChrome();
        await chrome.setKeepAbove(true);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('standup/window'),
              null,
            );
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
