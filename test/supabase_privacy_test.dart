import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the server-side privacy guarantees.
///
/// These assertions exist because the defect they catch was invisible from the
/// client: `flutter analyze`, the Dart suite and the app all stayed green while
/// `supabase_validation.sql` redefined the aggregate views without their
/// authorization clauses. Nothing in the app can see that a Postgres view has
/// silently become permissive, because the app only reads the result.
///
/// The two scripts define the same views. The schema file is authoritative for
/// WHO may read them; the validation file is authoritative for WHICH rows are
/// trustworthy. Neither may redefine a view while dropping the other's rules,
/// so every redefinition is checked here rather than trusted.

String get repoRoot => Directory.current.path;

/// The body of every `CREATE [OR REPLACE] VIEW <name>` statement in [source].
///
/// Line comments are stripped first. Without that, a `;` inside a `--` comment
/// ends the match early and the view body is silently truncated, which turns
/// this guard into a false negative - it would pass a view that had lost its
/// admin check simply because the explanation of that loss was commented.
Map<String, String> viewDefinitions(String raw) {
  final source = raw.replaceAll(RegExp(r'--[^\n]*'), '');
  final views = <String, String>{};
  // A definition runs until the next statement keyword at the start of a line,
  // which is how these scripts terminate every view with a semicolon.
  final pattern = RegExp(
    r'CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+([\w.]+)(.*?);',
    dotAll: true,
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(source)) {
    views[match.group(1)!] = match.group(2)!;
  }
  return views;
}

void main() {
  final schema = File('$repoRoot${Platform.pathSeparator}supabase_schema.sql')
      .readAsStringSync();
  final validation = File(
    '$repoRoot${Platform.pathSeparator}supabase_validation.sql',
  ).readAsStringSync();

  final schemaViews = viewDefinitions(schema);
  final validationViews = viewDefinitions(validation);

  group('Aggregate views keep their authorization clauses', () {
    // These are the views that expose organisation-level data. Each one must
    // restrict to admins and enforce a minimum cohort, or a single employee
    // can be read individually.
    const adminViews = ['public.org_analytics_daily'];

    for (final name in adminViews) {
      test('$name requires org admin in every definition', () {
        for (final entry in {
          'supabase_schema.sql': schemaViews[name],
          'supabase_validation.sql': validationViews[name],
        }.entries) {
          expect(
            entry.value,
            isNotNull,
            reason: '${entry.key} no longer defines $name',
          );
          expect(
            entry.value,
            contains('private.is_org_admin'),
            reason:
                '${entry.key} redefines $name without an is_org_admin check. '
                'A Postgres view runs as its owner and bypasses RLS on the '
                'base table, so without this predicate every authenticated '
                'employee can read every organisation.',
          );
        }
      });

      test('$name enforces a minimum cohort in every definition', () {
        for (final entry in {
          'supabase_schema.sql': schemaViews[name],
          'supabase_validation.sql': validationViews[name],
        }.entries) {
          expect(
            entry.value,
            contains('HAVING'),
            reason:
                '${entry.key} redefines $name without a HAVING clause, so a '
                'cohort of one employee becomes a published statistic.',
          );
          // Normalise case and whitespace away, because the two scripts spell the same
          // clause differently (`COUNT(DISTINCT user_id)` against a qualified alias).
          String normaliseSql(String sql) =>
              sql.toLowerCase().replaceAll(RegExp(r'\s+'), '');

          final cohortFloor = RegExp(r'count\(distinct[\w.]*user_id\)>=5');

          expect(
            cohortFloor.hasMatch(normaliseSql(entry.value!)),
            isTrue,
            reason:
                '${entry.key} redefines $name without the >= 5 distinct-user '
                'floor that the schema establishes.',
          );
        }
      });
    }

    test('the department view requires org admin in every definition', () {
      const name = 'public.org_department_analytics';
      for (final entry in {
        'supabase_schema.sql': schemaViews[name],
        'supabase_validation.sql': validationViews[name],
      }.entries) {
        expect(entry.value, isNotNull, reason: '${entry.key} dropped $name');
        expect(
          entry.value,
          contains('private.is_org_admin'),
          reason:
              '${entry.key} redefines $name without an is_org_admin check. '
              'This view breaks data down by department, so losing the check '
              'exposes named teams rather than only aggregate totals.',
        );
        expect(
          entry.value,
          contains('HAVING'),
          reason: '${entry.key} dropped the minimum-cohort floor',
        );
      }
    });
  });

  group('Trust filtering survives redefinition', () {
    // The validation script exists to keep untrusted rows out of leaderboards.
    // If a later edit drops the filter, the script still runs and looks fine.
    for (final name in const [
      'public.org_analytics_daily',
      'public.org_department_analytics',
    ]) {
      test('$name excludes untrusted rows', () {
        final body = validationViews[name];
        expect(body, isNotNull);
        expect(body, contains('trusted'));
        expect(body, contains('clock_suspect'));
      });
    }
  });

  group('Every view the validation script redefines already exists', () {
    // A CREATE OR REPLACE against a view the schema did not create is a new
    // object, and would silently inherit no grants.
    test('no view is introduced by the validation script alone', () {
      for (final name in validationViews.keys) {
        expect(
          schemaViews.containsKey(name),
          isTrue,
          reason:
              '$name is created by supabase_validation.sql but not declared in '
              'supabase_schema.sql. Apply order then decides its grants.',
        );
      }
    });
  });
}
