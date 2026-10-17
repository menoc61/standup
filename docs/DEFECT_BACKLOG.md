# Defect backlog

Findings from a systematic review of the timer, state, storage and i18n
subsystems. The Critical and High items were fixed — see the commits for
`stand_window.dart`, `supabase_validation.sql`, `app_state.dart` and
`local_repository.dart`. The entries below capture the original audit snapshot;
subsequent resolutions are recorded in the implementation follow-up at the end
of this document.

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
and `_GuidedStretchSheetState` (now `_GuidedStretchPanelState`, in
`ui/widgets/guided_stretch.dart`) has no `dispose`, so `initState`'s
`startGuidedStretch()` keeps running and logs a stretch the user abandoned.
Fix: cancel on dispose, or make the sheet non-dismissible.
*Resolved:* the state cancels the routine in `dispose`, so dismissing still
counts as abandoning it; the sheet stays dismissible.

### `remindersSent` counts recorded user actions, not delivered reminders
`local_repository.dart:280` increments on every action, so "reminders sent"
equals completed + snoozed + skipped. The legacy `adherenceRate` getter thus
means completed / recorded actions, not completed / delivered notifications.
Stand time now uses the configured action-window length when a completion is
recorded. The delivered-reminder denominator remains unresolved because no
delivery/presentation event is stored.

### Original finding: no HTTP timeout or retry/backoff on Supabase calls
`supabase_service.dart` now applies a 20-second PostgREST per-request timeout,
and a timeout stops the current analytics row loop. Auth-provider and realtime
operations do not use that PostgREST timeout. The sync loop does not yet retry
429/503 responses with backoff; unsent aggregates remain local for a later
attempt.

### Original finding: `SyncStatus.idle` was rendered as "Cloud Connected"
Analytics and Settings now consistently label `idle` as sharing off and
`offline` as local-only. Only `success` is described as synced.

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

## Implementation follow-up — 2026-10-13

- Reminder-event insertion and daily aggregate updates now use one Drift transaction; completion is claimed once per action window.
- Stand-time credit now uses the configured action-window length.
- The analytics ratio is labeled completion rate among recorded actions. It still does not count unanswered/delivered reminders.
- PostgREST requests have a 20-second per-attempt timeout; timeout stops the current row loop and pending rows remain local.
- Concurrent cloud-sync calls are shared, and account switches queue the new account's sync after the active operation.
- Sync labels distinguish local-only, sharing off, and synced states.
- Widget payload decoding now uses field types, preserving boolean flags even when integer fields contain `0` or `1`; serialization regression tests exercise the actual codec.
- Dismissing the guided-stretch sheet cancels its timer; completing the routine uses its original action-window key, and the sheet closes when the routine ends.
- Widget payloads refresh when clock trust changes and when the daily goal changes; fallback queue refreshes use the clamped cadence.
- Snooze/skip clear guided-stretch state, and skipped reminders reschedule using the same clamped cadence as the action-window rules.

Workday schedules now default to Monday–Friday, 09:00–17:00 and can be edited locally. The shared schedule rule filters in-app windows and the OS queue, and gates completion actions. Preferences are stored in Drift with a data-preserving v4-to-v6 migration; the OS queue re-anchors cadence boundaries against the local calendar day and Drift lookups have non-unique indexes. Boundary, queue, quiet-hours, and migration tests pass. DST transition simulation and device-delivery checks remain open. Multi-device reconciliation and uniqueness for `user_preferences.user_id` remain open because legacy duplicates must be preserved. Local deterministic guidance is implemented; long-term persistence of employee feedback is deferred.

Company AI guidance now uses a separate default-off local consent and a manual Home action. An authenticated Supabase Edge Function proxies the typed daily summary to a configurable company OpenAI-compatible endpoint. Local deterministic rules remain the fallback; model credentials stay in Edge Function secrets. The proxy is only a scaffold until a company endpoint and Supabase project are configured and deployed. Long-term feedback persistence, live Edge Function/upstream tests, DST simulation, device delivery, multi-device reconciliation, and the preference ownership uniqueness decision remain open.

## Implementation follow-up — 2026-10-16

- **Two column references in `supabase_validation.sql` named columns no schema ever created**, so `record_daily_analytics` installed cleanly and failed on the first sync of a fresh project: `synced_to_cloud` (in the `INSERT` list and the `DO UPDATE` set) existed only in that statement, and `total_stand_minutes` (in the `INSERT`, the `DO UPDATE` and the untrusted-view aggregate) is the *view alias* of the base column `total_stand_time`. The first is gone — a row written through the RPC is synced by construction — and the second now names the real column while keeping the view's output alias, which the Dart client reads. `test/supabase_sql_contract_test.dart` pins the class of defect: every inserted and upserted column must be declared by one of the two scripts, and the `VALUES` arity must match the column list.
- **Peak skip-hour analysis is no longer advertised.** `README.md` promised it while the client has always sent no event hour. Drawing it would require uploading the hour of each individual action, so the claim is removed rather than the boundary weakened.
- **The admin dashboard shows direction, not a single day.** `fetchOrganizationAnalytics` took `limit(1)`; `SupabaseService.fetchOrganizationTrend` returns the recent window (newest first, department rows for the newest day only) and `OrgTrendSummary.of` derives the comparison the strip renders. The trend is unwrapped client-side by tests, not eyeballed.
- **A workspace member who is not an admin no longer gets an "Open" button** to a screen whose query the RLS policy refuses; Settings says aggregate trends are admin-only, and the dashboard's refresh action pushes the local day before re-reading the aggregates.
- **Guidance feedback survives the process it was given in.** It lived in `AppState` memory, so the one complaint the app can act on — "these suggestions come too often" — stopped steering anything at the next launch. It is now a `user_preferences.guidance_feedback` text column (schema v9 → v10), read back through `GuidanceFeedback.parse` with an unrecognised value treated as `none` so a downgraded build can still open its database; the migration test asserts the column defaults to `none` for existing users rather than inventing an opinion for them.
- **The guidance answer space could not phrase two things it needed to**, so the app was silent in both cases: an explicit "too frequent" (the old local rule returned `null`, the one answer that cannot help a user who says the app talks too much) and a day with nothing recorded yet (silent on precisely the mornings a first nudge is worth most). `GuidanceReason.feedbackTooFrequent` and `GuidanceReason.noActivityYet` are accepted in the Dart and TypeScript contracts, rendered with bilingual copy, and produced by the local rule — with a test asserting every pair a model may return is one the local rule can also phrase, so the model's ceiling stays judgement rather than privileged vocabulary.
- **Open: the `ai-guidance` Edge Function has no per-user request quota.** Recorded in `docs/AI_INTEGRATION.md` instead of guessed at, because the fix needs a quota table (nothing in the SQL resembles the `audit_ai_requests` this repository was said to have) plus a live Supabase project to verify against. Until then the only spend control is the upstream gateway's own quota.
- **A daily cut-off ends the reminders instead of counting the work.** `WorkSchedule.dailyLimitInstant` (schema v11, `user_preferences.daily_limit_minutes`, default 0 = off) stops windows *N* hours after the work day starts, and `AppState._windowAllowed` is now the single gate the three schedule checks share so a limit cannot reach the timer and miss the OS queue. Three edges are asserted rather than assumed: a limit as long as the work day reports **no** cut-off rather than drawing a line no window can cross; the comparison uses the window's start so a window that opened before the cut-off is not revoked mid-break; and the queue applies it per candidate against that candidate's own date, because a limit tested once against `now` would stop applying after midnight. It is enforced at completion as well, since a user who does not enforce the action window can log breaks at any hour — otherwise the cut-off would have ended their reminders while leaving the counter open. **Deliberate divergence from Workrave:** it limits accumulated work time and forces a rest; this limits the *scheduled* day, because the alternative is continuously tracking desk occupancy and firing an interruption no setting predicts. Settings prints the resolved clock time so the difference is visible. **Known gap:** the launcher widget's own countdown is derived natively from the cadence in the payload (`WidgetSnapshot`), so past the cut-off it still counts to the next hourly boundary; the payload carries no cut-off field, and the native rendering cannot be verified in this repository without a platform build.
- **The guided stretch was reachable only from the dashboard — the one screen where it is most obviously right could not offer it.** It existed as the private `_GuidedStretchSheet` in `home_screen.dart`, and the forced-break cover cannot push a route: it is mounted from `MaterialApp.builder`, *above* the navigator, so a sheet opened from it would render underneath the very cover that asked for it. The routine is now `GuidedStretchPanel` (`ui/widgets/guided_stretch.dart`) — chrome-free, embedded by the cover and wrapped as a sheet by the dashboard — and the overlay's surface is chosen by `breakBlockView` (`core/break_block.dart`). That function exists because two rules meet here: the cover's own rule steps aside while a break is in progress, so a routine started from the cover would unmount the overlay hosting it on the same tap; `coverRequestedStretch` keeps that apart from a routine started at the dashboard, which must not summon the cover over its own sheet.
- **`AppCadence.guidedStretchStepCount` said four while the app ran five.** The routine shows five exercises and `AppState`'s ticker counted five steps of sixty seconds as `4 - (remaining ~/ 60)`, with both numbers inlined, so the constant a later change would have trusted was simply wrong — and `test/cadence_test.dart` asserted the fiction that it multiplied out. The count is five, the arithmetic is `AppCadence.guidedStretchStepFor`, and a test walks all 301 seconds of the routine to prove every index is one the routine can render. Observable behaviour is unchanged; what changed is that the constant now describes it.

