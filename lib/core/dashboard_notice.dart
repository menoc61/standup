/// The one thing the dashboard banner is saying right now.
///
/// ## Why this is a rule rather than an `if` chain in the widget
///
/// The banner answers a single question — *why is the app not asking me to
/// stand up?* — from four facts that are independently computed and can all be
/// true at once. Inline conditionals made that ordering invisible: the first
/// branch won by accident of how the widget was written, and two of the states
/// were silently unreachable.
///
/// The precedence is the whole point, so it lives here where a test can pin it.
library;

/// The message the dashboard banner currently shows.
enum DashboardNotice {
  /// A window is open and the user is at the machine: act now.
  actionWindow,

  /// No input for long enough to count as absent.
  ///
  /// Deliberately the **highest** precedence. An away user cannot answer an
  /// invitation — the chime, the nudge and the screen takeover are all withheld
  /// — so showing "log your stand-up before the window closes" beside a running
  /// countdown would be an instruction they are in no position to follow, and a
  /// counter that appears to be charging them for a machine nobody is sitting
  /// at. That appearance is the exact problem the presence reading was added to
  /// solve, so it must not be re-created by the banner.
  away,

  /// The day's cut-off has passed, so no further window will be offered.
  dayFinished,

  /// Nothing is happening right now; the next window is what matters.
  nextWindow,
}

/// Which message the banner shows for the current facts.
///
/// [userAway] is asked first on purpose — see [DashboardNotice.away]. Window and
/// cut-off are then evaluated in the order that keeps an actionable invitation
/// ahead of an informational one: an open window is the only state the user can
/// still act on.
///
/// A window and a reached cut-off are not expected to coincide, because the
/// cut-off removes windows from the schedule before they can open. The ordering
/// still prefers the open window, so a disagreement between the two facts shows
/// the invitation rather than a state the user cannot act on.
DashboardNotice resolveDashboardNotice({
  required bool windowOpen,
  required bool userAway,
  required bool cutOffReached,
}) {
  if (userAway) return DashboardNotice.away;
  if (windowOpen) return DashboardNotice.actionWindow;
  if (cutOffReached) return DashboardNotice.dayFinished;
  return DashboardNotice.nextWindow;
}

/// Whether the banner's countdown belongs on screen for [notice].
///
/// False for both silent states. A countdown measures time left to act, and in
/// [DashboardNotice.away] there is nothing to act on, while in
/// [DashboardNotice.dayFinished] there is nothing left to count down to — the
/// same reason the cut-off already hides it.
bool dashboardNoticeShowsCountdown(DashboardNotice notice) =>
    notice == DashboardNotice.actionWindow ||
    notice == DashboardNotice.nextWindow;
