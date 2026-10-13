# StandUp repository instructions

## Project constraints

- This is a Flutter/Dart application. The verified local toolchain is Flutter 3.47.4 and Dart 3.13.3; the package requires Dart `^3.13.3`. Do not upgrade SDKs or dependencies without a specific compatibility reason and a verified baseline.
- Preserve the offline-first design: Drift/SQLite is the local source of truth. Keep raw reminder events and timestamps on-device unless a privacy-reviewed design explicitly changes that boundary.
- Keep the dependency direction documented in `docs/ARCHITECTURE.md`: UI calls `AppState`; state coordinates services and repositories; reusable domain rules belong in pure models where practical.
- French is the default language and English is supported. Any user-visible copy must use the translation dictionary and receive bilingual coverage.
- Wellness metrics must remain deterministic. Keep local Dart guidance as the baseline/fallback. Optional company AI guidance is allowed only through the authenticated Supabase Edge Function, behind its own default-off local opt-in and a manual request; send only the `GuidanceInput.toModelInput()` allowlist and validate typed output before rendering localized copy. Never put model credentials in Flutter code or send raw events, timestamps, identity, or free-form notes to the model.
- Keep individual feedback and activity inputs local. Do not upload them to Supabase as part of organization aggregates.

## Data and reminder safety

- `lib/data/local/app_database.dart` is the Drift schema source. Any schema change needs a versioned, data-preserving migration and tests from prior schema versions. Regenerate and review `app_database.g.dart`; never hand-edit generated code.
- Treat reminder logs as source events. Keep event writes, derived counters, deduplication, and sync state consistent and idempotent. Do not delete or reset local user data to make a migration or test pass.
- Use `StandWindow` and `AppCadence` as the shared authority for action-window and cadence rules. Cover quiet hours, work schedules, device-local dates, clock changes, DST transitions, resume, and notification-action races.
- Do not claim background notification delivery on a platform without a build and platform-specific verification. Follow the limits in `docs/PLATFORM_SETUP.md` and `docs/INSTALL_AND_LAUNCH.md`.

## Supabase security and privacy

- The client may contain only the Supabase URL and publishable key. Never add a service-role or secret key to Dart code, assets, build args committed to source, or logs.
- Keep RLS enabled. Do not weaken policies or expose individual reminder logs/timestamps to administrators. Organization analytics must remain server-validated, admin-scoped, and cohort-protected.
- Validate invite and sync changes against both SQL scripts and `test/supabase_privacy_test.dart`. Static SQL tests do not replace live RLS tests when a configured project is available.

## Verification

- Before a change, inspect `git status` and preserve existing user modifications.
- For Dart changes, run `dart format --output=none --set-exit-if-changed lib test tool`, `flutter analyze --fatal-infos --fatal-warnings`, and the relevant tests; run `flutter test` for changes affecting shared behavior.
- After Drift schema edits, run `dart run build_runner build` and verify generated code is current.
- Run a platform build only when its required toolchain is available. Record unavailable SDKs and OS-only targets; never report an unrun build as passing.
- Keep fixes focused and independently reviewable. Update README/docs when behavior, privacy promises, or supported-platform limits change.
