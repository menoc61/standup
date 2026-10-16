import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the SQL scripts against the one failure mode a Dart suite cannot see
/// from the app: a reference to a column nobody creates.
///
/// `record_daily_analytics` listed `synced_to_cloud` in its `INSERT` for as long
/// as the file has existed, while no schema script ever created that column.
/// Postgres does not resolve the column when a PL/pgSQL body is created, so the
/// function installed cleanly and then failed on the *first sync* of a fresh
/// project with "column does not exist". Every Dart test, `flutter analyze` and
/// the whole build stayed green.
///
/// The checks below are deliberately narrow: one table, the columns the write
/// path touches, and the arity of its `VALUES` list. A general SQL parser is not
/// the point — catching this class of bug before a deploy is.

String get _root => Directory.current.path;

String _read(String name) =>
    File('$_root${Platform.pathSeparator}$name').readAsStringSync();

/// Strips `--` line comments so a commented-out clause can never satisfy a
/// check, and so a `;` inside prose cannot truncate a match.
String _uncommented(String raw) => raw.replaceAll(RegExp(r'--[^\n]*'), '');

/// Column names declared by `CREATE TABLE ... analytics_daily (...)`.
Set<String> _declaredColumns(String schema) {
  final body = RegExp(
    r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?public\.analytics_daily\s*\((.*?)\n\)\s*;',
    dotAll: true,
    caseSensitive: false,
  ).firstMatch(_uncommented(schema))?.group(1);
  expect(body, isNotNull, reason: 'analytics_daily table no longer declared');

  final columns = <String>{};
  for (final rawLine in body!.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    // Table constraints are not columns.
    if (RegExp(
      r'^(CONSTRAINT|PRIMARY|FOREIGN|UNIQUE|CHECK)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      continue;
    }
    final name = RegExp(r'^(\w+)\s').firstMatch(line)?.group(1);
    if (name != null) columns.add(name);
  }
  return columns;
}

/// Columns added later by `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`.
Set<String> _addedColumns(String validation) {
  final columns = <String>{};
  final pattern = RegExp(
    r'ADD\s+COLUMN\s+IF\s+NOT\s+EXISTS\s+(\w+)',
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(_uncommented(validation))) {
    columns.add(match.group(1)!);
  }
  return columns;
}

/// The column list of the insert into `analytics_daily`.
List<String> _insertColumns(String validation) {
  final match = RegExp(
    r'INSERT\s+INTO\s+public\.analytics_daily(?:\s+AS\s+\w+)?\s*\(([^)]*)\)',
    caseSensitive: false,
  ).firstMatch(_uncommented(validation));
  expect(match, isNotNull, reason: 'the analytics_daily insert is gone');
  return match!
      .group(1)!
      .split(',')
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .map((token) => token.split(RegExp(r'\s+')).last)
      .toList();
}

/// How many values the matching `VALUES (...)` list supplies.
int _insertValueCount(String validation) {
  final source = _uncommented(validation);
  final start = source.indexOf(RegExp(r'VALUES\s*\(', caseSensitive: false));
  expect(start, isNonNegative, reason: 'the insert has no VALUES list');

  var depth = 0;
  var commas = 0;
  var seenOpen = false;
  for (var i = start; i < source.length; i++) {
    final char = source[i];
    if (char == '(') {
      depth++;
      seenOpen = true;
    } else if (char == ')') {
      depth--;
      if (depth == 0 && seenOpen) break;
    } else if (char == ',' && depth == 1) {
      commas++;
    }
  }
  return commas + 1;
}

/// The columns the upsert's `SET` clause assigns.
Set<String> _upsertColumns(String validation) {
  final match = RegExp(
    r'DO\s+UPDATE\s+SET(.*?)RETURNING',
    dotAll: true,
    caseSensitive: false,
  ).firstMatch(_uncommented(validation));
  expect(match, isNotNull, reason: 'the analytics_daily upsert is gone');

  final columns = <String>{};
  for (final rawPart in match!.group(1)!.split(',')) {
    final left = rawPart.split('=').first.trim();
    if (RegExp(r'^\w+$').hasMatch(left)) columns.add(left);
  }
  return columns;
}

void main() {
  final schema = _read('supabase_schema.sql');
  final validation = _read('supabase_validation.sql');

  group('analytics_daily write path', () {
    // Built per test rather than once at group level: these helpers assert on
    // what they find, and `expect` is only legal inside a test body.
    Set<String> known() => {
      ..._declaredColumns(schema),
      ..._addedColumns(validation),
    };

    test('the schema declares the columns the validation script assumes', () {
      expect(known(), containsAll(['user_id', 'date', 'reminders_completed']));
      expect(
        known(),
        containsAll(['revision', 'trusted', 'trust_note', 'clock_suspect']),
      );
    });

    test('every inserted column exists', () {
      final missing = _insertColumns(validation)
          .where((column) => !known().contains(column))
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'supabase_validation.sql inserts into columns that no script '
            'creates. On a project built from supabase_schema.sql these fail at '
            'call time, not at create time: $missing',
      );
    });

    test('every upserted column exists', () {
      final missing = _upsertColumns(validation)
          .where((column) => !known().contains(column))
          .toList();
      expect(
        missing,
        isEmpty,
        reason: 'the ON CONFLICT DO UPDATE sets unknown columns: $missing',
      );
    });

    test('the values list matches the column list arity', () {
      // The companion bug: a column removed from the list without removing its
      // value leaves a statement Postgres rejects outright.
      expect(_insertValueCount(validation), _insertColumns(validation).length);
    });
  });
}
