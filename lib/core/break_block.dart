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
}) {
  if (!blockingEnabled) return false;
  if (quiet) return false;
  if (userAway) return false;
  if (!windowOpen) return false;
  if (alreadyCompleted) return false;
  if (breakInProgress) return false;
  return true;
}
