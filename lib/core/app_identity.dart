/// Every identifier the app owns, in one place.
///
/// ## Why this file exists
///
/// An audit of the repository found the app's identity scattered across nine
/// files and split across two incompatible spellings:
///
///  * `com.healthwellness.standup_app` (Android, Linux, Windows, web)
///  * `com.healthwellness.standupApp` (iOS, macOS, iOS App Group)
///
/// and the display name `CNPS StandUp` written out twelve times across eight
/// files, none of them derived from anything. The two spellings are not
/// cosmetic: `WidgetBridge` hard-codes the Android `applicationId` to address
/// the launcher widget, and the iOS App Group appears in two separate
/// `.entitlements` files whose own comments warn that drift fails silently. A
/// rename that missed one site would leave a widget that never updates, with
/// nothing in the build to say so.
///
/// ## How the native side stays in sync
///
/// Dart cannot write to Gradle, Xcode, CMake, `.rc`, `.desktop`, `manifest.json`
/// or Inno Setup at build time, so those files still carry literal copies. The
/// constants below are the single source of truth, and
/// `tool/stamp_identity.dart` propagates them into the native files and fails
/// loudly when any native file has drifted. `test/identity_test.dart` asserts the
/// Dart side matches both `pubspec.yaml` and the stamped native files.
///
/// If you change an identifier here, run `dart run tool/stamp_identity.dart`
/// and commit the result in the same change. Never edit the native copies by
/// hand; the stamp script is what makes drift detectable.
library;

/// Application identity, naming, and platform-registered identifiers.
abstract final class AppIdentity {
  /// The product name as displayed to users.
  static const String appName = 'CNPS StandUp';

  /// The short name for spaces too narrow for [appName]: launcher labels, the
  /// Windows notification app name, the Linux `.desktop` `Name` fallback.
  static const String shortName = 'StandUp';

  /// The organisation the app ships for. Used in legal and installer metadata.
  static const String organisation = 'CNPS';

  /// The organisation's full name, for installer and About text.
  static const String organisationFullName =
      'Caisse Nationale de la Prévoyance Sociale';

  /// The copyright line shown by the Windows and macOS installers and About
  /// boxes. The authoritative statement is the `LICENSE` file; this mirrors it
  /// for the places a platform insists on a metadata string.
  static const String legalCopyright =
      'Copyright (C) 2026 Mony Aye Tigana. All rights reserved.';

  /// The Dart package name. This is also the local database filename stem.
  ///
  /// Deliberately *not* renamed to match [bundleId]. Renaming it would touch
  /// every `package:` import in the project for no user-visible benefit, and the
  /// database filename is the one identifier where a change silently discards
  /// every existing install's history. Keep it stable.
  static const String packageName = 'standup_app';

  // ── Platform-registered identifiers ─────────────────────────────────────────

  /// The reverse-DNS application identifier.
  ///
  /// Set on Android (`applicationId` + `namespace`), Linux (`APPLICATION_ID`
  /// and `StartupWMClass`), and Windows (`CompanyName`/`appUserModelId`).
  ///
  /// On Android and Linux this is now a *free* rename only while the app is
  /// unpublished: once a build reaches the Play Store the `applicationId` is
  /// permanent, and an update with a different one is rejected as a different
  /// app. That is why this is worth changing now, at 1.0.0, and expensive later.
  static const String bundleId = 'com.cnps.standup';

  /// The Apple bundle identifier.
  ///
  /// Must match an App ID registered in the Apple Developer account. Unlike
  /// [bundleId] this cannot simply be changed: the provisioning profile and the
  /// App Group entitlement below are validated against the registered team and
  /// bundle ID at build time.
  static const String appleBundleId = 'com.cnps.standup';

  /// The WidgetKit extension's bundle identifier, nested under [appleBundleId].
  ///
  /// Injected into `ios/Runner.xcodeproj` by `scripts/ios/add_widget_target.rb`.
  static const String iosWidgetBundleId = '$appleBundleId.StandUpWidget';

  /// The App Group that lets the iOS WidgetKit extension read the payload the
  /// main app writes.
  ///
  /// Appears in `ios/Runner/Runner.entitlements` and
  /// `ios/StandUpWidget/StandUpWidget.entitlements`, and is registered on the
  /// Apple Developer account as a group identifier. The two entitlements must
  /// match each other exactly; a mismatch produces a widget extension that
  /// builds, installs, and never receives an update.
  static const String appGroupId = 'group.$appleBundleId';

  /// The qualified Android launcher-widget provider class.
  ///
  /// This is derived from [bundleId] and must match the Kotlin package
  /// declaration in `StandUpWidgetProvider.kt`. `WidgetBridge` registers this
  /// string with `home_widget`, and Android resolves it to instantiate the
  /// receiver — a mismatch means the widget renders stale or empty data.
  static const String androidWidgetProvider =
      '$bundleId.widget.StandUpWidgetProvider';

  /// Android broadcast action fired when a break is completed from the widget.
  static const String androidCompleteAction = '$bundleId.action.COMPLETE_BREAK';

  // ── URL schemes ────────────────────────────────────────────────────────────

  /// The custom scheme used for the Supabase OAuth / magic-link callback.
  ///
  /// Registered by `AndroidManifest.xml`, `ios/Runner/Info.plist` and
  /// `macos/Runner/Info.plist`. Note it is a *redirect* scheme, not an app
  /// identifier: changing it invalidates in-flight auth links, so it is kept
  /// stable even across an identity rebrand.
  static const String authScheme = 'standup';

  /// The full redirect URL handed to Supabase on every platform except web.
  static const String authRedirectUrl = '$authScheme://login-callback';

  /// The scheme used by the launcher widget's own deep links.
  static const String widgetScheme = 'CNPSwidget';

  /// Fired by the widget when the user completes a break from it.
  static const String widgetCompleteUri = '$widgetScheme://complete';

  /// Fired by the widget when the user taps it to open the app.
  static const String widgetOpenUri = '$widgetScheme://open';

  // ── Local storage ───────────────────────────────────────────────────────────

  /// The on-device SQLite filename, under the platform documents directory.
  static const String databaseFileName = '$packageName.sqlite';

  /// The database name used by the web (WASM) build, where there is no file.
  static const String databaseName = packageName;

  // ── Windows ─────────────────────────────────────────────────────────────────

  /// The Windows toast activation identifier.
  ///
  /// Windows uses this to route a notification click back to the right app when
  /// several are installed. It must be a valid URI-safe string and is written
  /// into `Runner.rc` as `CompanyName`.
  static const String windowsCompanyName = bundleId;

  /// Shown by the Windows notification plugin as the source of a toast.
  static const String windowsNotificationAppName = shortName;

  /// The Linux desktop-entry `StartupWMClass`, which must equal
  /// `APPLICATION_ID` in `linux/CMakeLists.txt` or the window cannot be
  /// associated with its launcher icon.
  static const String linuxApplicationId = bundleId;

  // ── Web ─────────────────────────────────────────────────────────────────────

  /// The web manifest `id`, which must match the application identity so a
  /// PWA installed to the home screen keeps its storage across releases.
  static const String webAppId = bundleId;

  /// The Android application ID, without the widget suffix. Used by the Windows
  /// toast id and by the widget bridge.
  static const String androidApplicationId = bundleId;

  // ── Version ─────────────────────────────────────────────────────────────────

  /// The marketing version, mirroring `version:` in `pubspec.yaml`.
  ///
  /// The app cannot read its own pubspec at runtime, so this constant is the
  /// Dart-side copy and `test/identity_test.dart` fails if the two diverge. The
  /// installer script (`scripts/windows/standup.iss`) carries a third copy for
  /// the same reason; `stamp_identity.dart` propagates this value into it.
  static const String version = '1.0.1';

  /// The build number, mirroring the `+N` suffix in `pubspec.yaml`.
  static const int buildNumber = 2;

  /// The full `version+build` string, as Android reports it and as
  /// `DeviceProfile` records it.
  static String get versionAndBuild => '$version+$buildNumber';
}
