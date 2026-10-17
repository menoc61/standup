# StandUp Phase 1 Audit

**Audit date:** 2026-10-13
**Scope:** Initial Phase 1 findings are a baseline snapshot from before the implementation follow-ups below. Each follow-up records the changes and current verification for its scope.
**Evidence:** Source/documentation review, local Flutter/Dart checks, Android and web builds. Supabase behavior was reviewed statically; no CNPS Supabase project was configured for live verification.

## Executive summary

StandUp is a Flutter application with a local Drift/SQLite source of truth, a single `AppState` coordinator, native/local notification delivery, optional Supabase authentication and aggregate analytics, and responsive French/English UI. The project explicitly documents limits for Linux/browser reminders and OEM delivery. The SQL definitions inspected use per-user RLS, scoped profile grants, server-derived organization membership, admin-only aggregate views, and a minimum cohort of five. No service-role key or JWT-like credential pattern was found in scanned repository files.

The baseline snapshot below found issues in scheduling, guidance, and verification. Later follow-ups in this document record the implementation of working-hour scheduling, deterministic local guidance, consent-gated company AI through a Supabase proxy, and current Flutter checks/build results. The live company AI path and several integration/device/timezone checks remain open because the required company endpoint, Supabase project, and test devices are not configured here.

No P0 finding was established. P1 findings below block CI or materially affect the core reminder/data contract. P2 findings affect metric accuracy, timezone correctness, privacy promises, or expected interaction behavior. P3 findings are documentation drift.

## Verified structure and architecture

- `lib/main.dart` is the composition root. `AppState` owns reminder state, action validation, day totals, sync orchestration, and lifecycle resume handling.
- `lib/core/` contains theme, strings, identity, cadence, and platform behavior; `lib/data/local/` contains Drift schema, generated ORM, repository, and widget bridge; `lib/data/remote/` contains Supabase; `lib/services/` contains notifications, countdown, audio, haptics, and Android background settings; `lib/ui/` contains adaptive layout, screens, and widgets.
- Drift schema version is 4 in `lib/data/local/app_database.dart`. Migrations add opt-out statistics, sound/quiet-hours/goal fields, and action-window fields. Generated code is present at `lib/data/local/app_database.g.dart`. CI includes a build-runner freshness check; that code-generation check was not run separately in this audit.
- `StandWindow` is the shared local-time action-window rule. `AppCadence` centralizes cadence and queue constants. The app rebuilds a rolling 48-alert queue on initialization/resume and after actions/preferences. Android declares the notification boot receiver. Linux uses foreground timers; the documentation describes browser reminders as requiring an open tab.
- `supabase_schema.sql` and `supabase_validation.sql` define profile/log ownership policies, aggregate views, invite joining, and a server-side daily analytics RPC. Static review found both org views apply an admin predicate and a five-person cohort floor. `test/supabase_privacy_test.dart` guards those SQL properties, but it is source-text testing rather than a live RLS test.
- `README.md` describes the user-facing feature set and platform limits. Some claims are ahead of the implementation, including work-hour boundaries, peak skip-hour analytics, and the current reminder-control file/layout.
- The current shell groups the daily destinations as Timer, Leaderboard, and Analytics (`lib/ui/screens/main_shell.dart:116-123,272-310`). Settings is a pushed route. Its sections already group Profile & Team (`lib/ui/screens/settings_screen.dart:591-702`) and Reminder Cadence & Notifications (`:703-830`). On compact layouts the trailing gear and reminder bell are separate controls; on expanded layouts the account button is the Settings entry point. The mobile/desktop entry points are mutually exclusive responsive layouts, not duplicate simultaneous pages. Profile editing and notification permission controls are not standalone primary tabs.
- Existing UI-focused tests cover responsive breakpoints (`test/adaptive_layout_test.dart`), palette contrast (`test/contrast_test.dart`), segmented-choice semantics/keyboard behavior (`test/segmented_choice_test.dart`), and empty leaderboard states (`test/leaderboard_test.dart`). These are useful source-level checks; no real-device screen-reader, permission-prompt, or notification-delivery session was run in this audit. Startup has no rendered Flutter loading surface until asynchronous initialization finishes (F-09), and the sync labels/timeouts have separate issues (F-16/F-17).
- There is no AI or recommendation dependency/service/model under `lib/`, and no recommendation tests. `UserPreferences` stores explicit goals and settings (`lib/data/models/user_preferences.dart:21-44`); `DailyAnalytics` stores summaries (`lib/data/models/daily_analytics.dart:1-11`); neither includes a feedback signal or a recommendation result. Current analytics and streaks are deterministic calculations, not personalized suggestions.
- No `AGENTS.md` exists in the repository or its parent directories. A proposed root file was added at [AGENTS.md](../AGENTS.md).
- The checkout already contained uncommitted changes in README, dependency files, database/model/state/UI files, a removed `reminder_fab.dart`, and new cadence/navigation files. Those changes were preserved. The audit describes the current working tree, not a clean `main` checkout.

## SDK and baseline results

The installed toolchain is Flutter **3.47.4 stable** with Dart **3.13.3**. The package constraint is `sdk: ^3.13.3`; CI pins Flutter 3.47.4. The installed versions match the project constraints.

| Check | Result |
|---|---|
| `flutter --version` | Passed: Flutter 3.47.4, Dart 3.13.3. |
| `flutter pub get --offline --enforce-lockfile` | Passed. Enforced the already-modified lockfile and resolved from cache; no lockfile rewrite was permitted. |
| `dart format --output=none --set-exit-if-changed .` | Failed: `test/cadence_test.dart` would change. Output-only mode did not modify it. 78 Dart files were inspected. |
| `flutter analyze` | Failed with one error: required named parameter `id` missing at `test/cadence_test.dart:30`. |
| `flutter test` | Failed to load two test files. `cadence_test.dart` has the same compile error. The parallel compiler also exited while loading `account_boundary_test.dart`; an isolated rerun passed all 4 tests. The full run reported 208 passing test cases before termination. |
| `flutter test test/account_boundary_test.dart` | Passed: 4 tests. |
| `flutter build apk --debug` | Passed: `build/app/outputs/flutter-apk/app-debug.apk`. Gradle emitted a non-blocking warning that `home_widget` applies Kotlin Gradle Plugin and may need migration for future Flutter releases. |
| `flutter build web --release` | Passed: `build/web`. Flutter emitted the informational Wasm dry-run notice. |
| `flutter doctor -v` | Flutter/web/Chrome and Android SDK are available. Android reports unaccepted licenses and multiple `adb` binaries, although the Android debug build succeeded. Visual Studio C++ workload is absent, so Windows builds are unavailable. iOS/macOS builds require macOS; Linux desktop builds require Linux. |
| Supabase live checks | Not run: no CNPS Supabase project credentials/configuration were supplied. Static SQL review only. |

## Findings

### P1 — F-01: Current test source blocks analysis and CI

**Evidence:** `test/cadence_test.dart:30` constructs `UserPreferences` without its required `id`; `lib/data/models/user_preferences.dart:46` requires it. The same test is the sole file reported by the format check. CI runs analyzer, tests, and formatting in `.github/workflows/ci.yml:34-74`.

**Root cause:** The new cadence test does not match the current model constructor and was not formatted before it entered the working tree.

**Proposed fix:** Supply a stable test `id`, format the file, then rerun analysis, the complete test suite, and the CI-format command.

**Regression risk:** Low. This should only repair the test fixture; avoid changing production defaults to satisfy the test.

**Test plan:** `flutter analyze --fatal-infos --fatal-warnings`; `flutter test`; `dart format --output=none --set-exit-if-changed lib test tool`.

### P1 — F-02: Default reminders can run outside work hours

**Evidence:** `lib/data/models/user_preferences.dart:148-162` defaults `quietHours` to `null`. `lib/services/notification_service.dart:387-438` creates 48 cadence-spaced candidates and filters only explicit quiet hours; it has no weekday, work-start, or work-end rule. The README describes reminders during the workday (`README.md:24-27`) but offers only optional quiet hours (`README.md:131`).

**Root cause:** The schedule model represents cadence and optional quiet time, but no working-day schedule. With defaults, the queue is not bounded to a workday.

**Proposed fix:** Add explicit local working days and start/end preferences, use the same pure schedule calculation for the in-app countdown and OS queue, and select a safe default schedule. Keep quiet hours as an additional suppression window.

**Regression risk:** Medium. A schedule boundary can skip or duplicate a reminder if it disagrees with `StandWindow`, DST, or a user's timezone change.

**Test plan:** Pure schedule tests for workday open/close, weekends, overnight quiet hours, cadence changes, timezone changes, and DST; scheduler tests asserting every queued alert falls inside the selected work schedule.

### P1 — F-03: Reminder events and daily totals are not committed atomically

**Evidence:** `lib/providers/app_state.dart:631-645` checks `_actedWindows`, awaits a database lookup, and only later inserts the completion at `:671-675`; the in-memory claim is added after the writes at `:680`. Two concurrent completion paths can both pass the asynchronous check. `ReminderLogsTable` has only a random row ID as its key (`lib/data/local/app_database.dart:59-71`), not a user/window uniqueness rule. The completion log and daily update are also separate awaited calls. The same log-then-aggregate ordering exists for snooze and skip at `app_state.dart:717-720` and `747-750`; `updateAnalytics` (`lib/data/local/local_repository.dart:290-324`) transacts only its read/modify/write.

**Root cause:** The check-then-insert completion guard is not atomic across concurrent taps, and the source event and aggregate counter update have different transaction boundaries. A race can record two completions in one window; a process exit or database error between writes can leave permanent disagreement. Daily analytics are incremented independently rather than rebuilt from event rows.

**Proposed fix:** Add a repository operation that claims a completion window, inserts one action event, and updates that day's counters in the same Drift transaction. Enforce idempotency with a durable user/window key; provide a reconciliation path for existing data before relying on summaries as source of truth.

**Regression risk:** Medium. Transaction retries, notification actions, and existing row IDs must not produce duplicate counts; migration must preserve local history.

**Test plan:** Run concurrent completion calls from two `AppState` instances against one database and assert one event/count; inject a failure between insert/update and assert rollback; test retry idempotency; compare stored daily totals with totals derived from reminder logs.

### P1 — F-04: Cloud counter merging loses activity from concurrent devices

**Evidence:** `LocalDatabaseRepository.mergeRemoteAnalytics` uses a per-field maximum (`lib/data/local/local_repository.dart:346-368`). The server RPC also updates each field with `GREATEST(existing, incoming)` (`supabase_validation.sql:164-170`).

**Root cause:** Each device syncs a cumulative local snapshot, while max is used as the conflict strategy. If two devices each collect distinct offline activity on the same date, the larger snapshot replaces the smaller contribution rather than combining distinct events.

**Proposed fix:** Define the account/device sync contract and use an event/outbox identity or server-side per-device counters so retries are idempotent and distinct offline actions merge additively. Do not simply sum replayed snapshots.

**Regression risk:** High. A naive additive change would double-count retries and existing rows; retain server validation and privacy boundaries.

**Test plan:** Simulate two device snapshots, reordered delivery, replay, and offline catch-up; verify exact totals and stable results after retries in both repository tests and SQL/RPC tests.

### P2 — F-05: Adherence denominator is an action count, not delivered reminders

**Evidence:** `LocalDatabaseRepository.updateAnalytics` increments `remindersSent` for every action (`lib/data/local/local_repository.dart:299-318`). `DailyAnalytics.adherenceRate` divides completions by that field (`lib/data/models/daily_analytics.dart:31-35`), and the org views use the same denominator (`supabase_schema.sql:252-271`, `supabase_validation.sql:231-261`). A reminder with no recorded user action is never counted as sent, while an in-app action can increment the field without proving a notification was delivered.

**Root cause:** Action events are being used to infer delivery. The schema has no delivered/presented reminder event.

**Proposed fix:** Choose and document the metric: either count eligible reminder opportunities when scheduling/delivering, or rename the denominator to actioned prompts and calculate adherence accordingly. Use deterministic event data and apply the same definition locally and in SQL.

**Regression risk:** Medium. Existing daily values and organization analytics may need a versioned interpretation; do not silently rewrite history.

**Test plan:** Cover delivered-with-no-action, skipped, snoozed, in-app actions, and completed prompts; assert local and server aggregates agree.

### P2 — F-06: Cadence queue and streak iteration assume 24-hour days

**Evidence:** The OS queue advances using elapsed durations (`lib/services/notification_service.dart:408-411`), while action windows are recomputed from local wall-clock boundaries in `lib/data/models/stand_window.dart:214-233`. `WorkdayMetrics.currentStreak` subtracts `Duration(days: 1)` (`lib/data/models/workday_metrics.dart:37-53`), which is 24 elapsed hours rather than the prior local calendar date.

**Root cause:** Reminder boundaries and streak dates mix elapsed-duration arithmetic with calendar-time rules. DST transitions can shift queued alerts relative to actionable windows and can skip a calendar date in streak traversal.

**Proposed fix:** Generate cadence candidates from local calendar boundaries and advance streaks with calendar constructors (`DateTime(year, month, day - 1)`). Reconcile pending OS alerts when the timezone changes.

**Regression risk:** Medium. DST gaps/folds and cadence intervals that do not divide evenly into 24 hours need explicit semantics.

**Test plan:** Deterministic tests across spring-forward/fall-back dates, midnight, 30/60/90-minute cadence, and timezone changes; assert alert time and `StandWindow` agree.

### P2 — F-07: Peak skip-hour analytics are advertised but always empty

**Evidence:** The README advertises peak skip-hour analysis (`README.md:117`). `SupabaseService.fetchOrganizationAnalytics` explicitly returns an empty `peak_skip_hours` list (`lib/data/remote/supabase_service.dart:310-313`); organization sync sends daily totals and no event timestamps (`:218-240`).

**Root cause:** The implementation deliberately keeps individual reminder timestamps local, but the README still describes an hourly cloud analysis that has no privacy-preserving input or query.

**Proposed fix:** Keep the privacy boundary and remove/qualify the claim, or design an opt-in, minimum-cohort hourly aggregate that never uploads identifiable reminder logs. Do not add raw employee timestamps to satisfy the current UI.

**Regression risk:** Low for correcting documentation; high for adding new analytics because small hourly cohorts can reveal individual behavior.

**Test plan:** If documentation-only, assert the README matches the empty-state UI. If implemented, SQL tests must check admin authorization, minimum cohort, and suppression across small cohorts.

### P2 — F-08: French onboarding includes untranslated profile labels

**Evidence:** `lib/ui/screens/onboarding/slide_widgets.dart:457,464,471` stores `Full Name`, `Designation / Role`, and `Work Email (Optional)` as English labels, then passes the variable through `appString` at `:524`. Those keys have no translation entries in `lib/core/app_strings.dart`. The parity test discovers only literals passed directly to `appString` (`test/bilingual_parity_test.dart:164-177`), so it misses this variable-based call.

**Root cause:** The English labels are not dictionary keys, and the source test does not follow variables into `appString`.

**Proposed fix:** Route labels through the French/English dictionary and extend the parity test to catch user-visible literals in common label/hint/title properties.

**Regression risk:** Low. Ensure the translated labels remain meaningful and accessible in form-field semantics.

**Test plan:** Render onboarding under `Locale('fr')` and `Locale('en')`; assert visible labels and semantics are translated, then run the parity suite.

### P2 — F-09: Native permission prompt precedes onboarding and Flutter UI startup

**Evidence:** `NotificationService.initialize` sets Darwin `requestAlertPermission`, `requestBadgePermission`, and `requestSoundPermission` to `true` (`lib/services/notification_service.dart:89-95`). `main()` initializes notifications, awaits `AppState.init()` and launch-action dispatch, then calls `runApp` (`lib/main.dart:37-58`).

**Root cause:** The operating system can display the iOS/macOS notification prompt before the Flutter onboarding screen explains the permission. Database initialization and 48-slot scheduling also delay first Flutter paint.

**Proposed fix:** Initialize the plugin without prompting, request permission from the onboarding/settings action, and show a Flutter loading/splash shell while asynchronous state and queue reconciliation complete.

**Regression risk:** Medium. Ensure denied permissions do not block local data startup and that later opt-in still schedules the queue.

**Test plan:** Test first launch with grant/deny, returning launch, and delayed database/notification initialization; verify onboarding is visible before permission prompt and local use continues after denial.

### P2 — F-10: Local schema does not enforce user/day uniqueness or index hot queries

**Evidence:** `UserPreferencesTable` and `AnalyticsDailyTable` use only `id` as their primary key (`lib/data/local/app_database.dart:25-56,73-88`); `userId` and analytics `date` have no unique constraint or indexes. `getUserPreferences` and `getAnalyticsForDate` use `limit(1)` without ordering (`lib/data/local/local_repository.dart:109-116,262-268`).

**Root cause:** Application-level IDs and query conventions carry uniqueness guarantees that SQLite does not enforce. Recent-skip, dedupe, and sync queries also have no declared indexes.

**Proposed fix:** Profile existing local data, deduplicate safely, then add unique keys/indexes through a versioned migration. Preserve all existing rows and define deterministic behavior for any duplicates before enforcing constraints.

**Regression risk:** High for migration on user devices with duplicate legacy rows; low for indexes after migration correctness is established.

**Test plan:** Migration tests from schema versions 1-4 with populated fixtures, duplicate-row handling, uniqueness checks, and query plans for reminder history and daily summaries.

### P3 — F-11: README links and source tree no longer agree

**Evidence:** `README.md:7` links to `CONTRIBUTING.md`, which is absent. Its architecture tree lists `lib/ui/widgets/reminder_fab.dart` (`README.md:287`), while that file is deleted in the current working tree and the shell uses `ReminderBellButton` (`lib/ui/screens/main_shell.dart:21,272,308`; `lib/ui/widgets/reminder_bell_button.dart:25-26`).

**Root cause:** Documentation did not keep up with the current uncommitted navigation redesign and repository files.

**Proposed fix:** Update the architecture tree and interaction description after the current UI change is settled, and either add the contribution guide or remove the dead badge link.

**Regression risk:** Low; documentation-only.

**Test plan:** Check every relative README link and listed source path; compare feature claims with the current UI and supported platforms.

### P2 — F-12: Reminder-window copy ignores the selected cadence and window length

**Evidence:** The UI allows cadence values 30, 60, and 90 minutes and action-window values 3, 5, 10, and 15 minutes (`lib/core/app_cadence.dart:87-105`). Rejection copy is fixed to “minute 55 of each hour” / “last 5 minutes of each hour” (`lib/providers/app_state.dart:619-621`), and the README repeats the five-minute-per-hour rule (`README.md:58`).

**Root cause:** User-facing explanations are constants rather than being derived from the active cadence and window preferences.

**Proposed fix:** Generate localized copy from the effective cadence and action-window settings, including the case where the selected cadence clamps the requested window.

**Regression risk:** Low. Keep French and English wording consistent with the exact boundary calculation.

**Test plan:** For each offered cadence/window combination, verify the displayed explanation matches `StandWindow` start/end boundaries in both locales.

### P2 — F-13: Requested local personalization/recommendations are absent

**Evidence:** The user-requested capability is to tailor suggestions to employee goals and feedback using Dart rules over local activity summaries and preferences. The current model surface contains preferences/goals (`lib/data/models/user_preferences.dart:21-44`) and activity summaries (`lib/data/models/daily_analytics.dart:1-11`), but source search found no recommendation service/model or recommendation UI in `lib/`; `pubspec.yaml` has no AI dependency, and `test/` has no recommendation-rule tests. Existing streak, adherence, and goal calculations are aggregate metrics, not recommendations.

**Root cause:** The product direction names personalized guidance, but its inputs, rule set, feedback capture, result model, and display surface have not been designed or implemented.

**Proposed fix:** After reminder and analytics data are trustworthy, define a small deterministic Dart rule engine that consumes local summaries, the employee's daily goal, cadence, and explicit feedback. Surface one explainable, dismissible suggestion in the existing Home/Timer experience. Keep personal inputs and event history local; no AI/network dependency is needed for this specified first version.

**Regression risk:** Medium. Recommendations based on the current action-count denominator or inconsistent event totals could be inaccurate or intrusive; implement after F-03/F-05, and make suggestions easy to dismiss.

**Test plan:** Unit-test each rule against known summaries, goal progress, skips, no-history, and feedback cases. Add tests that rules are deterministic, remain offline, do not alter analytics, and expose French/English accessible copy in the intended screen.

### P2 — F-14: “Snooze 10m” advances to the next cadence window

**Evidence:** The notification actions and reminder-bell sheet label the action `Snooze 10m` (`lib/services/notification_service.dart:104,237,258`; `lib/ui/widgets/reminder_bell_button.dart:155`). `AppState.snoozeReminder` stores the `minutes` argument but schedules the next cadence window (`lib/providers/app_state.dart:701-728`). The README also says it delays by ten minutes (`README.md:91`), while another README section says snooze advances to the next window.

**Root cause:** The anti-farming policy intentionally advances snooze to the next action window, but the action label and one feature description promise a ten-minute delay.

**Proposed fix:** Choose one contract and align notification labels, in-app labels, logs, and README. If the next-window policy is retained, label the action as “Next break” or equivalent in French and English; if 10 minutes is required, define how a break can be completed outside the normal window without creating extra credit.

**Regression risk:** Medium. Changing the action semantics affects notification controls and analytics; retaining the current rule requires only copy alignment.

**Test plan:** With a fixed clock, verify the displayed label, logged delay, next notification time, and action-window eligibility agree for 30/60/90-minute cadence in both locales.

### P2 — F-15: Overlapping reminder-queue rebuilds are not serialized

**Evidence:** `scheduleReminderSeries` cancels IDs 101–148 and then schedules the series sequentially (`lib/services/notification_service.dart:387-438`). It has no in-flight guard. Resume refresh (`lib/providers/app_state.dart:387-393`), action scheduling (`:686-770`), language changes (`:945`), and preference changes (`:903-918`) can all enter queue rebuilding. A single preference update may rebuild more than once; overlapping resume/tap/settings calls can interleave cancellation and scheduling for the same IDs.

**Root cause:** Each caller treats queue replacement as exclusive, but the service has no lock or generation check. Stable IDs prevent ordinary sequential rebuilds from adding duplicate IDs, but interleaving can leave a queue that reflects only part of the latest schedule.

**Proposed fix:** Serialize/debounce queue replacement and make the latest requested schedule win. Keep fixed IDs so replays replace prior requests.

**Regression risk:** Medium. A lock that blocks too long could delay actions; a generation-based approach must still cancel stale OS alerts.

**Test plan:** Use a controllable fake notification plugin to interleave two cadence updates, resume refresh, and a reminder action; assert the final pending IDs and times exactly match the latest preferences with no stale or duplicate alerts.

### P2 — F-16: A stalled cloud request can leave sync in “syncing” indefinitely

**Evidence:** `AppState.triggerCloudSync` sets `SyncStatus.syncing` and awaits `syncLocalToCloud` (`lib/providers/app_state.dart:1176-1198`). The RPC and delete requests in `SupabaseService.syncLocalToCloud` have no request timeout or retry/backoff (`lib/data/remote/supabase_service.dart:191-250`). Error handling runs only if the request completes or throws.

**Root cause:** Network operations have no bounded completion time, so a stalled socket can leave the settings/analytics UI showing a permanent spinner and any awaiting sync caller pending indefinitely.

**Proposed fix:** Apply a bounded timeout to cloud operations, preserve local state on failure, and use a limited retry/backoff policy only for safe idempotent operations. Stop the current per-row loop after a transient service-wide failure.

**Regression risk:** Medium. A timeout that is too short can label a slow but successful request as failed; retries must not double-count analytics.

**Test plan:** Use a fake client that hangs, times out, returns 429/503, and later succeeds; assert the UI leaves `syncing`, local data remains available, and retry does not duplicate remote totals.

### P2 — F-17: Analytics can report “Cloud Connected” for a local-only state

**Evidence:** `AppState` starts with `SyncStatus.idle` (`lib/providers/app_state.dart:75`). The sync service also returns `idle` when statistics opt-in is off (`lib/data/remote/supabase_service.dart:206-209`). Analytics renders that status as “Cloud Connected” (`lib/ui/screens/analytics_screen.dart:395-399`), while Settings renders the same state as “Local-only until Supabase Auth is configured” (`lib/ui/screens/settings_screen.dart:1282-1290`).

**Root cause:** `idle` represents both “not syncing” and “connected,” and the two screens interpret it differently.

**Proposed fix:** Add a distinct local-only/not-contributing state or derive connection and opt-in labels from separate fields; use one status mapping across screens.

**Regression risk:** Low to medium. Keep signed-out, opted-out, syncing, success, offline, and error states distinct so a green cloud cannot imply an upload occurred.

**Test plan:** Test each sync status in Analytics and Settings under no credentials, signed out, opted out, successful sync, and failure; assert the displayed meaning is consistent.

### UI grouping review — requested consolidation is already present

The requested grouping of reminders, rankings, and statistics maps to the existing Timer, Leaderboard, and Analytics destinations. Profile/team and notification/reminder preferences already live together on the Settings route. The separate reminder bell is a quick-action shortcut, not an additional page; the expanded layout uses an account button to enter Settings instead of showing the compact-layout gear. The supplied code therefore already has the requested top-level grouping. The README still describes a floating FAB and deleted `reminder_fab.dart` (F-11). Before removing additional controls as “redundant” or “useless,” compare the action sheet and Timer actions on each layout; current source review does not establish another duplicate screen that should be deleted.

## Security, privacy, and platform notes

- The client reads only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in `lib/data/remote/supabase_service.dart:11-15`. A repository scan found no service-role/JWT credential-pattern match. This is a source scan, not a secret-scanning service guarantee.
- Profiles, reminder logs, and daily analytics have RLS enabled in `supabase_schema.sql:94-97`; policies scope private rows by `auth.uid()` (`:108-156`). Admin views use `private.is_org_admin` and `HAVING COUNT(DISTINCT user_id) >= 5` (`:252-289`). The validator function uses an empty search path and derives user/org IDs server-side (`supabase_validation.sql:56-83,130-133`).
- The admin UI does not receive individual timestamps in the reviewed sync path. Peak-hour analytics are therefore unsupported, as F-07 records.
- Android reboots are covered by notification receiver declarations in `android/app/src/main/AndroidManifest.xml:3,18-21`. iOS/Android exact delivery remains OS-dependent. Linux foreground-only and browser open-tab limits are documented in `docs/INSTALL_AND_LAUNCH.md` and `README.md:185`.
- No live Supabase RLS, invitation, OAuth, Realtime, or multi-device integration test ran. No real-device notification delivery test ran. The builds prove compilation for Android and web only.

## Prioritized implementation roadmap

Each item is sized as a separately reviewable change. Keep Phase 1 audit-only; do not combine these into a broad rewrite.

1. **Restore baseline CI (F-01):** fix the cadence test fixture and formatting; rerun analysis, all tests, and the CI formatting command.
2. **Make action persistence atomic (F-03):** add repository transaction and idempotency tests before changing the three action call sites.
3. **Add work schedules (F-02):** define preference shape/defaults and pure calculations; test weekday, weekend, quiet-hours, cadence, and DST behavior before wiring notifications.
4. **Make cloud sync conflict-safe (F-04):** agree on device/event identity, then implement idempotent server reconciliation and two-device/replay tests.
5. **Align snooze copy/behavior (F-14):** decide between a real 10-minute delay and next-window semantics, then align all action labels and tests.
6. **Serialize queue reconciliation (F-15):** make the latest desired queue win across resume/actions/settings; test interleavings with a fake plugin.
7. **Define the reminder denominator (F-05):** document the metric and add failing unit tests for delivered, ignored, skipped, snoozed, and in-app cases; then update local and SQL calculation consistently.
8. **Fix calendar arithmetic (F-06):** add DST and timezone tests, then update queue generation and streak traversal.
9. **Make cloud state bounded and truthful (F-16, F-17):** test hung/network-failure paths and make Settings/Analytics use one explicit local-only/syncing/success/error model.
10. **Align privacy claims and analytics (F-07):** remove the unsupported claim or design a reviewed cohort-safe aggregate before exposing hourly views.
11. **Fix onboarding/bootstrap flow (F-08, F-09):** translate and test onboarding labels, then defer OS permission prompts and provide a visible startup state.
12. **Harden Drift uniqueness/performance (F-10):** inspect actual local rows, add migration fixtures, deduplicate with a documented policy, then add constraints and indexes.
13. **Refresh rule copy (F-12):** derive the action-window explanation from the selected settings and add locale/cadence coverage.
14. **Add local personalized guidance (F-13):** once the underlying metrics are trustworthy, define feedback inputs and deterministic recommendation rules; test offline behavior, explanations, and both locales.
15. **Refresh docs (F-11):** repair README links and source tree after the UI is stable; verify every platform claim against a real build or documented toolchain limit.


## Implementation follow-up — 2026-10-13

The findings above record the audit baseline. This follow-up records changes made after implementation was authorized:

- **Resolved:** F-01 cadence fixture and formatting failure. Tests now provide required IDs; zero-valued counter defaults remain intentional literals.
- **Resolved:** F-03 reminder event and daily aggregate writes now share a Drift transaction. Completion claims the action window inside that transaction, so concurrent attempts persist at most one completion. Regression coverage exercises concurrent claims.
- **Resolved:** F-06 streak traversal now steps between local calendar dates rather than subtracting a fixed 24-hour duration.
- **Resolved:** F-07 the unsupported peak skip-hour panel and README claim were removed; individual event times remain private.
- **Resolved:** F-08 French onboarding now translates the profile field labels.
- **Resolved:** F-09 Darwin notification initialization no longer prompts before onboarding; the existing onboarding/settings action requests permission.
- **Resolved:** F-12 rejection copy uses configured action-window and cadence values; the README describes the selected window rather than fixed five-minute defaults.
- **Resolved:** F-14 snooze labels and onboarding copy now say “Next reminder”. Snoozing remains aligned to the next valid action window, and the recorded duration reflects that window.
- **Improved:** F-15 reminder queue rebuilds are serialized; a failed rebuild no longer blocks a later repair.
- **UI:** Removed the Flutter Dynamic Island pill. The home header now shows profile access and a next-window/closing countdown. Reminder quick actions are a round control separate from compact navigation and available in the expanded header. README placement and source-tree descriptions were updated.
- **AI preparation:** Added a provider interface and identity-free, coarse-count input allowlist. No model provider or network call is enabled; requirements and privacy constraints are in `AI_INTEGRATION.md`.
- **Metric meaning:** User-facing analytics now call the ratio a completion rate. It is completed actions divided by recorded actions; it does not include reminders that had no recorded response. Legacy local and SQL column names remain unchanged for compatibility.
- **Documentation:** Removed the unsupported individual skip-hour analytics promise and corrected the source tree for the reminder control.

**Verification after implementation:** `dart format --output=none --set-exit-if-changed lib test tool` passed; `flutter analyze --fatal-infos --fatal-warnings` passed; `flutter test` passed (230 tests); `flutter build apk --debug` and `flutter build web --release` passed. Windows desktop cannot be built on this machine because the Visual Studio C++ workload is absent. iOS/macOS builds require macOS, and Linux desktop builds require Linux. Android device delivery, live Supabase/RLS behavior, and real-device notification delivery were not exercised.

**Still open at that implementation checkpoint:** F-02 workday scheduling, F-04 multi-device cloud conflict reconciliation, F-05 the user-facing meaning of the adherence denominator, F-10 schema uniqueness/indexes, F-13 actual personalized guidance, and F-16/F-17 cloud timeout/status consistency. Later follow-ups below address F-05 presentation and F-16/F-17.

### Follow-up — bounded and truthful cloud sync

The 2026-10-13 sync follow-up resolves F-16/F-17 for PostgREST database operations:

- Supabase PostgREST requests now have a 20-second per-attempt timeout. The SDK aborts a timed-out request; pending local analytics remain unmarked and can be retried later.
- A timed-out analytics RPC stops the current row loop instead of waiting through a timeout for every remaining day.
- Concurrent app-level sync triggers share the in-flight operation.
- Analytics and Settings now describe `idle` as sharing off, `offline` as local-only, and only `success` as synced.

The timeout does not cover OAuth/auth-provider calls or realtime WebSocket lifetime. No live Supabase endpoint was configured in this workspace, so network behavior still needs an integration check against a test project.

**Still open after this follow-up:** F-02 workday scheduling, F-04 multi-device cloud conflict reconciliation, F-10 schema uniqueness/indexes, and F-13 the user-facing local personalization rules. The optional schedule defaults are not changed without a confirmed product preference.

### Follow-up — local work schedule

The user confirmed the default schedule: Monday–Friday, 09:00–17:00. Settings allow editing active weekdays and same-day start/end times. A shared `WorkSchedule` rule filters the in-app countdown and the 48-alert OS queue; new break actions are rejected outside work hours. Schedule settings are stored in Drift's user-preferences table and are not synced. Queue cadence boundaries re-anchor to each local calendar day. Tests cover workday boundaries, Friday-to-Monday queue generation, quiet hours, JSON round trips, cadence boundaries, and a data-preserving v4-to-v6 migration with lookup indexes.

**Verification after this follow-up:** `dart format --output=none --set-exit-if-changed lib test tool` is clean (83 files, 0 changed); `flutter analyze --fatal-infos --fatal-warnings` reports no issues; `flutter test` passes (250 tests); `flutter pub get` succeeds; `flutter build apk --debug` and `flutter build web --release` both succeed after the v6 index/cadence changes. Flutter doctor reports Windows desktop unavailable because Visual Studio's C++ workload is absent; iOS/macOS require macOS and Linux desktop requires Linux. Android SDK licenses and multiple `adb` binaries are warnings. DST transition simulation, real-device notification delivery, and live Supabase/RLS behavior remain unverified.

F-02 is implemented; real timezone transition simulation remains open. Non-unique lookup indexes are in v6; F-10's unique constraint on preference ownership remains open because existing duplicate rows must be handled without deleting user data. F-04 multi-device cloud conflict reconciliation and long-term persistence of employee feedback remain open.

The F-05 presentation was also clarified: dashboards describe the existing ratio as completion rate among recorded actions, rather than delivered-reminder adherence. This avoids claiming to measure unobserved notifications without rewriting historical aggregates or database columns.

### Follow-up — company-hosted guidance AI scaffold

The user chose a company-hosted endpoint and asked for a Supabase proxy rather than a large local model. Settings now has an AI consent separate from statistics sharing; it defaults off, is stored only in Drift (schema v7), and the Home action makes a request only after a manual tap and only for a signed-in Supabase user. The client sends the coarse `GuidanceInput` allowlist. The authenticated `ai-guidance` Edge Function validates request shape/ranges and the fixed consent contract, calls an HTTPS OpenAI-compatible endpoint using server-only secrets, and returns only validated typed guidance. The Home UI uses localized app copy and keeps deterministic local guidance as fallback.

**Verification after this follow-up:** `dart format --output=none --set-exit-if-changed lib test tool` is clean (84 files, 0 changed); `flutter analyze --fatal-infos --fatal-warnings` reports no issues; `flutter test` passes (252 tests); `flutter build apk --debug` and `flutter build web --release` both succeed. No company model endpoint, API key, or Supabase project is configured in this checkout. The proxy fails closed until its three documented server secrets are configured and the function is deployed; a live upstream inference call and Edge Function runtime test could not be run because Deno and the Supabase CLI are unavailable on this host. The function contract tests are included for Deno but remain unexecuted here. Windows desktop is unavailable without Visual Studio's C++ workload; iOS/macOS require macOS and Linux desktop requires Linux.

### Follow-up — Workrave-parity batch (prelude, presence, cover, quiet mode, autostart, daily cut-off, guided routine on the cover)

Thirteen commits on top of `20e8b92`, each one independently reviewable; the
per-defect detail is in `docs/DEFECT_BACKLOG.md` and the feature-by-feature
comparison with Workrave is in `docs/WORKRAVE_ANALYSIS.md`.

- **Prelude, presence, cover.** An advisory heads-up before each window (in-app
  banner plus an OS notification on desktop); Windows `GetLastInputInfo` and
  Linux X11 `MIT-SCREEN-SAVER` idle readings that withhold the chime, the nudge
  and the cover while nobody is at the desk; an opt-in cover that also keeps the
  window above other applications for its duration.
- **Quiet mode** pauses every interruption at once and is deliberately
  session-only, because a persisted quiet mode is a silent failure the user
  cannot see.
- **Startup registration** writes the session entry Windows and Linux read
  (`Run` value, autostart `.desktop`), read back from the OS rather than
  remembered from the last tap.
- **Company aggregates.** The admin dashboard is a multi-day trend with the
  arithmetic in a pure `OrgTrendSummary`, gated by role rather than by having an
  organisation, and two SQL landmines are gone: `synced_to_cloud` was referenced
  by the RPC but created by no script, and `total_stand_minutes` (a view alias)
  was used as the base column `total_stand_time`. Both failed only on the first
  sync of a fresh project, which is why a static contract test now pins the class
  of defect.
- **Guidance.** The feedback choice is persisted (`user_preferences.guidance_feedback`,
  v10) instead of living in memory, and the answer space gained the two things it
  could not phrase (an explicit "too frequent", a day with nothing recorded yet) —
  in both the Dart rule and the TypeScript contract, with a test asserting every
  pair a model may return is one the local rule can also phrase.
- **Daily cut-off.** An optional limit stops offering breaks *N* hours after the
  work day starts; it is schedule arithmetic rather than Workrave's usage
  accounting, for the reasons written up in `WORKRAVE_ANALYSIS.md`, and Settings
  prints the resolved clock time so the difference is visible.
- **Guided routine on the cover.** The routine is no longer a private sheet in
  `home_screen.dart`, so the forced-break cover can offer it; the overlay's
  surface is chosen by the pure `breakBlockView`.

**Verification of this batch:** `dart format --output=none --set-exit-if-changed lib test tool` is clean; `flutter analyze --fatal-infos --fatal-warnings` reports no issues; `flutter test` passes (354 tests, including the new `test/daily_limit_test.dart`, the migration round-trip for schema v10 and v11, the queue's per-day cut-off cases and the overlay's view rule); the Drift schema moved to v11 with `dart run build_runner build` re-run and the regenerated `app_database.g.dart` committed; `flutter build apk --debug` and `flutter build web --release` both succeed on this host, so the Dart side compiles for two real targets beyond the test VM.

**Unverified, and not claimed:** the Windows and Linux desktop builds have never been compiled anywhere, because this host has no Visual Studio C++ workload and no Linux toolchain — the native presence and keep-above code is reviewed, not run, and the two rows in `PLATFORM_SETUP.md` still say so. The `ai-guidance` Deno contract tests are modified but unexecuted (no Deno). No live Supabase project is configured, so RLS and the RPC changes have not been exercised against a server. Notification delivery on a real device and DST transition behaviour remain unverified. The launcher widget's countdown ignores the daily cut-off because the payload carries no cut-off field and its native rendering cannot be built here. **All thirteen commits are local; CI has not run**. Until they are pushed, the desktop targets, the Deno tests and the packaging are unaudited.
