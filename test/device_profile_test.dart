import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:standup_app/data/models/device_profile.dart';

void main() {
  group('DeviceProfile.classifyDeviceType', () {
    test('separates phones from tablets by the shortest screen edge', () {
      expect(
        DeviceProfile.classifyDeviceType(
          platform: TargetPlatform.android,
          shortestSide: 400,
        ),
        'phone',
      );
      expect(
        DeviceProfile.classifyDeviceType(
          platform: TargetPlatform.iOS,
          shortestSide: 768,
        ),
        'tablet',
      );
    });

    test('treats a 600dp edge as a tablet boundary', () {
      expect(
        DeviceProfile.classifyDeviceType(
          platform: TargetPlatform.android,
          shortestSide: 600,
        ),
        'tablet',
      );
    });

    test('reports desktop on desktop platforms', () {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(
          DeviceProfile.classifyDeviceType(
            platform: platform,
            shortestSide: 900,
          ),
          'desktop',
        );
      }
    });
  });

  test('capture never records a network address', () {
    final profile = DeviceProfile.capture(
      screenSize: const Size(390, 844),
      pixelRatio: 3,
      locale: 'fr',
    );
    final json = profile.toJson();
    // The whole point of the design decision: no IP, no location, no
    // advertising identifier ever reaches the payload.
    expect(json.keys, isNot(contains('ip')));
    expect(json.keys, isNot(contains('ip_address')));
    expect(json.keys, isNot(contains('location')));
    expect(json.keys, isNot(contains('latitude')));
    expect(json.keys, isNot(contains('advertising_id')));
    expect(json['source'], 'device-only');
    expect(json['locale'], 'fr');
    expect(json['pixel_ratio'], '3.00');
  });

  test('toJson round-trips through fromJson', () {
    final profile = DeviceProfile.capture(
      screenSize: const Size(1280, 800),
      pixelRatio: 1,
      locale: 'en',
    );
    final restored = DeviceProfile.fromJson(profile.toJson());
    expect(restored.deviceType, profile.deviceType);
    expect(restored.platform, profile.platform);
    expect(restored.locale, 'en');
    expect(restored.appVersion, profile.appVersion);
  });

  test('fromJson tolerates missing keys with safe defaults', () {
    final restored = DeviceProfile.fromJson(const {});
    expect(restored.deviceType, 'unknown');
    expect(restored.source, 'device-only');
  });
}
