import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/models/org_analytics.dart';

/// The activity mix is the only place on the admin dashboard that splits the
/// reminders the server counted. The arithmetic is trivial, which is exactly why
/// it is worth pinning: an off-by-one between "sent" and the three outcomes
/// would quietly reclassify reminders as unanswered, and the reader has no way
/// to tell from the screen.
void main() {
  OrgAnalytics org({
    required int sent,
    int completed = 0,
    int snoozed = 0,
    int skipped = 0,
  }) {
    return OrgAnalytics(
      organizationId: 'org-1',
      organizationName: 'CNPS',
      date: '2026-10-20',
      activeUsers: 12,
      totalSent: sent,
      totalCompleted: completed,
      totalSnoozed: snoozed,
      totalSkipped: skipped,
      totalStandMinutes: completed * 5,
      adherenceRate: sent == 0 ? 0 : completed / sent * 100,
    );
  }

  group('Outcome split', () {
    test('the remainder is reported as unanswered, not folded elsewhere', () {
      final mix = OrgActivityMix.from(
        org(sent: 20, completed: 12, snoozed: 3, skipped: 4),
      );

      expect(mix.unanswered, 1, reason: '20 - 12 - 3 - 4');
      expect(mix.denominator, 20);
    });

    test('shares are fractions of what was sent', () {
      final mix = OrgActivityMix.from(
        org(sent: 40, completed: 10, snoozed: 20, skipped: 10),
      );

      expect(mix.shareOf(10), closeTo(0.25, 1e-9));
      expect(mix.shareOf(20), closeTo(0.5, 1e-9));
      expect(mix.shareOf(0), 0);
    });

    test('outcomes that exceed sends cannot produce a negative remainder', () {
      // A stored row can be inconsistent after a manual correction even though
      // the server withholds untrusted ones. A negative remainder would make the
      // stacked bar thinner than its container and print a negative count.
      final mix = OrgActivityMix.from(
        org(sent: 5, completed: 5, snoozed: 2, skipped: 1),
      );

      expect(mix.unanswered, 0);
      expect(mix.denominator, 5);
    });

    test('no sends falls back to the outcomes as the denominator', () {
      final mix = OrgActivityMix.from(org(sent: 0, completed: 3, snoozed: 1));

      expect(mix.denominator, 4);
      expect(mix.shareOf(3), closeTo(0.75, 1e-9));
    });

    test('an empty day reports zero shares instead of dividing by zero', () {
      final mix = OrgActivityMix.from(org(sent: 0));

      expect(mix.denominator, 0);
      expect(mix.shareOf(10), 0);
      expect(mix.unanswered, 0);
    });
  });
}
