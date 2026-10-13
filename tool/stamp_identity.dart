/// Propagates the identifiers in `lib/core/app_identity.dart` into every native
/// and declarative file that cannot read Dart at build time, and fails when any
/// of them has drifted.
///
/// ## Why a script instead of build-time generation
///
/// Gradle, Xcode, CMake, the Windows `.rc` compiler, the freedesktop `.desktop`
/// spec, `manifest.json` and Inno Setup all read literals. A Dart constant
/// cannot reach any of them during a normal build. That leaves two options:
///
///  * hand-edit nine files per rename and hope, or
///  * declare the identifiers once in Dart, stamp them out here, and verify.
///
/// This is the second option. Run it after changing `AppIdentity`:
///
/// ```
/// dart run tool/stamp_identity.dart          # apply
/// dart run tool/stamp_identity.dart --check  # verify only, non-zero on drift
/// ```
///
/// `test/identity_test.dart` runs the `--check` path, so drift fails CI instead
/// of producing a widget that silently stops updating.
///
/// ## What it will not do
///
/// It rewrites values it recognises but it does not invent them. A new platform
/// folder, or a native file this script has never seen, is reported as
/// unverified rather than silently ignored — that is the whole point.
library;

import 'dart:io';

import 'package:standup_app/core/app_identity.dart';

/// One literal to push into a file, and how to recognise it.
class _Rule {
  const _Rule({
    required this.path,
    required this.find,
    required this.replace,
    this.description,
  });

  final String path;

  /// A regular expression whose first capture group (if any) is the value to
  /// replace.
  final String find;
  final String Function(Match) replace;
  final String? description;
}

final List<_Rule> _rules = [
  // ── Android ────────────────────────────────────────────────────────────────
  _Rule(
    path: 'android/app/build.gradle.kts',
    find: r'(namespace\s*=\s*")[^"]+(")',
    replace: (m) => '${m.group(1)}${AppIdentity.bundleId}${m.group(2)}',
    description: 'Gradle namespace',
  ),
  _Rule(
    path: 'android/app/build.gradle.kts',
    find: r'(applicationId\s*=\s*")[^"]+(")',
    replace: (m) => '${m.group(1)}${AppIdentity.bundleId}${m.group(2)}',
    description: 'Gradle applicationId',
  ),
  _Rule(
    path: 'android/app/src/main/AndroidManifest.xml',
    find: r'(android:label=")[^"]+(")',
    replace: (m) => '${m.group(1)}@string/app_name${m.group(2)}',
    description: 'Android application label -> @string/app_name',
  ),
  _Rule(
    path: 'android/app/src/main/AndroidManifest.xml',
    find: r'(<action android:name=")[^"]*COMPLETE_BREAK(")',
    replace: (m) =>
        '${m.group(1)}${AppIdentity.androidCompleteAction}${m.group(2)}',
    description: 'widget-complete broadcast action',
  ),
  _Rule(
    path: 'android/app/src/main/res/values/strings.xml',
    find: r'(<string name="app_name">)[^<]*(</string>)',
    replace: (m) => '${m.group(1)}${AppIdentity.appName}${m.group(2)}',
    description: 'Android app_name resource',
  ),
  _Rule(
    path: 'android/app/src/main/kotlin/com/cnps/standup/MainActivity.kt',
    find: r'(package\s+)[a-z0-9_.]+(\s*$)',
    replace: (m) => '${m.group(1)}${AppIdentity.bundleId}${m.group(2)}',
    description: 'MainActivity Kotlin package',
  ),
  _Rule(
    path: 'android/app/src/main/kotlin/com/cnps/standup/widget/StandUpWidgetProvider.kt',
    find: r'(package\s+)[a-z0-9_.]+(\s*$)',
    replace: (m) => '${m.group(1)}${AppIdentity.bundleId}.widget${m.group(2)}',
    description: 'Widget provider Kotlin package',
  ),

  // ── iOS / macOS ────────────────────────────────────────────────────────────
  _Rule(
    path: 'ios/Runner/Info.plist',
    find: r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
    replace: (m) => '${m.group(1)}${AppIdentity.appName}${m.group(2)}',
    description: 'iOS display name',
  ),
  _Rule(
    path: 'ios/Runner/Info.plist',
    find: r'(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)',
    replace: (m) => '${m.group(1)}${AppIdentity.packageName}${m.group(2)}',
    description: 'iOS bundle name',
  ),
  _Rule(
    path: 'ios/Runner/Runner.entitlements',
    find: r'(<string>)[^<]*(</string>)',
    replace: (m) => '${m.group(1)}${AppIdentity.appGroupId}${m.group(2)}',
    description: 'iOS App Group entitlement',
  ),
  _Rule(
    path: 'ios/StandUpWidget/StandUpWidget.entitlements',
    find: r'(<string>)[^<]*(</string>)',
    replace: (m) => '${m.group(1)}${AppIdentity.appGroupId}${m.group(2)}',
    description: 'iOS widget App Group entitlement',
  ),
  _Rule(
    path: 'ios/StandUpWidget/Info.plist',
    find: r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
    replace: (m) => '${m.group(1)}${AppIdentity.shortName}${m.group(2)}',
    description: 'iOS widget display name',
  ),
  _Rule(
    path: 'macos/Runner/Configs/AppInfo.xcconfig',
    find: r'(PRODUCT_NAME\s*=\s*).*$',
    replace: (m) => '${m.group(1)}${AppIdentity.appName}',
    description: 'macOS product name',
  ),
  _Rule(
    path: 'macos/Runner/Configs/AppInfo.xcconfig',
    find: r'(PRODUCT_BUNDLE_IDENTIFIER\s*=\s*).*$',
    replace: (m) => '${m.group(1)}${AppIdentity.appleBundleId}',
    description: 'macOS bundle identifier',
  ),
  _Rule(
    path: 'macos/Runner/Configs/AppInfo.xcconfig',
    find: r'(PRODUCT_COPYRIGHT\s*=\s*).*$',
    replace: (m) => '${m.group(1)}${AppIdentity.legalCopyright}',
    description: 'macOS copyright',
  ),

  // ── Windows ────────────────────────────────────────────────────────────────
  _Rule(
    path: 'windows/CMakeLists.txt',
    find: r'(project\()[^)]+(\))',
    replace: (m) => '${m.group(1)}${AppIdentity.packageName}${m.group(2)}',
    description: 'CMake project name',
  ),
  _Rule(
    path: 'windows/runner/main.cpp',
    find: r'(window\.Create\(L")[^"]+(",)',
    replace: (m) => '${m.group(1)}${AppIdentity.appName}${m.group(2)}',
    description: 'Windows window title',
  ),
  _Rule(
    path: 'windows/runner/Runner.rc',
    find: r'(VALUE "CompanyName",\s*")[^"]+(")',
    replace: (m) =>
        '${m.group(1)}${AppIdentity.windowsCompanyName}${m.group(2)}',
    description: 'Windows CompanyName / toast id',
  ),
  _Rule(
    path: 'windows/runner/Runner.rc',
    find: r'(VALUE "ProductName",\s*")[^"]+(")',
    replace: (m) => '${m.group(1)}${AppIdentity.appName}${m.group(2)}',
    description: 'Windows ProductName',
  ),
  _Rule(
    path: 'windows/runner/Runner.rc',
    find: r'(VALUE "FileDescription",\s*")[^"]+(")',
    replace: (m) => '${m.group(1)}${AppIdentity.appName}${m.group(2)}',
    description: 'Windows FileDescription',
  ),
  _Rule(
    path: 'windows/runner/Runner.rc',
    find: r'(VALUE "LegalCopyright",\s*")[^"]+(")',
    replace: (m) => '${m.group(1)}${AppIdentity.legalCopyright}${m.group(2)}',
    description: 'Windows copyright',
  ),

  // ── Linux ──────────────────────────────────────────────────────────────────
  _Rule(
    path: 'linux/CMakeLists.txt',
    find: r'(APPLICATION_ID\s+")[^"]+(")',
    replace: (m) =>
        '${m.group(1)}${AppIdentity.linuxApplicationId}${m.group(2)}',
    description: 'Linux APPLICATION_ID',
  ),
  _Rule(
    path: 'linux/runner/standup_app.desktop',
    find: r'(StartupWMClass=).*$',
    replace: (m) => '${m.group(1)}${AppIdentity.linuxApplicationId}',
    description: 'Linux StartupWMClass',
  ),
  _Rule(
    path: 'linux/runner/standup_app.desktop',
    find: r'(Name=).*$',
    replace: (m) => '${m.group(1)}${AppIdentity.appName}',
    description: 'Linux desktop entry name',
  ),

  // ── Web ────────────────────────────────────────────────────────────────────
  _Rule(
    path: 'web/manifest.json',
    find: r'("id"\s*:\s*")[^"]+(")',
    replace: (m) => '${m.group(1)}${AppIdentity.webAppId}${m.group(2)}',
    description: 'PWA manifest id',
  ),
  _Rule(
    path: 'web/manifest.json',
    find: r'("short_name"\s*:\s*")[^"]+(")',
    replace: (m) => '${m.group(1)}${AppIdentity.shortName}${m.group(2)}',
    description: 'PWA short name',
  ),

  // ── Installer ──────────────────────────────────────────────────────────────
  _Rule(
    path: 'scripts/windows/standup.iss',
    find: r'(AppVersion=).*$',
    replace: (m) => '${m.group(1)}${AppIdentity.version}',
    description: 'Inno Setup app version',
  ),
  _Rule(
    path: 'scripts/windows/standup.iss',
    find: r'(AppPublisher=).*$',
    replace: (m) => '${m.group(1)}${AppIdentity.organisation}',
    description: 'Inno Setup publisher',
  ),

  // ── Helper scripts ─────────────────────────────────────────────────────────
  //
  // These shell out to the native toolchains and cannot import Dart, so they
  // carried their own copies of the identifiers. Left alone they would be the
  // one place a rename silently misses, which is exactly the failure mode this
  // script exists to prevent.
  _Rule(
    path: 'scripts/standup.ps1',
    find: r"(\$Script:AndroidPackage\s*=\s*')[^']+(')",
    replace: (m) => '${m.group(1)}${AppIdentity.bundleId}${m.group(2)}',
    description: 'PowerShell Android package',
  ),
  _Rule(
    path: 'scripts/standup.ps1',
    find: r"(\$Script:IOSBundleId\s*=\s*')[^']+(')",
    replace: (m) => '${m.group(1)}${AppIdentity.appleBundleId}${m.group(2)}',
    description: 'PowerShell iOS bundle id',
  ),
  _Rule(
    path: 'scripts/standup.sh',
    find: r'(ANDROID_PACKAGE=")[^"]+(")',
    replace: (m) => '${m.group(1)}${AppIdentity.bundleId}${m.group(2)}',
    description: 'Shell Android package',
  ),
  _Rule(
    path: 'scripts/standup.sh',
    find: r'(IOS_BUNDLE_ID=")[^"]+(")',
    replace: (m) => '${m.group(1)}${AppIdentity.appleBundleId}${m.group(2)}',
    description: 'Shell iOS bundle id',
  ),
  _Rule(
    path: 'scripts/standup.sh',
    find: r'(WIDGET_PROVIDER=")[^"]+(")',
    replace: (m) =>
        '${m.group(1)}${AppIdentity.androidWidgetProvider}${m.group(2)}',
    description: 'Shell widget provider class',
  ),
  _Rule(
    path: 'scripts/icons/generate_icons.py',
    find: r'(APPLICATION_ID\s*=\s*")[^"]+(")',
    replace: (m) => '${m.group(1)}${AppIdentity.bundleId}${m.group(2)}',
    description: 'icon generator application id',
  ),
  _Rule(
    path: 'scripts/ios/add_widget_target.rb',
    find: r"(WIDGET_BUNDLE_ID\s*=\s*')[^']+(')",
    replace: (m) =>
        '${m.group(1)}${AppIdentity.iosWidgetBundleId}${m.group(2)}',
    description: 'iOS widget target bundle id',
  ),
  _Rule(
    path: 'scripts/ios/add_widget_target.rb',
    find: r"(APP_GROUP\s*=\s*')[^']+(')",
    replace: (m) => '${m.group(1)}${AppIdentity.appGroupId}${m.group(2)}',
    description: 'iOS widget App Group',
  ),

  // The Kotlin package directory path itself. The directory has to move when the
  // package is renamed, and a helper script pointing at the old path would
  // report "widget source missing" rather than doing the obvious thing.
  _Rule(
    path: 'scripts/standup.ps1',
    find: r'(kotlin\\)com[\\/][a-z0-9_]+[\\/][a-z0-9_]+([\\/]widget[\\/]StandUpWidgetProvider\.kt)',
    replace: (m) =>
        '${m.group(1)}${AppIdentity.bundleId.replaceAll('.', r'\')}${m.group(2)}',
    description: 'PowerShell widget source path',
  ),
  _Rule(
    path: 'scripts/standup.sh',
    find: r'(kotlin/)[a-z0-9_]+/[a-z0-9_]+/[a-z0-9_]+',
    replace: (m) => '${m.group(1)}${AppIdentity.bundleId.replaceAll('.', '/')}',
    description: 'Shell widget source path',
  ),
  _Rule(
    path: 'scripts/standup.ps1',
    find: r'(kotlin\\)com[\\/][a-z0-9_]+[\\/][a-z0-9_]+',
    replace: (m) =>
        '${m.group(1)}${AppIdentity.bundleId.replaceAll('.', r'\')}',
    description: 'PowerShell widget source path',
  ),
];

/// Native files this script must find, so that a rename or a deleted platform
/// folder is reported rather than passing silently.
const List<String> _requiredFiles = [
  'android/app/build.gradle.kts',
  'android/app/src/main/AndroidManifest.xml',
  'android/app/src/main/res/values/strings.xml',
  'ios/Runner/Info.plist',
  'ios/Runner/Runner.entitlements',
  'ios/StandUpWidget/StandUpWidget.entitlements',
  'macos/Runner/Configs/AppInfo.xcconfig',
  'windows/runner/Runner.rc',
  'windows/CMakeLists.txt',
  'linux/CMakeLists.txt',
  'linux/runner/standup_app.desktop',
  'web/manifest.json',
  'scripts/windows/standup.iss',
];

void main(List<String> args) {
  final checkOnly = args.contains('--check');
  final missing = <String>[];
  final changed = <String>[];
  final unmatched = <String>[];

  for (final path in _requiredFiles) {
    if (!File(path).existsSync()) {
      missing.add(path);
    }
  }

  for (final rule in _rules) {
    final file = File(rule.path);
    if (!file.existsSync()) {
      unmatched.add('${rule.path} — file missing (${rule.description})');
      continue;
    }
    final before = file.readAsStringSync();
    final pattern = RegExp(rule.find, multiLine: true);
    if (!pattern.hasMatch(before)) {
      unmatched.add('${rule.path} — no match for ${rule.description}');
      continue;
    }
    final after = before.replaceAllMapped(pattern, rule.replace);
    if (after == before) continue;

    changed.add(rule.path);
    if (!checkOnly) file.writeAsStringSync(after);
  }

  for (final path in changed) {
    stdout.writeln(checkOnly ? '  DRIFT  $path' : '  stamp  $path');
  }
  for (final problem in [...missing, ...unmatched]) {
    stderr.writeln('  ERROR  $problem');
  }

  stdout.writeln('');
  stdout.writeln(
    'identity: ${changed.length} file(s) ${checkOnly ? 'out of date' : 'stamped'}, '
    '${missing.length} missing, ${unmatched.length} unmatched',
  );
  stdout.writeln('  bundleId  ${AppIdentity.bundleId}');
  stdout.writeln('  appGroup  ${AppIdentity.appGroupId}');
  stdout.writeln('  appName   ${AppIdentity.appName}');
  stdout.writeln('  version   ${AppIdentity.versionAndBuild}');

  if (missing.isNotEmpty || unmatched.isNotEmpty) {
    stderr.writeln('\nSome native files could not be verified.');
    exitCode = 2;
  } else if (checkOnly && changed.isNotEmpty) {
    stdout.writeln(
      '\nRun `dart run tool/stamp_identity.dart` to apply, and commit the result.',
    );
    exitCode = 1;
  }
}
