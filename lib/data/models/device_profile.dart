import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;

/// A transparent description of the device and app build.
///
/// ## Why this is deliberately limited
///
/// An earlier request asked for the device IP address and as much identifying
/// information as possible. That was not implemented, and the omission is
/// intentional:
///
/// * An IP address is personal data under both the GDPR and Cameroon's data
///   protection law. Pairing it with per-employee break timestamps converts the
///   app from an anonymous wellness tool into individual employee monitoring,
///   which directly contradicts the product's own privacy guarantees and the
///   row-level security rules in `supabase_schema.sql`.
/// * Resolving an IP requires a third-party lookup service, which would leak
///   every user's address to that service and break the offline-first design.
/// * The employer-facing dashboards are specified to be anonymised aggregates.
///   Individual timestamps are the one thing the schema deliberately never
///   exposes to administrators.
///
/// What is collected here is the operational metadata that genuinely helps debug
/// a build and reason about aggregate reliability: what kind of device, which OS
/// and version, which app build, how large the window, and which locale and time
/// zone the user is in. No identifier, no network address, no location, and no
/// advertising or analytics fingerprint. It is stored on the device, shown to the
/// user in Preferences, and only sent to the cloud when the user turns the
/// statistics toggle on.
class DeviceProfile {
  /// Broad form factor, used to weight layout and reporting.
  final String deviceType;

  /// Operating system name, e.g. `Android`, `iOS`, `Windows`.
  final String platform;

  /// Operating system version string.
  final String osVersion;

  /// Physical device model when the platform exposes it. On web and desktop
  /// this is usually empty.
  final String model;

  /// Application version from `pubspec.yaml`.
  final String appVersion;

  /// Build number from `pubspec.yaml`.
  final String appBuild;

  /// Logical screen size in device-independent pixels.
  final String screenSize;

  /// Device pixel ratio.
  final String pixelRatio;

  /// User interface language tag, e.g. `fr`.
  final String locale;

  /// IANA time zone name, e.g. `Africa/Douala`.
  final String timeZone;

  /// UTC offset in minutes at the time of capture.
  final int utcOffsetMinutes;

  /// Free-form label describing where the value came from, used in the UI so
  /// the user can see that nothing is being inferred from the network.
  final String source;

  const DeviceProfile({
    required this.deviceType,
    required this.platform,
    required this.osVersion,
    required this.model,
    required this.appVersion,
    required this.appBuild,
    required this.screenSize,
    required this.pixelRatio,
    required this.locale,
    required this.timeZone,
    required this.utcOffsetMinutes,
    required this.source,
  });

  /// Builds the profile from the running app.
  ///
  /// Every field is read from the operating system or from local app metadata.
  /// No network request is made anywhere in this class.
  static DeviceProfile capture({
    required Size screenSize,
    required double pixelRatio,
    required String locale,
  }) {
    final deviceType = classifyDeviceType(
      platform: defaultTargetPlatform,
      shortestSide: screenSize.shortestSide,
    );

    return DeviceProfile(
      deviceType: deviceType,
      platform: _platformLabel(defaultTargetPlatform),
      osVersion: _osVersion(),
      model: _model(),
      appVersion: _appVersion,
      appBuild: _appBuild,
      screenSize:
          '${screenSize.width.toStringAsFixed(0)}x'
          '${screenSize.height.toStringAsFixed(0)} dp',
      pixelRatio: pixelRatio.toStringAsFixed(2),
      locale: locale,
      timeZone: _timeZoneName(),
      utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      source: 'device-only',
    );
  }

  /// Form factor from platform plus the shortest screen edge, which is the
  /// standard breakpoint for separating a phone from a tablet.
  static String classifyDeviceType({
    required TargetPlatform platform,
    required double shortestSide,
  }) {
    if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
      if (shortestSide >= 600) return 'tablet';
      return 'phone';
    }
    switch (platform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return 'desktop';
      case TargetPlatform.fuchsia:
        return 'other';
      default:
        // Web has no reliable form factor, so it is reported as unknown rather
        // than guessed from a user agent string.
        return 'web';
    }
  }

  static const Map<TargetPlatform, String> _platformLabels = {
    TargetPlatform.android: 'Android',
    TargetPlatform.iOS: 'iOS',
    TargetPlatform.windows: 'Windows',
    TargetPlatform.macOS: 'macOS',
    TargetPlatform.linux: 'Linux',
    TargetPlatform.fuchsia: 'Fuchsia',
  };

  static String _platformLabel(TargetPlatform platform) =>
      _platformLabels[platform] ?? 'Web';

  static String _osVersion() {
    try {
      return Platform.operatingSystemVersion.trim();
    } catch (_) {
      // Web does not expose an operating system version through dart:io.
      return 'unknown';
    }
  }

  static String _model() {
    try {
      if (kIsWeb) return '';
      final env = Platform.environment;
      // These are read from the local process environment, never from a server.
      return env['ANDROID_MODEL'] ?? env['MODEL'] ?? env['DEVICE_NAME'] ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _timeZoneName() {
    try {
      // Linking the local zone name requires the timezone package's data, which
      // the notification service already initialises. Falling back to a fixed
      // offset keeps this working even if it has not been loaded yet.
      return DateTime.now().timeZoneName;
    } catch (_) {
      return 'unknown';
    }
  }

  /// App version and build are injected at build time by the Flutter tool.
  static const String _appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const String _appBuild = String.fromEnvironment(
    'APP_BUILD',
    defaultValue: '1',
  );

  Map<String, dynamic> toJson() => {
    'device_type': deviceType,
    'platform': platform,
    'os_version': osVersion,
    'model': model,
    'app_version': appVersion,
    'app_build': appBuild,
    'screen_size': screenSize,
    'pixel_ratio': pixelRatio,
    'locale': locale,
    'time_zone': timeZone,
    'utc_offset_minutes': utcOffsetMinutes,
    'source': source,
  };

  factory DeviceProfile.fromJson(Map<String, dynamic> json) {
    return DeviceProfile(
      deviceType: json['device_type'] as String? ?? 'unknown',
      platform: json['platform'] as String? ?? 'unknown',
      osVersion: json['os_version'] as String? ?? 'unknown',
      model: json['model'] as String? ?? '',
      appVersion: json['app_version'] as String? ?? '1.0.0',
      appBuild: json['app_build'] as String? ?? '1',
      screenSize: json['screen_size'] as String? ?? '',
      pixelRatio: json['pixel_ratio'] as String? ?? '',
      locale: json['locale'] as String? ?? 'fr',
      timeZone: json['time_zone'] as String? ?? 'unknown',
      utcOffsetMinutes: json['utc_offset_minutes'] as int? ?? 0,
      source: json['source'] as String? ?? 'device-only',
    );
  }

  /// The exact JSON that would be transmitted, for display in Preferences so the
  /// user can audit it before opting in.
  String describeForUser() =>
      toJson().entries.map((e) => '${e.key}: ${e.value}').join('\n');
}
