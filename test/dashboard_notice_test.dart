import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/dashboard_notice.dart';

/// The banner answers "why is the app silent?" from four facts that can all be
/// true at once, so the tests here are mostly about precedence: an away user must
/// never be shown an invitation they cannot answer, and a silent state must never
/// be shown a countdown to something that will not happen.
void main() {
  group('resolveDashboardNotice', () {
    test('an open window for a present user is the actionable state', () {
      expect(
        resolveDashboardNotice(
          windowOpen: true,
          userAway: false,
          cutOffReached: false,
        ),
        DashboardNotice.actionWindow,
      );
    });

    test('a closed window falls back to the next one', () {
      expect(
        resolveDashboardNotice(
          windowOpen: false,
          userAway: false,
          cutOffReached: false,
        ),
        DashboardNotice.nextWindow,
      );
    });

    test('a reached cut-off is its own state, not a closed window', () {
      expect(
        resolveDashboardNotice(
          windowOpen: false,
          userAway: false,
          cutOffReached: true,
        ),
        DashboardNotice.dayFinished,
      );
    });

    test('away outranks an open window', () {
      // The case this rule exists for. An away user is not told to "log your
      // stand-up before the window closes": the app is deliberately not asking
      // them to do anything, so an invitation is a lie with a countdown on it.
      expect(
        resolveDashboardNotice(
          windowOpen: true,
          userAway: true,
          cutOffReached: false,
        ),
        DashboardNotice.away,
        reason: 'the window is not actionable while nobody is at the desk',
      );
    });

    test('away outranks the cut-off as well', () {
      // Both explain the silence, but away is the one that resolves the moment
      // the user comes back, and it is the one they are about to stop needing.
      expect(
        resolveDashboardNotice(
          windowOpen: false,
          userAway: true,
          cutOffReached: true,
        ),
        DashboardNotice.away,
      );
    });

    test('returning mid-window restores the invitation', () {
      // The other half of the away rule: the cue is withheld while absent but
      // never cancelled, so the moment presence flips back the open window has
      // to be visible again.
      final before = resolveDashboardNotice(
        windowOpen: true,
        userAway: true,
        cutOffReached: false,
      );
      final after = resolveDashboardNotice(
        windowOpen: true,
        userAway: false,
        cutOffReached: false,
      );
      expect(before, DashboardNotice.away);
      expect(after, DashboardNotice.actionWindow);
    });

    test('an open window outranks a cut-off the two facts disagree about', () {
      // The cut-off removes windows from the schedule before they can open, so
      // this cannot normally happen. If it ever does, showing the invitation is
      // the honest answer: it is the only state the user can still act on.
      expect(
        resolveDashboardNotice(
          windowOpen: true,
          userAway: false,
          cutOffReached: true,
        ),
        DashboardNotice.actionWindow,
      );
    });
  });

  group('dashboardNoticeShowsCountdown', () {
    test(
      'a countdown appears only where there is something to count down to',
      () {
        expect(
          dashboardNoticeShowsCountdown(DashboardNotice.actionWindow),
          isTrue,
        );
        expect(
          dashboardNoticeShowsCountdown(DashboardNotice.nextWindow),
          isTrue,
        );
      },
    );

    test('neither silent state shows a countdown', () {
      // Away: the countdown would keep running towards a window the user cannot
      // act on, which is the "the counter is charging me" appearance.
      expect(dashboardNoticeShowsCountdown(DashboardNotice.away), isFalse);
      // Day finished: there is nothing left to count down to.
      expect(
        dashboardNoticeShowsCountdown(DashboardNotice.dayFinished),
        isFalse,
      );
    });

    test('every notice has a decided countdown behaviour', () {
      // Guards a new enum member: adding one without choosing would silently
      // default to whatever the comparison happens to say.
      for (final notice in DashboardNotice.values) {
        expect(
          dashboardNoticeShowsCountdown(notice),
          notice != DashboardNotice.away &&
              notice != DashboardNotice.dayFinished,
          reason: 'undecided countdown for $notice',
        );
      }
    });
  });
}
