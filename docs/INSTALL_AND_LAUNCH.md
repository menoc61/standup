# Install and launch StandUp

This guide covers local development and test builds for Android, Windows, iOS, macOS, Linux, and web. It is a Flutter application with Drift/SQLite local storage. Supabase is optional: without project credentials, the app runs in local-only mode.

> **Downloading a release?** As of v1.0.1, published releases contain **Android,
> Windows, Linux and Web** builds. There is no iOS or macOS download: the Apple
> build has never completed, for the reason in
> [PLATFORM_SETUP.md](PLATFORM_SETUP.md#ios-and-macos-are-not-currently-in-a-release).

The interface starts in French for CNPS Cameroon. Select **English** in Settings to switch languages; the selection is stored on the device. CNPS branding does not imply that cloud accounts are connected: the CNPS Supabase project URL and publishable key must be supplied separately.

## Requirements

- Flutter **3.47 or newer** and Dart **3.13 or newer** (`flutter --version`).
- Run `flutter doctor -v` and resolve the checks for the target platform.
- **Windows desktop:** Visual Studio 2022 or Visual Studio Build Tools with **Desktop development with C++**, the MSVC toolset, CMake tools, and a Windows SDK. Android Studio alone does not supply the MSVC compiler Flutter needs.
- **Android:** Android SDK/platform tools and an enabled USB-debugging device or emulator. Accept the device authorization dialog; on some OEM builds, also enable the OS's “Install via USB” developer option.
- **iOS/macOS:** a Mac with Xcode and the matching Apple platform SDKs.
- **Linux:** the Flutter Linux desktop dependencies, CMake, Ninja, and a C++ compiler.

## Get the project ready

From the project root:

```bash
flutter pub get
flutter analyze
flutter test
```

The database's generated Drift source is committed. If you change database tables, regenerate it with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Start the app

List the targets Flutter can see, then use the exact device ID shown:

```bash
flutter devices
flutter run -d <device-id>
```

Common IDs include `windows`, `chrome`, `android`, and `ios` when their respective platform toolchains are installed.

### Android phone or emulator

```bash
flutter run -d <device-id>
flutter build apk --debug
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. Install it over USB with:

```bash
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-debug.apk
```

For a locally testable release-mode APK, use `flutter build apk --release`. Store distribution requires a separately configured signing key; do not use the debug signing key for a public release.

### Windows desktop

#### Installing a release (for most people)

Each GitHub release ships a `standup-<version>-windows-x64-setup.exe`. Download
it and run it. It installs per-user, so there is **no administrator prompt** and
it works on machines where you cannot install software system-wide. You get a
Start Menu entry, a desktop shortcut and a proper Add/Remove Programs entry.

The same release also ships `standup-<version>-windows-x64.zip`. That is the
raw build folder — use the installer unless you specifically need the portable
copy.

> **Windows may warn you.** The binaries are not code-signed, so Windows
> SmartScreen shows a blue *"Windows protected your PC"* dialog. The packaging
> does not change that — SmartScreen judges the signature, not the file format.
> To proceed: click **More info**, then **Run anyway**. Only do this for a
> build you obtained from this project's own releases.
>
> Signing is the real fix and is not wired up yet; see the note in
> [LICENSE](LICENSE) and the `SignToolCommand` hook in
> `scripts/windows/standup.iss`.

#### Where your data lives

Nothing the app writes sits inside the install folder, so uninstalling never
destroys your history:

| Data | Location |
| --- | --- |
| Break history, streaks, analytics | `%USERPROFILE%\Documents\standup_app.sqlite` |
| Language, accent and reminder settings | `%APPDATA%\com.cnps.standup\CNPS StandUp\shared_preferences.json` |

To fully remove the app, uninstall it from Add/Remove Programs and then delete
those two files.

The database filename is `standup_app.sqlite`, deliberately not
`com.cnps.standup.sqlite`: it comes from the Dart package name via
`AppIdentity.databaseFileName`, and renaming it would silently discard every
existing install's history rather than migrate it.

> **Not yet verified on a real Windows build.** The settings path is derived from
> the `CompanyName` and `ProductName` fields in `windows/runner/Runner.rc`, which
> `path_provider` reads from the executable's version resource. Both are now
> stamped from `AppIdentity` by `tool/stamp_identity.dart`, so the value above
> should be correct — but no Windows build has been produced in this environment,
> so treat the exact folder name as unconfirmed until one is installed and
> inspected.

> **Note for upgraders.** Renaming `CompanyName` from `com.healthwellness` to
> `com.cnps.standup` changed the folder `path_provider` resolves, so Windows
> looks in a new location and your language, accent and reminder settings reset to
> defaults once. Your break history in `Documents` is untouched. This is a
> deliberate consequence of adopting one CNPS-branded identifier across all
> platforms; it happens once, and no later build will repeat it.

#### Building it yourself

After installing the Visual Studio C++ workload and restarting the terminal:

```powershell
flutter doctor -v
flutter run -d windows
flutter build windows --release
```

The release bundle is under `build/windows/x64/runner/Release/`. Launch `standup_app.exe` from that directory; keep the adjacent DLLs and `data` directory with it. For a test build without packaging, use `flutter build windows --debug` and launch the executable under `build/windows/x64/runner/Debug/`.

To also produce the installer locally, install Inno Setup
(`winget install JRSoftware.InnoSetup`) and run the release command — it builds
both the zip and the setup executable into `dist/`.

### Web, iOS, macOS, and Linux

```bash
flutter run -d chrome
flutter run -d ios       # macOS + Xcode
flutter run -d macos     # macOS + Xcode
flutter run -d linux     # Linux desktop toolchain
```

Build artifacts:

```bash
flutter build web --release
flutter build ios --release       # macOS + Xcode; signing may be required
flutter build macos --release     # macOS + Xcode
flutter build linux --release    # Linux desktop toolchain
```

Each GitHub release now also ships `standup-<version>-web.zip`, a static bundle
you can host anywhere.

> **`flutter build web --release` alone produces a bundle that fails at
> runtime.** The Flutter tool knows nothing about Drift, so `sqlite3.wasm` and
> `drift_worker.js` are left out and the app throws on its first database query.
> Use `./scripts/standup.sh build web release`, which copies both in from the
> resolved `drift` package. The release workflow does exactly this and then
> asserts both files are present.

## Release builds

All release commands run from the project root after `flutter pub get`. The
project already enables R8 minification and resource shrinking for Android.

### Android — signing first

Release builds fall back to the debug key when `key.properties` is absent, which
is fine for local testing but **cannot be uploaded to Google Play**. To produce a
store-signed build:

1. Generate an upload keystore (once, and keep it backed up):

   ```bash
   keytool -genkey -v -keystore ~/standup-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (never commit this file):

   ```properties
   storePassword=<keystore password>
   keyPassword=<key password>
   keyAlias=upload
   storeFile=/absolute/path/to/standup-upload.jks
   ```

3. Build. Gradle picks up the release signing config automatically.

   ```bash
   flutter build apk --release        # single APK  -> build/app/outputs/flutter-apk/app-release.apk
   flutter build appbundle --release  # Play bundle -> build/app/outputs/bundle/release/app-release.aab
   ```

### Desktop and other targets

```bash
flutter build windows --release   # build/windows/x64/runner/Release/
flutter build macos --release     # build/macos/Build/Products/Release/  (macOS + Xcode)
flutter build linux --release     # build/linux/x64/release/bundle/     (Linux toolchain)
flutter build ios --release       # build/ios/Runner/                  (macOS + Xcode, signing required)
flutter build web --release       # build/web/
```

Supply Supabase credentials at build time when cloud features are needed:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Without those defines the app still builds and runs fully offline against the
local Drift database.

## Optional Supabase connection

1. Create a Supabase project and apply the repository's [`supabase_schema.sql`](../supabase_schema.sql) in that project's SQL editor.
2. Enable the auth providers you intend to use. Configure redirect URLs and provider credentials in Supabase; OAuth provider sign-in is only available where its callback can be registered.
3. Run with the project URL and **publishable** client key:

   PowerShell:
   ```powershell
   flutter run -d <device-id> --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
   ```

   Bash:
   ```bash
   flutter run -d <device-id> \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
   ```

Never put a Supabase service-role/secret key in this client app. Supabase auth, organization membership, and aggregate analytics also require the configured project schema, RLS policies, and real organization provisioning. If those aren't present, local reminders and analytics remain available, while cloud-only controls report that the service is unavailable.

## Platform behavior

| Platform | Layout and input | Reminders and feedback |
| --- | --- | --- |
| Android | Compact bottom navigation; touch, swipe onboarding, haptics | Local notifications and Android notification actions; the OS may restrict exact alarms or background delivery until permission is granted. |
| iOS | Compact navigation; touch, swipe onboarding, haptics | Apple local notification permissions and OS scheduling rules apply. |
| Windows/macOS | Sidebar, keyboard shortcuts, pointer hover and click | Desktop notification integration depends on OS notification settings. Haptics are unavailable on most desktop hardware. |
| Linux | Sidebar and keyboard shortcuts | A foreground timer is used by the current Linux notification implementation; keep the app running. |
| Web | Responsive layout, pointer/keyboard and touch | Keep the tab open for visible countdown and reminder audio; browser background/closed-tab delivery is not provided by this implementation. |

Motion uses Flutter's `Animated*` widgets, `flutter_animate`, `GestureDetector`, pointer events, and the existing spring button. The UI honors the platform reduced-motion signal for the shell transition and press scaling. These are Flutter-native equivalents for this stack; GSAP and React Native Gesture Handler target other frameworks.

The custom posture/workspace artwork is drawn in Flutter's `CustomPainter`, so it remains crisp at different pixel densities and does not depend on a remote image host.

Mobile and desktop reminders are scheduled with native local-notification APIs. StandUp maintains 48 upcoming alerts and refreshes the queue on startup, app resume, and reminder actions. This avoids relying on an exact-time Dart background job: iOS may defer background refresh, while Android vendors can restrict alarm delivery. On Xiaomi/Redmi, allow notifications, exact alarms, autostart/background activity, and unrestricted battery use for StandUp. Linux currently uses foreground timers; the browser requires its tab to stay open. A 48-alert queue is finite and can run out if the app is never reopened or used after the queue is exhausted.

## Design references and source availability

- [Apple Human Interface Guidelines: Motion](https://developer.apple.com/design/human-interface-guidelines/motion) recommends purposeful, brief motion, gesture-consistent feedback, and motion alternatives.
- [Material 3: Motion](https://m3.material.io/styles/motion) describes expressive versus standard motion and spring-based feedback.
- [Flutter desktop support](https://docs.flutter.dev/platform-integration/desktop) and [Windows build guide](https://docs.flutter.dev/platform-integration/windows/building) cover native desktop build requirements.
- The provided Stitch project ID was checked in the signed-in browser, but Stitch returned that the project page does not exist or is not shared with this account. The interface implementation follows the supplied onboarding and feature specification until the project is shared with this account.

## Troubleshooting

- **`Unable to find suitable Visual Studio toolchain`:** install Visual Studio 2022/Build Tools with the C++ desktop workload, then run `flutter doctor -v` again.
- **Phone install reports user-restricted:** unlock the phone, accept its install prompt, and check the OEM's “Install via USB” setting.
- **Redmi reminders arrive late or stop:** enable StandUp notifications and exact alarms, allow autostart/background activity, and remove it from battery restrictions. Exact delivery remains subject to Android/OEM policy.
- **Cloud sign-in or org analytics unavailable:** configure Supabase URL/publishable key and the project schema, auth providers, redirects, RLS, and organization data.
- **No reminders after closing a Linux app or browser tab:** this is a current platform limitation; keep the app/tab running for those targets.
- **Release signing:** Android store builds and Apple distribution builds need the platform's own release signing configuration.
