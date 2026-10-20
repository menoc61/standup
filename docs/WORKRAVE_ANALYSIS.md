# Workrave analysis — what to adopt, what to refuse, and why

## Why this document exists

Workrave is the reference implementation of "a break tool that is actually
fair": it is the tool an employee is most likely to have already compared
StandUp to, and it is the one most likely to be installed *alongside* StandUp on
the same machine. Rather than react to that, this document states — feature by
feature — what StandUp already does, what it deliberately does differently, and
what is genuinely still missing.

## Sources and method

Everything below is taken from Workrave's own documentation for the current
stable line (1.11), with the archived 1.10 pages used only where 1.11 has no
equivalent page. No third-party description, shop listing or marketing page is
used as a source, because several of them invent features Workrave does not
have.

> **Correction.** An earlier revision of this document repeated a claim — from a
> third-party listing, not from Workrave — that Workrave's **Monitoring**
> section tracks which applications and window titles are in use. It does not.
> Workrave's Monitoring page lists exactly two activity settings (`Use alternate
> monitor`, `Mouse sensitivity`) plus a Windows **Focus Assist** integration, and
> Workrave's own position is that it collects nothing and sends nothing. The
> false claim is removed; the corrected fact is used in
> [What must not be copied](#what-must-not-be-copied) instead.

Sources, all retrieved 2026-10-20:

- <https://workrave.org/about/>
- <https://workrave.org/docs/1.11/breaks/> and `/docs/breaks/reminder/`, `/docs/breaks/breaks/`
- <https://workrave.org/docs/1.11/windows/main/>, `/windows/exercises/`, `/windows/statistics/`
- <https://workrave.org/docs/1.11/menus/operation-mode/>, `/menus/reading-mode/`
- <https://workrave.org/docs/1.11/settings/>, `/settings/timers/`, `/settings/ui/`, `/settings/monitoring/`
- <https://workrave.org/docs/1.11/whats-new/>
- <https://workrave.org/faq/>

## What Workrave actually does

### Two clocks

Workrave monitors **keyboard and mouse activity** and keeps two clocks:

| Clock | Behaviour |
| --- | --- |
| *Active time* | Rises only while the keyboard or mouse is being used. Reaching "time between breaks" prompts a break. |
| *Idle time* | Rises while there is no input, and **resets to zero the instant input resumes**. Reaching "break duration" means the break was taken, and active time resets to zero. |

The consequences a reader must internalise: a break is owed after N minutes of
*real work*, not N minutes of wall clock; time away is free; and coming back and
touching the mouse can wipe a nearly-complete break.

### Three breaks, not one

- **Microbreak** — short and frequent. Default: every ~3 minutes, lasting ~30
  seconds. Look away from the screen.
- **Restbreak** — long and rare. Default: ~10 minutes every ~45 minutes. Walk
  away. Can show a configurable number of illustrated exercises at the start.
- **Daily limit** — tracks computer usage and, when the configured limit is
  reached, prompts the user to stop for the day. The counter resets at a
  configurable *time before end* (4:00 am by default). A setting,
  **Regard micro-breaks as activity**, decides whether the limit measures *time
  behind the computer* or *time actually using it*.

If a microbreak falls due and a restbreak would start within 30 seconds of it,
Workrave skips the microbreak and starts the restbreak instead.

### The reminder is a timed escalation, not a switch

This is Workrave's most distinctive piece of interaction design, and it is fully
specified in its docs:

1. A small, **non-intrusive** window appears and **automatically moves out of the
   way** so the current activity can be finished.
2. After ~20 seconds of being ignored it starts **flashing orange**.
3. A few seconds later it flashes **red**.
4. If it is still ignored it **disappears** (after roughly 30 seconds).
5. Then, depending on settings and how many times the break has already been
   ignored, Workrave **either forces the break or tries again a few minutes
   later**. The **Maximum number of prompts** setting defines how many times a
   reminder can be ignored before the break is forced; `0` means the break is
   *always* forced after the reminder.

### Break windows

- A **green bar** shows break progress; when full, the break is taken and the
  window closes.
- Using the mouse or keyboard while the break runs flashes an **orange border**
  and **freezes the break timer** — the break does not count down while you are
  working through it.
- **Postpone** closes the window and re-reminds after the configured postpone
  time. **Skip** closes the window and resets the break's timer *as if the break
  had been taken* (statistics still record it as skipped). Both buttons can be
  hidden.
- For the **daily limit**, Skip dismisses it for the rest of the day.
- Some breaks carry a **Lock** button that can lock, suspend or shut down the
  machine.

### How a break is actually enforced

The UI preferences define a **Block mode**, which is the difference between a
nag and an enforcement:

| Block mode | Behaviour |
| --- | --- |
| **Block input** | During a break, keyboard and mouse are blocked at the OS level. The break window is always on top and cannot be moved. The desktop stays visible. |
| **Block input and screen** | As above, and every other window is hidden so only the break window and wallpaper remain. |
| **No blocking** | The window can be moved and is not always on top. |

### Operation modes

- **Normal** — monitors and reminds.
- **Quiet** — keeps monitoring but stops reminding (a presentation, a call).
- **Suspended** — stops monitoring *and* reminding (someone else is using the
  machine).

1.11 adds **temporary** modes: *Temporarily Quiet…* / *Temporarily Suspended…*
for a chosen duration (30 minutes, 1 hour), **Until next day**, or
**Indefinitely**.

**Reading mode** is a separate idea: normally Workrave would not interrupt a
reader, because reading produces no input. In reading mode it starts the break
timers as soon as input begins and *keeps them running even when input stops*,
through the first restbreak, so a reader is still reminded.

Windows **Focus Assist** can be wired to switch Workrave to Quiet or Suspended
automatically while Focus Assist is active.

### Settings surface

| Section | What it exposes |
| --- | --- |
| Timers (per break) | Enable timer; time between breaks; break duration; postpone time; show postpone button; show skip button; prompt before breaking; maximum number of prompts |
| Timers (restbreak adds) | Number of exercises; **start restbreak when the screen is locked**; enable shutting down the computer from the rest screen |
| Timers (daily limit adds) | Time before end; regard micro-breaks as activity |
| Monitoring | Use alternate monitor; mouse sensitivity; Windows Focus Assist → Quiet/Suspended |
| Sounds | Volume; sound device; **sound theme** (subtle/classic); per-event sounds; **mute all audio during a rest break and daily limit** |
| User interface | Block mode; language; start on logon (Windows); system-tray icon; **status window** visibility, always-on-top, placement, cycle time and per-timer visibility |

### Exercises

Workrave can show a configurable number of **illustrated exercises** at the
start of a restbreak, with **previous / pause / next / stop** controls, and can
start them manually from the menu. After the configured number they disappear and
the break timer continues.

### Statistics

Collected **per day**, with a day selector, and reported for day, week and month:

| Metric | Meaning |
| --- | --- |
| Break prompts | Unique reminders. Repeated reminders after an ignored one are *not* counted. |
| Repeated prompted | Total reminders, *including* repeats after an ignore. |
| Prompted breaks taken | Breaks taken when reminded. |
| Natural break taken | Breaks taken **without** being reminded. |
| Breaks skipped | Times Skip was pressed. |
| Breaks postponed | Times Postpone was pressed. |
| Overdue time | Total time a break was overdue — it becomes overdue when a reminder is ignored. |
| Usage | Total computer use for the day, week and month. |

### Platforms, licence, trajectory

- Ships for **Windows, Linux and FreeBSD**. There is **no official Android or iOS
  app**; the mobile effort never shipped.
- **GPL-3.0**; parts of the code are under other licences.
- Networking across computers was deprecated and is being removed, so timers are
  becoming strictly per-machine.
- A **Qt rewrite (1.12)** is in preliminary documentation.
- Privacy position: settings stay in the user's home directory, nothing is
  reported to a server, no telemetry.

## Feature-by-feature comparison

| Capability | Workrave | StandUp | StandUp location / verdict |
| --- | --- | --- | --- |
| Activity model | Active/idle clocks driven by real input | Wall-clock windows anchored to local midnight | `data/models/stand_window.dart` — deliberate (see decision 2) |
| Break types | Microbreak + restbreak + daily limit | One 5-minute break per boundary, optional stretch inside | `core/app_cadence.dart` — deliberate (decision 3) |
| Default cadence | ~3 min micro / ~45 min rest | 60 min (30/60/90 offered) | `AppCadence.defaultCadenceMinutes`, `cadenceOptions` |
| Gentle pre-break notice | Non-intrusive window that moves itself away, escalates orange → red → disappears | Advisory prelude banner, 1/2/5/10 min, on by default, never traps input | `defaultPreludeMinutes`, `ui/widgets/prelude_alert.dart` |
| Escalation after ignored prompts | Configurable max prompts, then forced break | A configurable limit (2/3/5, default off) after which the cover raises itself; counts only windows that closed unacted **while the user was present** | `core/escalation.dart`, `AppCadence.escalationOptions` — see gap #3 for what remains |
| Forced break | Block input / block input+screen / none, at OS level | In-app `ModalBarrier` cover for the window, opt-in; window kept above on Windows/Linux | `core/break_block.dart`, `services/window_chrome.dart` — deliberate (decision 4) |
| Working through a break | Orange border + break timer freezes | Cover has no dismiss; the block simply lifts when the window ends | `ui/widgets/break_block.dart` |
| "I did it instantly" | Break timer only advances while idle, so input freezes it | 30-second anti-cheat wait, **capped by the remaining window** | `BreakBlockScreen.defaultMinWaitSeconds` |
| Postpone | Configurable postpone time, re-reminds in a few minutes | **Snooze** moves the break to the *next* window, so snoozes cannot be farmed | `AppState.snoozeReminder` |
| Skip | Resets the break timer as if taken; counted as skipped | Records the event; three in a row raise a nudge | `AppState.skipReminder` |
| Buttons on the break screen | Postpone/Skip can be hidden; daily-limit Skip lasts all day | The cover deliberately offers **neither** — the only exits are standing up or the window ending; snooze/skip live on the dashboard | `ui/widgets/break_block.dart` (doc comment), `AppState.skipReminder` |
| Exercises | Illustrated library, N per restbreak, prev/pause/next/stop, manual start | Guided stretch, 5 timed steps (300 s), from dashboard and from the cover | `AppCadence.guidedStretch*`, `ui/widgets/guided_stretch.dart` — gap #4 (library) |
| Machine off the desk | Lock / suspend / shutdown button; "start restbreak when the screen is locked" | Presence detection withholds cues and the cover while away | `core/presence.dart` — gap #5 (lock counts as rest) |
| Quiet mode | Normal / Quiet / Suspended, **timed** and until-next-day | One session-only flag read by every path, not persisted | `isInterruptionPaused`, `ui/widgets/quiet_mode_banner.dart` — gap #7 (timed) |
| OS-driven quiet | Windows Focus Assist → Quiet/Suspended | None | gap #7 |
| Reading mode | Starts timers on first input and keeps them running through the first restbreak | Not needed: the cadence does not depend on input | decision 2 |
| Statistics | 8 compliance metrics + usage, per day/week/month | Completed/snoozed/skipped, completion rate, heatmap, weekly breakdown, stand-duration trend, distribution, streak, CSV copy | `data/models/daily_analytics.dart`, `ui/screens/analytics_screen.dart` — gaps in note below |
| "Natural breaks" | Counts breaks taken without a reminder | Not represented; only window actions are recorded | gap #9 |
| "Repeated prompts" / overdue time | Both tracked | Neither tracked | gap #9 |
| Active/usage time as a metric | First-class (`Usage`, active-time bars) | Not surfaced (the OS reading exists but is only used for presence) | `services/idle_time_source.dart` — gap #6 |
| Progress game | None | XP, levels, daily goal, streak, leaderboard | `data/models/gamification_metrics.dart` — StandUp ahead |
| Desktop status surface | Always-on-top timer window + tray icon (placement, cycle, per-timer visibility) | Mobile home-screen widget (Android + iOS); no desktop tray or status window | `home_widget`, `lib/data/local/widget_*` — gap #8 on desktop |
| Sound | Volume, two themes, per-event sounds, mute during restbreak | Per-action sound choice, on/off, haptics; volume exists as a field but is not a user setting, and there is no theme or mute-during-break control | `services/audio_service.dart`, `settings_screen.dart` — gap #8 |
| Start on logon | Windows setting | Windows registry + Linux XDG autostart | `services/autostart_service.dart` — match |
| Multi-machine | Deprecated network timer sharing | Local-first; only opt-in aggregates sync, timers stay per-device | deliberate |
| Platforms | Windows / Linux / FreeBSD | Android-first + Windows/Linux desktop | StandUp ahead on mobile |
| Language | UI language picker | FR + EN dictionary, every visible string covered | `core/app_strings.dart` — match |
| Licence | GPL-3.0 | MIT (per repository) | copy boundary |

## Where StandUp is structurally ahead

- **It runs on the phone.** Workrave has no official mobile app and never
  shipped one. A stand-up reminder that only exists on the office desktop is
  absent from exactly the device the employee carries to a meeting.
- **Organisation value without surveillance.** Workrave is a single-player tool
  with personal statistics. StandUp adds admin-scoped, cohort-protected
  aggregates that are server-validated and — by policy — incapable of exposing
  one person's breaks, while individual feedback and activity inputs stay local.
- **Gamification that Workrave lacks entirely.** XP, levels, daily goal rings,
  streaks and a leaderboard give a reason to *want* the break; Workrave only ever
  asks for compliance.
- **An anti-cheat that fits an in-app cover.** Workrave can freeze its break
  timer on input because it can block input. StandUp cannot and will not, so it
  asks for a short, window-capped wait instead — the same intent, honest about
  the platform.
- **Bilingual copy as an invariant.** Every user-visible string goes through the
  dictionary with FR and EN coverage; a missing key is a test failure.

## Four differences that are decisions, not gaps

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

This is also why StandUp needs no **reading mode**. Reading mode exists because
Workrave would otherwise stay silent for someone who reads for an hour without
touching the keyboard. StandUp's reminder does not depend on input at all, so the
reader is reminded on the same cadence as everyone else with nothing to configure.

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

### 4. StandUp does not block the keyboard and mouse

Workrave's strongest setting hides every window and swallows input at the OS
level. That is a hostile, privileged integration: it needs platform input hooks,
it is precisely the behaviour that makes "wellness software" feel like
surveillance hardware, and it cannot be verified here — `docs/PLATFORM_SETUP.md`
is explicit that the forced break is an in-app cover, "not an OS lock", and that
no background or screen-level guarantee may be claimed without a
platform-specific build and test. The cover plus `setKeepAbove` on Windows and
Linux is the whole promise, and the docs say so.

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
   `StandWindow.windowsBetween` already computes the denominator needed to derive
   it, so the missing piece is a recorded counter, not new arithmetic.
3. **Escalation: partially closed.** The setting now exists — *Settings → Reminder
   Cadence* offers 2, 3 or 5 ignored breaks in a row (or never), after which the
   cover raises itself, and `IgnoredPromptTracker` (`core/escalation.dart`) does the
   counting. Two deliberate differences from Workrave remain. First, it is a
   *separate* opt-in from the forced break rather than a property of the prompt
   warning: an interruption that appears because a previous interruption was
   ignored is still an interruption, so nothing may arm it but the employee.
   Second, and more consequentially, only windows that closed with **no recorded
   action while the user was at the desk** are counted. Workrave escalates on a
   timer that ignores presence; StandUp cannot, because charging an empty chair is
   the exact failure the presence work exists to prevent, and where presence is
   unavailable (Android, iOS, web) the feature is inert rather than approximate.
   What is still missing is Workrave's *middle* step — an escalation that makes the
   existing prompt harder to miss (orange → red) before it becomes a cover.
4. **An exercise library.** Workrave ships illustrated exercises with
   next/pause navigation. StandUp has 5 timed steps, reachable from both the
   dashboard and the forced-break cover. Adding a real library means storing
   exercise content — a data model change, so it needs the same migration care as
   any other schema change.
5. **Screen lock counted as a rest.** Workrave can treat a locked screen as a
   completed break, which matters for a user who steps away and locks the
   machine. StandUp's presence reading covers "stepped away" but not "locked and
   done".
6. **Counting active minutes as a first-class metric.** The OS reading already
   exists on Windows and Linux; surfacing "you worked 5h 40m of screen time"
   would answer a question the current analytics cannot.
7. **A timed quiet mode, ideally driven by the OS.** Workrave's *Temporarily
   Quiet…* (30 minutes / 1 hour / until next day) and its Focus Assist integration
   mean a presentation never has to be fought reminder by reminder. StandUp's
   quiet mode is session-only and manual. A duration is a small change; the Focus
   Assist hook is platform work but privacy-neutral.
8. **Desktop surfaces and sound control.** An always-on-top desktop timer window
   and tray icon (Workrave's most-used surface), plus a sound theme and a
   mute-during-break control. Lower value on a mobile-first product, higher value
   on the desktop builds.
9. **The three statistics Workrave reports and StandUp cannot.** "Natural breaks"
   (taken without a reminder), "repeated prompts" (total reminders including
   repeats) and "overdue time" (how long a break stayed ignored). The first needs
   a definition StandUp's model does not currently have; the other two need
   prompt-level recording rather than action-level recording.

## What must not be copied

- **OS-level input blocking and screen hiding.** See decision 4. It is a
  privileged, hostile integration that `docs/PLATFORM_SETUP.md` already disclaims.
- **Workrave's exercise artwork or source.** Workrave is GPL-licensed. Its ideas
  and its documented behaviour are fair to learn from; copying its images or code
  into an MIT codebase would import that obligation.
- **Any per-employee usage reporting to administrators.** Workrave's statistics
  are personal by design. CNPS administrators see server-validated, admin-scoped,
  cohort-protected aggregates — never an individual's screen time.
- **The misconception that Workrave watches your applications.** It does not, and
  StandUp must not either. Recorded here because the *opposite* mistake — copying
  a competitor's app-and-window-title tracking because "they do it" — is exactly
  the argument a future contributor might make. Workrave's Monitoring page has
  two settings and neither is tracking; StandUp's boundary is stricter still, and
  it is stated in `docs/ARCHITECTURE.md`.
- **Cross-machine timer sharing.** Workrave's network mode is deprecated. StandUp
  syncs opt-in aggregates; the timers stay local and per-device, which keeps the
  privacy promise and removes a whole class of clock-reconciliation bugs.
