import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/models/org_analytics.dart';

/// The admin dashboard's direction arrow is arithmetic on a window that is not
/// always full. These tests pin the cases that would otherwise read as a
/// confident claim about nothing: one day, an empty window, and a window whose
/// newest day must not be compared against its own contribution.
void main() {
  OrgAnalytics day(String date, double rate) => OrgAnalytics(
    organizationId: 'org-1',
    organizationName: 'Acme',
    date: date,
    activeUsers: 8,
    totalSent: 40,
    totalCompleted: 30,
    totalSnoozed: 4,
    totalSkipped: 6,
    totalStandMinutes: 150,
    adherenceRate: rate,
  );

  group('OrgTrendSummary', () {
    test('an empty window has no direction and claims no rate', () {
      final summary = OrgTrendSummary.of(const []);
      expect(summary.dayCount, 0);
      expect(summary.latestRate, 0);
      expect(summary.hasDirection, isFalse);
    });

    test('a single day is not a trend', () {
      // A delta of zero here would render as "flat", which is a claim the data
      // cannot support: nothing was compared.
      final summary = OrgTrendSummary.of([day('2026-05-02', 42)]);
      expect(summary.dayCount, 1);
      expect(summary.latestRate, 42);
      expect(summary.hasDirection, isFalse);
      expect(summary.deltaPoints, isNull);
    });

    test(
      'the newest day is compared against the others, not against itself',
      () {
        // 80, 60, 40 -> the earlier average is 50, so the delta is +30. If the
        // newest day were included in its own baseline (60) the dashboard would
        // report +20 and quietly understate the move.
        final summary = OrgTrendSummary.of([
          day('2026-05-03', 80),
          day('2026-05-02', 60),
          day('2026-05-01', 40),
        ]);
        expect(summary.dayCount, 3);
        expect(summary.earlierAverageRate, closeTo(50, 0.001));
        expect(summary.deltaPoints, closeTo(30, 0.001));
        expect(summary.hasDirection, isTrue);
      },
    );

    test('a fall is reported as a negative delta', () {
      final summary = OrgTrendSummary.of([
        day('2026-05-03', 40),
        day('2026-05-02', 70),
        day('2026-05-01', 80),
      ]);
      expect(summary.deltaPoints, closeTo(-35, 0.001));
    });

    test(
      'a shorter window still compares, without dividing by the full one',
      () {
        // Two days is the smallest window with a direction, and it must not be
        // padded with zeroes to reach a nominal length.
        final summary = OrgTrendSummary.of([
          day('2026-05-02', 90),
          day('2026-05-01', 70),
        ]);
        expect(summary.dayCount, 2);
        expect(summary.earlierAverageRate, closeTo(70, 0.001));
        expect(summary.deltaPoints, closeTo(20, 0.001));
      },
    );
  });
}
