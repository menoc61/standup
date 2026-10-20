/// The rule for when the forced break may take over the screen.
///
/// ## Why this is a free function
///
/// The decision reads four independent facts, three of which can only be wrong
/// in the app state if this one is wrong. Keeping it pure means the whole rule
/// is pinned by unit tests rather than inferred from widget behaviour, and the
/// screen and the timer cannot drift apart.
///
/// Every input is a reason the block must *not* fire, and each one is a real
/// failure the app must avoid:
///
/// * `blockingEnabled` — an intrusive feature is opt-in, never forced on a user
///   by an upgrade.
/// * `escalationDue` — the second, independently armed way the cover may appear:
///   the employee asked for it to raise itself after a streak of ignored breaks.
///   It is a different opt-in, not an exception to one.
/// * `quiet` — "do not interrupt me" outranks every other reason to cover the
///   screen: a demo, a call or a presentation is exactly when a takeover would
///   be most damaging, and it is the one veto the user sets by hand.
/// * `userAway` — seizing the screen of someone in a meeting is worse than
///   missing the break entirely.
/// * `windowOpen` — the block belongs to the break window, not to the whole hour.
/// * `alreadyCompleted` — once the break is logged the block has done its job
///   and must get out of the way.
/// * `breakInProgress` — the guided stretch already owns the screen; raising the
///   block on top of it would fight the flow it exists to serve.
library;

bool shouldBlockBreak({
  required bool blockingEnabled,
  required bool userAway,
  required bool windowOpen,
  required bool alreadyCompleted,
  required bool breakInProgress,
  bool quiet = false,
  bool escalationDue = false,
}) {
  // Escalation is the second, independently armed reason the cover may appear:
  // the employee asked for it to raise itself after a streak of ignored breaks.
  // It is not a loophole around the opt-in — it *is* an opt-in, a different one
  // — so the remaining vetoes below apply to it exactly as they do to a block
  // the user switched on by hand.
  if (!blockingEnabled && !escalationDue) return false;
  if (quiet) return false;
  if (userAway) return false;
  if (!windowOpen) return false;
  if (alreadyCompleted) return false;
  if (breakInProgress) return false;
  return true;
}

/// What the forced-break overlay should be showing right now.
enum BreakBlockView {
  /// Nothing: the app underneath is interactive.
  none,

  /// The cover.
  cover,

  /// The guided routine, swapped in where the cover asked for it.
  guidedStretch,
}

/// Picks the overlay's surface from the facts the overlay itself holds.
///
/// ## The case this exists for
///
/// [shouldBlockBreak] vetoes the cover while a break is in progress, because the
/// guided routine already owns the screen. That is right when the routine was
/// started from the dashboard, and wrong when it was started *from the cover*:
/// the cover would vanish on the same tap that asked it for the routine, taking
/// the routine with it. `coverRequestedStretch` is what separates the two — the
/// one who asked keeps something on screen, the one who did not is left alone
/// with the sheet they already have.
BreakBlockView breakBlockView({
  required bool active,
  required bool windowOpen,
  required bool coverEligible,
  required bool coverRequestedStretch,
  required bool breakInProgress,
}) {
  if (!active || !windowOpen) return BreakBlockView.none;
  if (coverEligible) return BreakBlockView.cover;
  if (coverRequestedStretch && breakInProgress) {
    return BreakBlockView.guidedStretch;
  }
  return BreakBlockView.none;
}
