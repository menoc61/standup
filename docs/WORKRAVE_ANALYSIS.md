# Workrave analysis — what to adopt, what to refuse, and why

## Why this document exists

Workrave is the reference implementation of "a break tool that is actually fair":
it is the tool an employee is most likely to have already compared StandUp to,
and it is the one most likely to be installed *alongside* StandUp on the same
machine. Rather than react to that, this document states — feature by feature —
what StandUp already does, what it deliberately does differently, and what is
genuinely still missing.

The feature descriptions below come from Workrave's own documentation, not from
memory:

- [About Workrave](https://workrave.org/about/)
- [Breaks](https://workrave.org/docs/breaks/)
- [Break windows](https://workrave.org/docs/breaks/breaks/)
- [Timers settings](https://workrave.org/docs/settings/timers/)

## What Workrave actually does

Workrave monitors **keyboard and mouse activity** and keeps two clocks:

| Clock | Behaviour |
| --- | --- |
| *Active time* | Rises while the keyboard or mouse is being used. Reaching "time between breaks" triggers a break. |
| *Idle time* | Rises while there is no input. Reaching "break duration" means the break was taken and active time resets to zero. |

On top of that it runs **three kinds of break**, not one:

- **Microbreak** — short and frequent (by default every ~3 minutes, lasting ~30
  seconds). Look away from the screen.
- **Restbreak** — long and rare (by default ~10 minutes every ~45 minutes). Walk
  away. Can display a configurable number of illustrated exercises at the start,
  and can offer a Lock button that locks, suspends or shuts down the machine.
- **Daily limit** — tracks *actual computer usage* and, when the limit is reached,
  prompts the user to stop for the day. The counter resets at a configurable
  "time before end" (4:00 am by default). A setting decides whether micro-breaks
  count toward it, i.e. whether it measures *time behind the computer* or *time
  actually using it*.

Interruption handling is deliberately layered: a **gentle, self-moving-away
reminder** before the break; **Postpone** (try again in a few minutes) and
**Skip** (treat as taken, reset the timer) buttons that can each be hidden; and
**escalation** — a configurable "maximum number of prompts", after which ignoring
the reminder forces the break instead of retrying.

Statistics count breaks **taken, ignored and postponed**, plus usage per
day/week/month, and the tool has distinct **normal / quiet / suspended** modes.

## Where StandUp already matches it

| Workrave | StandUp | Where |
| --- | --- | --- |
| Gentle reminder before a break | 5-minute advisory heads-up, configurable 1/2/5/10 min, off by default | `AppCadence.defaultPreludeMinutes`, `ui/widgets/prelude_alert.dart` |
| Break screen that takes over | Opt-in full-app cover for the length of the window | `core/break_block.dart`, `ui/widgets/break_block.dart` |
| Screen stays in front while the break runs | `WindowChrome.setKeepAbove` on transition (Windows + Linux) | `services/window_chrome.dart` |
| Postpone | **Snooze** moves the break to the *next* window rather than granting a fresh delay, so snoozes cannot be farmed | `AppState.snoozeReminder` |
| Skip | Skip records the event and feeds the three-in-a-row nudge | `AppState.skipReminder` |
| Escalation after ignored prompts | Binary: forced break is opt-in (`breakBlockingEnabled`, default **off**) | `UserPreferences.breakBlockingEnabled` |
| Statistics | Daily analytics, contribution heatmap, charts, local CSV export | `ui/screens/analytics_screen.dart` |
| Daily limit | Optional cut-off after N hours of the scheduled work day | `WorkSchedule.dailyLimitInstant` |
| Quiet mode | One flag read by every interruption path, deliberately not persisted, announced by a banner | `core/presence.dart`, `ui/widgets/quiet_mode_banner.dart` |
| Idle-aware supervision | OS idle reading → present/away; chimes, nudges and the screen takeover are all withheld while away | `ActiveTimeTracker`, `IdleTimeSource` |
| Exercises during a long break | Guided stretch, 5 minutes in 5 timed steps — offered on the dashboard **and** on the forced-break cover | `AppCadence.guidedStretchSeconds`, `ui/widgets/guided_stretch.dart` |

## Three differences that are decisions, not gaps

### 1. The daily limit counts the *scheduled* day, not the time actually worked

Workrave's limit is usage accounting: it watches active time accumulate and
forces a rest when it passes the limit. Reproducing that here would mean
continuously tracking desk occupancy, reconciling it across suspend and clock
changes, and then firing an interruption that no setting the employee chose
explains. StandUp expresses the same intent as "N hours after your work day
starts", which the user can compute from their own schedule and cannot be wrong
about how long they were actually at the desk. Settings prints the resolved clock
time next to the number for exactly this reason.

**Consequence:** a user who works six hours straight from a nine-to-five schedule
still gets a six-hour cut-off. Workrave would have stopped them at six hours of
*real* work regardless of the wall clock. This is the single largest behavioural
difference between the two tools.

### 2. The cadence is anchored to the wall clock, not to activity

Workrave's central insight is that a break is owed after N minutes of **actual
work**, so time spent away resets the counter. StandUp anchors every window to a
local clock boundary (`StandWindow`), which is what makes the OS notification
queue, the action gate, the widget and the org aggregates all agree on the same
instant.

What StandUp does adopt is Workrave's *fairness* consequence: **time away is
never charged to the user.** Nothing is written to the counters unless the user
actively does something — `remindersSent` is incremented inside
`recordReminderAction`, not by a timer — so a window that opened and expired over
an unattended desk adds no completion, no skip, no XP and no streak damage. The
absence also suppresses the chime, the nudge and the screen takeover, while
leaving the cue itself unplayed so someone returning mid-window still hears the
invitation they missed.

### 3. One break type instead of three

Workrave offers a 30-second look-away and a 10-minute walk-away as different
things. StandUp has a single 5-minute break per cadence boundary, plus an
optional guided stretch inside it. The action-window rule ("a stand-up only
counts in the last N minutes of the hour") is the app's core product idea and is
not diluted by adding a second cadence.

## What is genuinely still missing

Ordered by value per unit of work. None of these are started.

1. **A long break every Nth window.** The cheapest way to approximate Workrave's
   microbreak/restbreak split on top of the existing cadence: every *n*th window
   is long (walk away) instead of the standard one. Pure `AppCadence` arithmetic
   plus one flag in the window rules — no new data model, no new screen.
2. **Accounting for windows that expire untouched.** StandUp records completed,
   snoozed and skipped, so a silently expired window is invisible — not a
   completion, not a skip, not a miss. A `missed` concept makes the analytics
   honest and gives the AI guidance a fourth signal to learn from.
3. **Escalation instead of a binary forced break.** Workrave's "maximum number of
   prompts" turns ignored reminders into a forced break. StandUp's cover is
   all-or-nothing per user, so the softer middle ground is missing.
4. **An exercise library.** Workrave ships illustrated exercises with next/pause
   navigation. StandUp has 5 timed steps, reachable from both the dashboard and
   the forced-break cover. Adding a real library means storing exercise content —
   a data model change, so it needs the same migration care as any other schema
   change.
5. **Screen lock counted as a rest.** Workrave can treat a locked screen as a
   completed break, which matters for a user who steps away and locks the
   machine. StandUp's presence reading covers "stepped away" but not "locked and
   done".
6. **Counting active minutes as a first-class metric.** The OS reading already
   exists on Windows and Linux; surfacing "you worked 5h 40m of screen time"
   would answer a question the current analytics cannot.

## What must not be copied

- **Window-title / application monitoring.** Workrave's Monitoring section can
  track which programs are in use. This is the opposite of StandUp's privacy
  architecture: raw activity stays on the device, only an explicit action is
  ever recorded, and organisation analytics stay cohort aggregates that cannot
  identify an individual. This is a product boundary, not a missing feature.
- **Any per-employee usage reporting to administrators.** Workrave's statistics
  are personal by design. CNPS administrators see server-validated, admin-scoped,
  cohort-protected aggregates — never an individual's screen time.
- **Workrave's exercise artwork or source.** Workrave is GPL-licensed. Its ideas
  and its documented behaviour are fair to learn from; copying its images or code
  into an MIT codebase would import that obligation.