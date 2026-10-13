import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_identity.dart';

/// Guards the single source of truth for the app's identity.
///
/// The identifiers in [AppIdentity] exist because the same string used to be
/// written out independently in nine native files across two incompatible
/// spellings. That is easy to reintroduce by accident: rename a value here and
/// forget Gradle, and the Android launcher widget silently stops receiving
/// updates with nothing in the build to say so.
///
/// These tests fail when a rename is only half-applied. They are deliberately
/// file-reading rather than behavioural: the failure they guard against is
/// invisible at runtime, which is precisely why it needs a guard.
void main() {
  group('identity matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('version matches pubspec', () {
      final match = RegExp(
        r'^version:\s*(\S+)\+(\S+)',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec.yaml has no version: X+Y line');

      expect(AppIdentity.version, match!.group(1));
      expect(
        '${AppIdentity.buildNumber}',
        match.group(2),
        reason: 'build number must match the +N suffix in pubspec.yaml',
      );
    });

    test('package name matches the Dart package', () {
      expect(pubspec, contains('name: ${AppIdentity.packageName}'));
    });

    test('repository points at the declared homepage', () {
      expect(pubspec, contains('homepage: https://github.com/menoc61/standup'));
    });
  });

  group('derived identifiers are internally consistent', () {
    test(
      'widget provider is the sub-package of the Android application id',
      () {
        expect(
          AppIdentity.androidWidgetProvider,
          '${AppIdentity.bundleId}.widget.StandUpWidgetProvider',
        );
      },
    );

    test('complete action is the sub-action of the Android application id', () {
      expect(
        AppIdentity.androidCompleteAction,
        '${AppIdentity.bundleId}.action.COMPLETE_BREAK',
      );
    });

    test('app group is nested under the Apple bundle id', () {
      expect(AppIdentity.appGroupId, 'group.${AppIdentity.appleBundleId}');
    });

    test('widget bundle id is nested under the Apple bundle id', () {
      expect(
        AppIdentity.iosWidgetBundleId,
        '${AppIdentity.appleBundleId}.StandUpWidget',
      );
    });

    test('auth redirect is built from the scheme', () {
      expect(
        AppIdentity.authRedirectUrl,
        '${AppIdentity.authScheme}://login-callback',
      );
    });

    test('database file name is derived from the package name', () {
      expect(AppIdentity.databaseFileName, '${AppIdentity.packageName}.sqlite');
    });
  });

  group('no legacy identity survives', () {
    /// The pre-rebrand identifiers. `standup_app` and `standupApp` differed only
    /// in case, which is exactly the kind of split that survives a find-and-
    /// replace and breaks a widget months later.
    const legacy = ['healthwellness', 'standupApp', 'CSPH'];

    /// Files that must not mention the old identity. `app_identity.dart` is
    /// excluded because documenting the previous spellings is the point of it,
    /// and `pubspec.lock` / build output are not source.
    ///
    /// `docs/` is deliberately *not* scanned. Documentation has to be able to
    /// name the previous value to explain a migration — the installer notes
    /// explain the one-time settings reset precisely by saying which folder
    /// `CompanyName` used to resolve. Flagging that as drift would push the docs
    /// toward omitting the only information an upgrader needs. Stale doc claims
    /// are a separate problem with a separate review, not a substring check.
    const scannedDirs = [
      'lib',
      'test',
      'tool',
      'android/app/src',
      'android/app/build.gradle.kts',
      'ios',
      'macos',
      'windows',
      'linux',
      'web',
      'scripts',
    ];

    /// An allowlist, not a blocklist.
    ///
    /// Platform folders contain generated trees — `windows/flutter/ephemeral`
    /// holds `.plugin_symlinks` into other packages, complete with binary
    /// fixtures such as `sound.mp3`. Reading those as UTF-8 throws, and a
    /// recursive scan that walks into them tests somebody else's code. Naming
    /// the source extensions keeps the scan pointed at this repository.
    const textExtensions = {
      '.dart',
      '.kt',
      '.java',
      '.swift',
      '.m',
      '.mm',
      '.h',
      '.hpp',
      '.cpp',
      '.cc',
      '.cxx',
      '.xml',
      '.plist',
      '.xcconfig',
      '.entitlements',
      '.pbxproj',
      '.json',
      '.html',
      '.css',
      '.js',
      '.md',
      '.yaml',
      '.yml',
      '.iss',
      '.ps1',
      '.sh',
      '.rb',
      '.py',
      '.gradle',
      '.kts',
      '.properties',
      '.desktop',
      '.rc',
      '.cmake',
      '.txt',
    };

    test('no source file references the old identity', () {
      final offenders = <String>[];

      for (final dir in scannedDirs) {
        final path = Directory(dir);
        if (!path.existsSync()) continue;

        for (final entity in path.listSync(recursive: true)) {
          if (entity is! File) continue;
          final name = entity.path;

          if (!textExtensions.any(name.endsWith)) continue;

          // The identity module documents the old spellings on purpose, and the
          // brand regression test exists to assert the old name is gone.
          if (name.endsWith('app_identity.dart')) continue;
          if (name.endsWith('identity_test.dart')) continue;
          if (name.endsWith('brand_regression_test.dart')) continue;

          final text = entity.readAsStringSync();
          for (final token in legacy) {
            if (text.contains(token)) {
              offenders.add('$name contains "$token"');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Legacy identity found. Rename it in AppIdentity and run\n'
            '  dart run tool/stamp_identity.dart\n'
            'then commit the stamped files in the same change.\n\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('native files match the stamp', () {
    /// Deliberately does *not* shell out to `tool/stamp_identity.dart --check`.
    ///
    /// An earlier version of this test did, and it deadlocked: the nested `dart
    /// run` contends for the same package-config and build lock the test runner
    /// already holds, so neither side makes progress. Running the stamper as its
    /// own CI step (see `.github/workflows/ci.yml`) keeps the same guarantee
    /// without the lock contention.
    ///
    /// What is asserted here is the part that needs the Dart values: that the
    /// identifiers the app resolves at runtime are the ones the native projects
    /// actually declare.
    test('the Android widget provider class exists in the native project', () {
      // AppIdentity.androidWidgetProvider is a class reference, so if the Kotlin
      // package or the class name drifted, the widget would resolve to nothing.
      const provider = 'android/app/src/main/kotlin';
      final matches = Directory(provider)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('StandUpWidgetProvider.kt'))
          .toList();

      expect(matches, hasLength(1));
      expect(
        File(matches.single.path).readAsStringSync(),
        contains('package ${AppIdentity.bundleId}.widget'),
        reason:
            'Kotlin package must match AppIdentity.androidWidgetProvider, or '
            'Android cannot resolve the receiver the widget bridge registers.',
      );
    });

    test('both iOS App Group entitlements declare the same group', () {
      const entitlements = [
        'ios/Runner/Runner.entitlements',
        'ios/StandUpWidget/StandUpWidget.entitlements',
      ];

      for (final path in entitlements) {
        expect(
          File(path).readAsStringSync(),
          contains(AppIdentity.appGroupId),
          reason: '$path must declare ${AppIdentity.appGroupId}',
        );
      }
    });

    test('the WidgetKit extension reads the same App Group', () {
      expect(
        File('ios/StandUpWidget/WidgetPayload.swift').readAsStringSync(),
        contains(AppIdentity.appGroupId),
        reason:
            'WidgetPayload.appGroup drives where the extension reads the shared '
            'snapshot. If it differs from the entitlement the widget renders '
            'empty data with no error.',
      );
    });

    test('Gradle declares the same application id the widget bridge uses', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('applicationId = "${AppIdentity.bundleId}"'));
      expect(gradle, contains('namespace = "${AppIdentity.bundleId}"'));
    });

    test('the Android manifest action matches the widget bridge constant', () {
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains(AppIdentity.androidCompleteAction),
      );
    });

    test('the manifest label reads the shared string resource', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(
        manifest,
        contains('android:label="@string/app_name"'),
        reason:
            'A literal android:label is a third copy of the app name. Use the '
            'resource so the stamp owns exactly one of them.',
      );
    });

    test('macOS exposes the product name, not the Dart package name', () {
      final xcconfig = File('macos/Runner/Configs/AppInfo.xcconfig')
          .readAsStringSync();
      expect(xcconfig, contains('PRODUCT_NAME = ${AppIdentity.appName}'));
      expect(
        xcconfig,
        isNot(contains('PRODUCT_NAME = ${AppIdentity.packageName}')),
        reason:
            'macOS substitutes PRODUCT_NAME into MainMenu.xib, so leaving the '
            'Dart package name here makes the menu bar read "standup_app".',
      );
    });
  });
}
