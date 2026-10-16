import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_cadence.dart';
import 'package:standup_app/core/presence.dart';
import 'package:standup_app/services/idle_time_source.dart';

/// The presence classifier is the only thing standing between a reminder and an
/// empty chair, so its boundaries are pinned rather than assumed.
void main() {
  final now = DateTime(2026, 3, 10, 14, 30);

  group('ActiveTimeTracker classification', () {
    test('starts present and needs a reading to change', () {
      final tracker = ActiveTimeTracker();
      expect(tracker.presence, Presence.present);
      expect(tracker.isAway, isFalse);
      expect(tracker.awaySince, isNull);
    });

    test('input below the threshold stays present', () {
      final tracker = ActiveTimeTracker(
        awayThreshold: const Duration(minutes: 5),
      );
      expect(
        tracker.observe(
          idle: const Duration(minutes: 4, seconds: 59),
          now: now,
        ),
        Presence.present,
      );
      expect(tracker.awaySince, isNull);
    });

    test('the threshold itself counts as away', () {
      final tracker = ActiveTimeTracker(
        awayThreshold: const Duration(minutes: 5),
      );
      expect(
        tracker.observe(idle: const Duration(minutes: 5), now: now),
        Presence.away,
      );
    });

    test('the absence is back-dated to when input stopped', () {
      // Reporting "away since now" would make a two-hour absence look like it
      // began the moment the app noticed.
      final tracker = ActiveTimeTracker(
        awayThreshold: const Duration(minutes: 5),
      );
      tracker.observe(idle: const Duration(hours: 2), now: now);
      expect(tracker.awaySince, now.subtract(const Duration(hours: 2)));
      expect(tracker.awayDuration(now), const Duration(hours: 2));
    });

    test('any input returns the user to present', () {
      final tracker = ActiveTimeTracker(
        awayThreshold: const Duration(minutes: 5),
      );
      tracker.observe(idle: const Duration(minutes: 30), now: now);
      expect(tracker.isAway, isTrue);

      expect(
        tracker.observe(
          idle: Duration.zero,
          now: now.add(Duration(minutes: 1)),
        ),
        Presence.present,
      );
      expect(tracker.awaySince, isNull);
      expect(tracker.awayDuration(now), Duration.zero);
    });

    test('a null reading preserves the previous state either way', () {
      final tracker = ActiveTimeTracker(
        awayThreshold: const Duration(minutes: 5),
      );
      // Present + unknown stays present.
      expect(tracker.observe(idle: null, now: now), Presence.present);
      // Away + unknown stays away, rather than silently flipping back.
      tracker.observe(idle: const Duration(minutes: 30), now: now);
      expect(tracker.observe(idle: null, now: now), Presence.away);
    });

    test('a backwards clock jump never yields a negative absence', () {
      final tracker = ActiveTimeTracker(
        awayThreshold: const Duration(minutes: 5),
      );
      tracker.observe(idle: const Duration(minutes: 10), now: now);
      expect(
        tracker.awayDuration(now.subtract(const Duration(hours: 3))),
        Duration.zero,
      );
    });

    test('the default threshold is the cadence constant', () {
      expect(
        ActiveTimeTracker().awayThreshold,
        const Duration(minutes: AppCadence.defaultAwayThresholdMinutes),
      );
    });

    test('reset returns the tracker to a known state', () {
      final tracker = ActiveTimeTracker(
        awayThreshold: const Duration(minutes: 5),
      );
      tracker.observe(idle: const Duration(minutes: 30), now: now);
      tracker.reset();
      expect(tracker.presence, Presence.present);
      expect(tracker.awaySince, isNull);
    });

    test('presence polling is slower than the UI tick', () {
      // A per-second platform call would be waste: idle time moves at human
      // speed.
      expect(AppCadence.presencePollSeconds, greaterThan(1));
    });
  });

  group('IdleTimeSource degradation', () {
    test('the unsupported source answers null, never a guess', () async {
      const source = UnsupportedIdleTimeSource();
      expect(await source.currentIdleTime(), isNull);
    });

    test('a platform without a native reader never calls the channel', () async {
      // No mock handler is registered here on purpose: if the source tried the
      // channel, this test would fail rather than silently return null.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(PlatformIdleTimeSource.isSupported, isFalse);
        const source = PlatformIdleTimeSource();
        expect(await source.currentIdleTime(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('the platform source degrades to null when the plugin is '
        'missing', (tester) async {
      // Simulates the state of a desktop build before its native reader exists:
      // the engine answers that no implementation is registered. A
      // MissingPluginException must not escape into the 1 Hz ticker.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('standup/presence'), (
              call,
            ) async {
              throw MissingPluginException('no presence implementation');
            });

        const source = PlatformIdleTimeSource();
        expect(await source.currentIdleTime(), isNull);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('standup/presence'),
              null,
            );
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('the platform source reads milliseconds from the channel', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('standup/presence'), (
              call,
            ) async {
              expect(call.method, 'getIdleTime');
              return 90000;
            });

        const source = PlatformIdleTimeSource();
        expect(await source.currentIdleTime(), const Duration(seconds: 90));
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('standup/presence'),
              null,
            );
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a negative reading is treated as unknown', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('standup/presence'),
              (call) async => -1,
            );

        const source = PlatformIdleTimeSource();
        expect(await source.currentIdleTime(), isNull);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('standup/presence'),
              null,
            );
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
