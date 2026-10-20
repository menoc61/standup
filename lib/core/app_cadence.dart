/// Every number that decides *when* the app interrupts you, in one place.
///
/// ## Why this exists
///
/// These values used to be written out wherever they were needed. An audit
/// found the default action window of five minutes declared twelve times — as a
/// model constant, as a constructor default, as a `fromJson` fallback, as a
/// `defaultPreferences()` literal, as a Drift column default, as a hand-written
/// `ALTER TABLE` default in a migration, as a widget payload default, and, worst,
/// as a bare `cadence < 5 ? cadence : 5` buried inside a clamping algorithm where
/// nothing would ever connect it back to the setting it represents.
///
/// ## The rule for changing one
///
/// Change it here, and nowhere else. The Drift column default and the SQL in the
/// migration cannot reference a Dart constant, so `test/cadence_test.dart`
/// asserts they agree — a migration that disagrees would silently write a
/// different default than every other layer believes in.
///
/// ## What is deliberately not here
///
/// Quiet hours, and the window arithmetic itself. Those are value objects with
/// real behaviour and belong to `StandWindow`; a constant file is the wrong home
/// for logic.
library;

/// Cadence, window length, goals, and the option sets the UI offers.
abstract final class AppCadence {
  // ── Defaults ───────────────────────────────────────────────────────────────

  /// Minutes between reminders. One hour.
  static const int defaultCadenceMinutes = 60;

  /// How long before the end of a window the user may still act on it.
  ///
  /// The window is *anchored to the end* of the cadence period, so "the last
  /// five minutes of the hour" is `11:55`–`12:00`, not `12:00`–`12:05`. The
  /// countdown therefore reads as "you can still do it" rather than "you are
  /// already late", which is the behaviour the home screen copy promises.
  static const int defaultActionWindowMinutes = 5;

  /// How many breaks a day counts as a good day.
  static const int defaultDailyGoal = 8;

  /// Minutes credited to the day for each completed break.
  ///
  /// This was a bare `completed * 5` in the repository. It is the *default*, not
  /// the user's choice: once `actionWindowMinutes` became configurable, the day
  /// total has to use the configured window, or a user who shortens the window
  /// is silently over-credited.
  static const int defaultStandBreakMinutes = 5;

  /// The workday the daily-progress figures are measured against.
  static const int workdayMinutes = 8 * 60;

  /// How long without keyboard or mouse input counts as being away.
  ///
  /// Five minutes is longer than a screen-read while still short enough that a
  /// forgotten desk is recognised before the next break is due. It exists so the
  /// app never chimes at, or seizes the screen of, an empty chair.
  static const int defaultAwayThresholdMinutes = 5;

  /// How often the OS idle reading is polled, in seconds.
  ///
  /// The reading moves at human speed, so polling every tick would be pure
  /// waste; once every few seconds is indistinguishable and far cheaper.
  static const int presencePollSeconds = 5;

  /// How long before a window opens the prelude warning appears.
  ///
  /// The prelude is the "get ready to stop" notice: it fires this many minutes
  /// before the actionable window so the user can save their work before the
  /// break begins. Unlike the action window it is purely advisory — it never
  /// changes whether a break counts, only whether the app warns first.
  static const int defaultPreludeMinutes = 5;

  /// Minutes after the start of the work day when StandUp stops offering
  /// breaks. Zero means no cut-off.
  ///
  /// Off by default on purpose: a cut-off changes what the app does for the rest
  /// of the day, so it is a choice the employee makes rather than something an
  /// upgrade switches on for them.
  static const int defaultDailyLimitMinutes = 0;

  /// What the Settings switch sets the cut-off to when it is turned on.
  ///
  /// Turning the limit on and choosing a length are two decisions; the first
  /// must not silently mean "one hour". Eight hours is a full working day, so
  /// the switch on its own is a no-op against a 9–17 schedule — which is why
  /// Settings shows the resolved cut-off time next to the value.
  static const int enabledDailyLimitMinutes = 8 * 60;

  // ── Bounds ─────────────────────────────────────────────────────────────────

  static const int minCadenceMinutes = 1;
  static const int maxCadenceMinutes = 24 * 60;

  /// Keeps a corrupt or hand-edited preference row from making `StandWindow`
  /// throw `ArgumentError` from inside the 1 Hz ticker, which would produce an
  /// unhandled async error every second and freeze the visible timer at zero.
  static int clampCadence(int minutes) =>
      minutes.clamp(minCadenceMinutes, maxCadenceMinutes);

  /// Resolves the effective action window against the cadence.
  ///
  /// A window can never be longer than the cadence it sits inside. Invalid or
  /// non-positive input falls back to [defaultActionWindowMinutes], bounded by
  /// the cadence so a one-minute cadence still yields a valid window.
  static int resolveActionWindow(int requested, int cadence) {
    final safeCadence = clampCadence(cadence);
    if (requested <= 0) {
      return safeCadence < defaultActionWindowMinutes
          ? safeCadence
          : defaultActionWindowMinutes;
    }
    return requested > safeCadence ? safeCadence : requested;
  }

  /// Resolves the effective prelude length against the cadence.
  ///
  /// The prelude sits in the gap before a window opens, so it can never be
  /// longer than the cadence it precedes. Invalid or non-positive input falls
  /// back to [defaultPreludeMinutes], bounded by the cadence.
  static int resolvePrelude(int requested, int cadence) {
    final safeCadence = clampCadence(cadence);
    if (requested <= 0) {
      return safeCadence < defaultPreludeMinutes
          ? safeCadence
          : defaultPreludeMinutes;
    }
    return requested > safeCadence ? safeCadence : requested;
  }

  // ── The option sets the UI offers ──────────────────────────────────────────
  //
  // Declared once so the settings screen, the onboarding picker and the widget
  // cannot disagree about which values exist. These were previously duplicated
  // between `settings_screen.dart` and `slide_widgets.dart`.

  /// Reminder intervals, in minutes.
  static const List<int> cadenceOptions = [30, 60, 90];

  /// Daily break goals.
  static const List<int> dailyGoalOptions = [4, 6, 8, 10, 12];

  /// Action-window lengths, in minutes.
  ///
  /// All four are honoured. [resolveActionWindow] only shortens a window that is
  /// longer than its own cadence, so with the default one-hour cadence every
  /// option here is reachable — a claim that was previously made incorrectly in
  /// the defect backlog.
  static const List<int> actionWindowOptions = [3, 5, 10, 15];

  /// Prelude-warning lengths, in minutes.
  static const List<int> preludeOptions = [1, 2, 5, 10];

  /// Cut-off lengths the UI offers, in minutes (one to twelve hours).
  ///
  /// An entry longer than the configured work day is not an error: it is a
  /// cut-off the schedule already imposes, and [WorkSchedule.dailyLimitInstant]
  /// reports it as no cut-off rather than drawing a line nothing can cross.
  static const List<int> dailyLimitOptions = [
    60,
    120,
    180,
    240,
    300,
    360,
    420,
    480,
    540,
    600,
    660,
    720,
  ];

  /// The longest cut-off the UI offers.
  static const int maxDailyLimitMinutes = 720;

  /// The shortest cut-off the UI offers.
  static const int minDailyLimitMinutes = 60;

  /// Bounds a stored cut-off to the offered range, leaving zero ("off") alone.
  ///
  /// A hand-edited row asking for a 30-minute day is rounded up to the shortest
  /// offered value rather than silently ignored, so the app never behaves as if
  /// the setting were absent.
  static int clampDailyLimit(int minutes) {
    if (minutes <= 0) return 0;
    return minutes.clamp(minDailyLimitMinutes, maxDailyLimitMinutes);
  }

  // ── Escalation ─────────────────────────────────────────────────────────────

  /// How many breaks in a row may be ignored before the break screen raises
  /// itself. Zero means escalation is off, which is the default.
  ///
  /// This is the one place StandUp borrows Workrave's "maximum number of
  /// prompts" idea. It stays off until the employee asks for it: an interruption
  /// that appears because a *previous* interruption was ignored is still an
  /// interruption the employee chose to arm, never one an upgrade armed for them.
  static const int defaultEscalationPromptLimit = 0;

  /// The limits the UI offers. Zero is "off"; the rest say how many ignored
  /// breaks in a row it takes before the screen appears on its own.
  static const List<int> escalationOptions = [0, 2, 3, 5];

  /// Bounds a stored escalation limit to the offered set.
  ///
  /// A hand-edited value outside the set is rounded *up* to the next offered
  /// limit rather than falling back to zero. For a setting whose entire purpose
  /// is enforcement, the safe direction to fail is "still enforced", not "quietly
  /// disabled".
  static int clampEscalationPromptLimit(int limit) {
    if (limit <= 0) return 0;
    for (final option in escalationOptions) {
      if (option >= limit) return option;
    }
    return escalationOptions.last;
  }

  // ── Timed quiet mode ───────────────────────────────────────────────────────

  /// The two timed pauses the dashboard offers, matching Workrave's
  /// *Temporarily Quiet…* (30 minutes / 1 hour). "Until tomorrow" is computed
  /// from the local day rather than stored, and "until I resume" is indefinite.
  static const Duration quietForThirtyMinutes = Duration(minutes: 30);
  static const Duration quietForOneHour = Duration(hours: 1);

  // ── Reminder scheduling ────────────────────────────────────────────────────

  /// How many upcoming reminders the OS queue holds.
  ///
  /// Android's `AlarmManager` and iOS's `UNNotificationRequest` limit are both
  /// 50 outstanding requests on iOS, so the app stays just under it rather than
  /// scheduling a request the OS will silently drop.
  static const int scheduledReminderQueueSize = 48;

  /// The lowest notification id used for the reminder series.
  ///
  /// A fixed base, because the ids must be stable across launches to be
  /// cancellable: a reminder at index 3 is always id 104.
  static const int reminderNotificationIdBase = 101;

  /// The lowest notification id used for the prelude series.
  ///
  /// Offset clear of the reminder series so the two are cancelled independently.
  /// Only the desktop queue uses this range: the mobile outstanding-request
  /// budget is spent entirely on the actionable reminders, and the in-app banner
  /// already covers the foreground case everywhere.
  static const int preludeNotificationIdBase = 201;

  // ── Guided stretch ─────────────────────────────────────────────────────────

  /// How long the guided stretch runs, in seconds.
  static const int guidedStretchSeconds = 300;

  /// The same length in whole minutes, for copy that states it.
  static const int guidedStretchMinutes = guidedStretchSeconds ~/ 60;

  // ── Long breaks ────────────────────────────────────────────────────────────

  /// How many windows apart the long breaks are. Zero means there are none.
  ///
  /// Workrave splits its cadence in two: a microbreak every few minutes and a
  /// restbreak every forty-five. StandUp has one cadence, so the second kind has
  /// to be periodic instead — every Nth window gets the longer break. Zero (off)
  /// is the default, because a break that is longer than asked for is a change
  /// to somebody's day that no upgrade should make on their behalf.
  static const int defaultLongBreakEvery = 0;

  /// The periods the UI offers. Zero is "never".
  static const List<int> longBreakEveryOptions = [0, 2, 3, 4];

  /// How long a long break runs. Ten minutes is Workrave's restbreak default.
  static const int defaultLongBreakMinutes = 10;

  /// The long-break lengths the UI offers, in minutes.
  static const List<int> longBreakMinutesOptions = [10, 15, 20];

  /// Bounds a stored period to the offered set, rounding *up* so a hand-edited
  /// value cannot switch long breaks off — the direction that fails safely for a
  /// setting the user deliberately turned on.
  static int clampLongBreakEvery(int every) {
    if (every <= 0) return 0;
    if (every == 1) return longBreakEveryOptions[1];
    for (final option in longBreakEveryOptions) {
      if (option >= every) return option;
    }
    return longBreakEveryOptions.last;
  }

  /// Bounds a stored long-break length to the offered set.
  ///
  /// Anything at or below zero falls back to the default: a break with no length
  /// is not a smaller break, it is a broken one.
  static int clampLongBreakMinutes(int minutes) =>
      longBreakMinutesOptions.contains(minutes)
      ? minutes
      : defaultLongBreakMinutes;

  /// The length in seconds of the guided break a window gets.
  ///
  /// A long break is the same routine run for longer, not a different one: the
  /// five movements simply repeat. That is an honest description of what the
  /// routine contains today — see gap #4 in `docs/WORKRAVE_ANALYSIS.md`, which is
  /// the lot that gives a long break movements of its own.
  static int breakSecondsFor({
    required bool longBreak,
    int longBreakMinutes = defaultLongBreakMinutes,
  }) =>
      (longBreak
          ? clampLongBreakMinutes(longBreakMinutes)
          : guidedStretchMinutes) *
      60;

  /// How many discrete steps the guided stretch has.
  ///
  /// Five, which is what the routine in `ui/widgets/guided_stretch.dart`
  /// actually shows: it was written as four here while the ticker in `AppState`
  /// counted five steps of sixty seconds, so the number a future change would
  /// have trusted was the wrong one.
  static const int guidedStretchStepCount = 5;

  /// Seconds per guided-stretch step.
  static const int guidedStretchStepSeconds =
      guidedStretchSeconds ~/ guidedStretchStepCount;

  /// Which step [secondsRemaining] puts the user on, counting from zero.
  ///
  /// Lived inside `AppState`'s one-second ticker as `4 - (remaining ~/ 60)`,
  /// which encoded the step count and the step length as literals nothing else
  /// could read. The `- 1` is not decoration: the ticker decrements before it
  /// asks, so the first second of the routine is second 299 of 300, and without
  /// it every step boundary would land one second late.
  ///
  /// [totalSeconds] defaults to the standard routine so every existing caller
  /// keeps the behaviour it had, and it exists for long breaks. The steps *repeat*
  /// rather than stretching: a ten-minute break is the five movements twice,
  /// whereas a movement that lasted two minutes would silently change what the
  /// routine asks the user to do. For the five-minute routine the modulo is a
  /// no-op — five steps, five slots, nothing to wrap.
  static int guidedStretchStepFor({
    required int secondsRemaining,
    int totalSeconds = guidedStretchSeconds,
  }) {
    final elapsed = totalSeconds - 1 - secondsRemaining;
    if (elapsed <= 0) return 0;
    return (elapsed ~/ guidedStretchStepSeconds) % guidedStretchStepCount;
  }
}
