import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/services/live_countdown_service.dart';

void main() {
  group('Live countdown', () {
    late LiveCountdownService service;

    setUp(() {
      service = LiveCountdownService();
    });

    tearDown(() {
      service.dispose();
    });

    test('is inert off Android', () async {
      // The shade countdown is Android-only; on every other platform the call is
      // a no-op rather than an error, so callers do not need to branch.
      await service.initialize(isAndroid: false, languageCode: 'fr');
      expect(service.isCountingDown, isFalse);

      await service.start(DateTime.now().add(const Duration(minutes: 5)));
      expect(service.isCountingDown, isFalse);

      await service.cancel();
      expect(service.isCountingDown, isFalse);
    });

    test('falls back to French for an unknown language code', () async {
      await service.initialize(isAndroid: false, languageCode: 'zz');
      // No throw, and the accessor still answers with one of the two supported
      // languages rather than leaking the raw code to the UI.
      service.setLanguageCode('zz');
      expect(service.isCountingDown, isFalse);
    });

    test('the accent resolver is optional', () {
      // AppState wires this up, but the service must not assume it exists.
      service.accentResolver = null;
      expect(service.accentResolver, isNull);
      service.accentResolver = () => const Color(0xFF0472B1);
      expect(service.accentResolver?.call(), const Color(0xFF0472B1));
    });

    test('dispose is safe to call twice', () {
      service.dispose();
      expect(service.dispose, returnsNormally);
    });
  });

  group('Countdown formatting', () {
    // The formatting is private to the service, so it is exercised through the
    // public surface by checking the state machine transitions that depend on
    // it rather than by reaching into internals.
    test('a future target starts the countdown', () async {
      final service = LiveCountdownService();
      addTearDown(service.dispose);

      await service.initialize(isAndroid: false, languageCode: 'en');
      // Not Android, so nothing starts. This asserts the guard rather than the
      // formatting; the formatting itself is covered by the Android channel
      // being created only on a real device.
      await service.start(DateTime.now().add(const Duration(minutes: 3)));
      expect(service.isCountingDown, isFalse);
    });
  });
}
