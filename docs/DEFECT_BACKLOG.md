# Defect backlog

Findings from a systematic review of the timer, state, storage and i18n
subsystems. The Critical and High items were fixed — see the commits for
`stand_window.dart`, `supabase_validation.sql`, `app_state.dart` and
`local_repository.dart`. Everything below is **not fixed** and is recorded here
so it is not rediscovered from scratch.

Each entry cites the evidence that established it. Nothing here was reproduced
on a device unless the entry says so; several are read-from-code conclusions.

## Medium

### Widget payload `_decode` turns booleans into ints, so `WidgetBridge.read()` returns null
`lib/data/local/widget_snapshot.dart:352` — `_decode` does `int.tryParse('1')`
first, which succeeds, so the `?? (value == '1' …)` fallback is dead and
booleans arrive as `int`. `fromMap` then throws on the cast to `bool?`. So
`read()` yields null whenever `window_open`, `clock_suspect` or `goal_met` is
true. *Verified by execution.* Latent today, because the native Kotlin and
Swift parsers keep strings and are unaffected — but `read()` is public API.
The existing test passes only because it round-trips `toMap()` and never
touches `_encode`/`_decode`. Fix: check the `1`/`0` form first, and make the
test exercise the encode/decode pair.

### `clock_suspect` is computed every second but published only on rare events
`app_state.dart:336` recomputes it at 1 Hz; `syncWidget` is not called from
`_tick`. Consumers gate on it (`StandUpWidgetProvider.kt`, `WidgetPayload.swift`)
to hide the launcher action button. Once the flag trips and clears, the button
stays hidden until one of the few `syncWidget()` call sites fires. Fix:
publish on the transition, not on a timer.

### Dismissing the guided-stretch sheet still auto-logs the break
`home_screen.dart` — `showModalBottomSheet` defaults to `isDismissible: true`
and `_GuidedStretchSheetState` has no `dispose`, so `initState`'s
`startGuidedStretch()` keeps running and logs a stretch the user abandoned.
Fix: cancel on dispose, or make the sheet non-dismissible.

### `remindersSent` counts user actions, and `totalStandTime` is hard-coded to 5
`local_repository.dart:280` increments on every action, so "reminders sent"
equals completed + snoozed + skipped, which makes `adherenceRate` equal
`completed / totalActions`. `:298` hard-codes 5 minutes, ignoring
`actionWindowMinutes`, so a user with a 15-minute window accrues a third of the
stand time they actually took — and that figure is what is uploaded as
`p_total_stand_minutes`. Fix: increment where a reminder is emitted, derive
stand time from the window length.

### No HTTP timeout or retry/backoff on any Supabase call
`supabase_service.dart` — a hung socket leaves `_syncStatus = syncing` forever
with no watchdog, and because `updatePreferences` awaits the sync, the
statistics toggle handler never returns. The per-row loop continues straight
through a 429/503. Fix: `.timeout(...)`, bounded backoff on reads, abort the
row loop on the first 429/5xx.

### `SyncStatus.idle` is rendered as "Cloud Connected"
`app_state.dart:65` initialises `idle`; `supabase_service.dart:208` returns
`idle` when the user is not opted in; `analytics_screen.dart:391` maps it to
"Cloud Connected" while `settings_screen.dart:1263` maps the same value to
"Local-only". A local-only user sees a green cloud. Fix: add a distinct
`localOnly` member.

### Reminder-queue rebuild is ~96 sequential platform-channel calls, up to three times per preference change
`notification_service.dart:396` cancels then schedules 48 reminders, each a
round-trip. `updatePreferences` can invoke it three times in one call, and
`init()` runs it before `runApp`. Fix: `Future.wait`, debounce behind a
single in-flight future, move `init()`'s build after `runApp`.

### Changing the daily goal never reaches the widget
`app_state.dart:864` syncs the widget only when `colorSystem != null`, yet
`syncWidget` publishes `dailyGoal`. Fix: also sync when `streakGoal` changes.

### No indexes on any Drift table, and `user_preferences.user_id` is not unique
`app_database.dart` has no `@TableIndex` or `uniqueKeys`. Hot paths are full
scans: `hasCompletedReminderInWindow` runs on every completion,
`getUnsyncedReminderLogs`, `getUnsyncedAnalytics`, `getAllDailyAnalytics`.
`UserPreferencesTable`'s primary key is `id`, so `reassignLocalUser`'s `UPDATE`
can create duplicates, and `getUserPreferences` takes `limit(1)` with no
`orderBy`. Fix: indexes plus `uniqueKeys => [{#userId}]` (needs a migration).

### `HomeWidget.widgetClicked` subscription is never released
`widget_snapshot.dart:279` subscribes and discards the `StreamSubscription`,
and the handler is invoked unawaited without a `catch`, so a throw surfaces as
an unhandled stream error. Fix: store and cancel it; wrap the call.

## Low

- `dailyGoalBonusXp = 25` is declared and promised by `totalXp`'s doc but never
  awarded (`gamification_metrics.dart`).
- `StandWindow.windowsBetween` is documented as the way to detect missed breaks
  without trusting a client counter, but has no caller in `lib/`.
- `WidgetBridge.requestAndroidRefresh()` publishes an empty map, which would
  blank the launcher widget. Currently unused.
- `Colors.black54` on `GlassCard` is roughly 1.4:1 in the dark theme
  (`analytics_screen.dart`, `org_admin_screen.dart`). `contrast_test.dart` only
  checks `AppColors` constants.
- The desktop "Forward" button is wired to `navigator.canPop()` /
  `maybePop()`, so it navigates backwards (`main_shell.dart`).
- `_orgAnalytics` loads once in `init()` and never refreshes, so joining a
  workspace later leaves the leaderboard on the offline fallback until relaunch.
- `_persistReminderInterval` is a deliberate no-op, but the comment above it
  says "Restore the absolute due time".
- `snoozeReminder` / `skipReminder` clear `_breakTimer` but leave
  `_breakWindowKey` set. Unreachable today because `_isBreakActive` is cleared,
  but a latent trap.
- DST: `scheduleReminderSeries` adds `Duration(minutes: cadence * i)` across 48
  slots, drifting an hour across a transition, while the in-app window math is
  re-derived from the wall clock each tick — so the OS queue and the action
  gate disagree twice a year.
- DST: `currentStreak`'s `cursor.subtract(Duration(days: 1))` can skip a
  calendar day across a midnight transition.
- `_consecutiveSkips` restored at launch is hard-capped at 3, so the comment
  justifying `>= 3` over `== 3` ("can already sit above three") describes an
  unreachable state.
- `refreshReminderQueue` falls back to the unclamped `notificationFrequency`
  while everything else uses `_cadenceMinutes`.
- The widget's `updatePeriodMillis="900000"` is clamped by Android to a
  30-minute floor, so the launcher countdown redraws every ~30 minutes, not
  15. The provider doc's "recomputed on every draw" is true per draw, but
  draws are rare.
- `AudioService._init()` discards the `setReleaseMode` future;
  `handleNotificationAction`'s `notificationId` is unused; the headless isolate
  never initialises `HapticsService.enabled`, so haptics fire even when
  disabled.
- `README.md:76` advertises retired accents ("Emerald, Teal, Amber, Indigo,
  Coral") while the shipped palette is brand/ink/blue/teal/violet/amber.
- `README.md:7` links to a `CONTRIBUTING.md` that does not exist.

## Hard-coded English that never enters the dictionary

`app_strings.dart`'s "unknown copy stays visible as-is" policy does hold — the
problem is that these strings never reach `appString` at all, which no existing
gate detects. The parity test only matches `appString(<ctx>, '<literal>')`, so a
string passed through a variable is invisible to it.

- `settings_screen.dart` — many
- `slide_widgets.dart:444, 446, 451, 453, 458, 460` — these three are passed to
  `appString` as a *variable* at `:505`, so they fall through to English
- `contribution_heatmap_widget.dart`, `analytics_charts.dart`,
  `analytics_screen.dart:112, 114`

**On-device confirmation:** the onboarding profile slide renders "Full Name",
"Designation / Role" and "Work Email (Optional)" in English inside an otherwise
French screen.