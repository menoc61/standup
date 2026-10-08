import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/data/models/leaderboard.dart';
import 'package:standup_app/data/models/org_analytics.dart';

/// The leaderboard was the screen reported as "buggy". Three separate defects
/// are pinned here, each of which looked like a rendering fault but lived in the
/// ranking logic.
void main() {
  group('Personal bests', () {
    test('days with no breaks are excluded entirely', () {
      // The clearest defect: an empty or sparse history produced a board of
      // zeros, reading as either a bug or an accusation.
      final entries = LeaderboardBuilder.fromPersonalHistory([
        const DailyAnalyticsLike(label: 'Jan 1', completed: 4, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'Jan 2', completed: 0, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'Jan 3', completed: 0, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'Jan 4', completed: 2, unit: 'breaks'),
      ]);

      expect(entries.map((e) => e.name), ['Jan 1', 'Jan 4']);
      expect(
        entries.any(
          (e) => e.name.contains('Jan 2') || e.name.contains('Jan 3'),
        ),
        isFalse,
      );
    });

    test('an empty history produces an empty board, not a board of zeros', () {
      expect(LeaderboardBuilder.fromPersonalHistory(const []), isEmpty);
    });

    test('a history of only zero-break days produces an empty board', () {
      final entries = LeaderboardBuilder.fromPersonalHistory([
        const DailyAnalyticsLike(label: 'Jan 1', completed: 0, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'Jan 2', completed: 0, unit: 'breaks'),
      ]);
      expect(entries, isEmpty);
    });

    test('rows are ordered strongest first', () {
      final entries = LeaderboardBuilder.fromPersonalHistory([
        const DailyAnalyticsLike(label: 'Mon', completed: 3, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'Tue', completed: 7, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'Wed', completed: 5, unit: 'breaks'),
      ]);

      expect(entries.map((e) => e.name), ['Tue', 'Wed', 'Mon']);
      expect(entries.map((e) => e.rank), ['1', '2', '3']);
    });

    test('ties share a rank and the next rank skips', () {
      // Sports-table ranking: two on 7 breaks are both 2nd, the next is 4th.
      // Numbering by position would print 1, 2, 3 and imply a false ordering.
      final entries = LeaderboardBuilder.fromPersonalHistory([
        const DailyAnalyticsLike(label: 'A', completed: 7, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'B', completed: 7, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'C', completed: 3, unit: 'breaks'),
      ]);

      expect(entries.map((e) => e.name), ['A', 'B', 'C']);
      expect(entries.map((e) => e.rank), ['1', '1', '3']);
    });

    test('three-way tie all report first place', () {
      final entries = LeaderboardBuilder.fromPersonalHistory([
        const DailyAnalyticsLike(label: 'A', completed: 5, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'B', completed: 5, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'C', completed: 5, unit: 'breaks'),
      ]);
      expect(entries.map((e) => e.rank), ['1', '1', '1']);
    });

    test('order is stable across rebuilds when scores tie', () {
      // A rebuild must not reshuffle equal rows, or the list visibly jitters
      // every time the user changes a setting.
      List<LeaderboardEntry> build() => LeaderboardBuilder.fromPersonalHistory([
        const DailyAnalyticsLike(label: 'Mar', completed: 4, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'Jan', completed: 4, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'Feb', completed: 4, unit: 'breaks'),
      ]);

      // Ties fall back to the label, which is stable and deterministic even
      // though the database is not guaranteed to return rows in date order.
      expect(build().map((e) => e.name), ['Feb', 'Jan', 'Mar']);
      expect(build().map((e) => e.name), build().map((e) => e.name));
    });

    test('progress is relative to the strongest day', () {
      final entries = LeaderboardBuilder.fromPersonalHistory([
        const DailyAnalyticsLike(label: 'A', completed: 8, unit: 'breaks'),
        const DailyAnalyticsLike(label: 'B', completed: 4, unit: 'breaks'),
      ]);

      expect(entries.first.progress, 1.0);
      expect(entries.last.progress, closeTo(0.5, 0.001));
    });

    test('at most seven rows are shown', () {
      final entries = LeaderboardBuilder.fromPersonalHistory([
        for (var i = 1; i <= 20; i++)
          DailyAnalyticsLike(label: 'D$i', completed: i, unit: 'breaks'),
      ]);
      expect(entries.length, 7);
    });

    test('the current day is flagged so it can be highlighted', () {
      final entries = LeaderboardBuilder.fromPersonalHistory([
        const DailyAnalyticsLike(
          label: 'Today',
          completed: 6,
          unit: 'breaks',
          isCurrentUser: true,
        ),
        const DailyAnalyticsLike(
          label: 'Yesterday',
          completed: 4,
          unit: 'breaks',
        ),
      ]);

      expect(entries.first.isCurrentUser, isTrue);
      expect(entries.last.isCurrentUser, isFalse);
    });
  });

  group('Department standings', () {
    test('departments with no breaks are excluded', () {
      final entries = LeaderboardBuilder.fromDepartments(
        _org([
          _dept('Engineering', completed: 30),
          _dept('Design', completed: 0),
        ]),
      );

      expect(entries.map((e) => e.name), ['Engineering']);
    });

    test('an organisation with no activity produces an empty board', () {
      expect(
        LeaderboardBuilder.fromDepartments(_org([_dept('Ops', completed: 0)])),
        isEmpty,
      );
    });

    test('ties share a rank', () {
      final entries = LeaderboardBuilder.fromDepartments(
        _org([
          _dept('A', completed: 20),
          _dept('B', completed: 20),
          _dept('C', completed: 9),
        ]),
      );

      expect(entries.map((e) => e.rank), ['1', '1', '3']);
    });

    test('progress is relative to the leading department', () {
      final entries = LeaderboardBuilder.fromDepartments(
        _org([_dept('A', completed: 40), _dept('B', completed: 20)]),
      );

      expect(entries.first.progress, 1.0);
      expect(entries.last.progress, closeTo(0.5, 0.001));
    });

    test('no individual is ever named', () {
      // The privacy contract: only anonymized aggregates appear.
      final entries = LeaderboardBuilder.fromDepartments(
        _org([_dept('Engineering', completed: 10)]),
      );
      for (final entry in entries) {
        expect(entry.name.toLowerCase(), isNot(contains('@')));
      }
    });
  });
}

DepartmentMetric _dept(String name, {required int completed}) {
  return DepartmentMetric(
    department: name,
    activeUsers: 5,
    totalCompleted: completed,
    totalSkipped: 0,
    adherenceRate: 0.8,
  );
}

OrgAnalytics _org(List<DepartmentMetric> departments) {
  final completed = departments.fold<int>(
    0,
    (sum, d) => sum + d.totalCompleted,
  );
  return OrgAnalytics(
    organizationId: 'org_1',
    organizationName: 'CSPH',
    date: '2026-01-07',
    activeUsers: departments.length * 5,
    totalSent: completed,
    totalCompleted: completed,
    totalSnoozed: 0,
    totalSkipped: 0,
    totalStandMinutes: completed * 2,
    adherenceRate: 0.8,
    departmentMetrics: departments,
  );
}
