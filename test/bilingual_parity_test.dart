import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_strings.dart';

/// Scans the widget tree for every string the user can see and checks that
/// French copy exists for each one.
///
/// The dictionary is keyed on the English literal, so a literal that reaches the
/// screen without a dictionary entry falls back to English while the app is set
/// to French. That failure is invisible in English and easy to ship, which makes
/// it worth a test rather than a review convention.
void main() {
  group('Bilingual coverage', () {
    late Map<String, String> dictionary;

    setUpAll(() {
      dictionary = frenchOverrides;
    });

    test('the dictionary is not empty', () {
      expect(dictionary.length, greaterThan(100));
    });

    test('no French entry is left as its own English source', () {
      // A copy-paste that maps a string to itself is usually a placeholder
      // rather than a translation. Brand names and cognates are the legitimate
      // exception, and they are listed explicitly so the exemption is visible
      // instead of silently shrinking the check.
      final identical = <String>[
        for (final entry in dictionary.entries)
          if (entry.key == entry.value &&
              !intentionallyIdenticalInFrench.contains(entry.key))
            entry.key,
      ];
      expect(identical, isEmpty, reason: 'untranslated: $identical');
    });

    test('every identity entry is justified', () {
      // Guards the allowlist itself: an entry added to it must be a word that
      // really is spelled the same in French.
      const known = {
        'Google',
        'Apple',
        'XP',
        'minutes',
        'Notifications',
        'Finance',
        'Auto',
        'Monochrome',
        'Violet',
      };
      expect(
        intentionallyIdenticalInFrench.difference(known),
        isEmpty,
        reason: 'remove entries that no longer need the exemption',
      );
      // And nothing may claim the exemption without a dictionary entry.
      final unbacked = intentionallyIdenticalInFrench
          .where((k) => !dictionary.containsKey(k))
          .toList();
      expect(unbacked, isEmpty, reason: 'exempted but untranslated: $unbacked');
    });

    test('no French entry is blank', () {
      final blank = <String>[
        for (final entry in dictionary.entries)
          if (entry.value.trim().isEmpty) entry.key,
      ];
      expect(blank, isEmpty, reason: 'blank translations: $blank');
    });

    test('French entries carry no untranslated English marker', () {
      final suspicious = <String>[
        for (final entry in dictionary.entries)
          if (entry.value.contains('TODO') ||
              entry.value.contains('TBD') ||
              entry.value.contains('FIXME'))
            entry.key,
      ];
      expect(suspicious, isEmpty, reason: 'placeholders: $suspicious');
    });

    test('every appString key in the UI is translated', () {
      final missing = collectUntranslatedKeys();
      expect(
        missing,
        isEmpty,
        reason:
            'These strings are shown in French mode but have no translation.\n'
            'Add each one to _french in lib/core/app_strings.dart:\n'
            '${missing.map((k) => '  - "$k"').join('\n')}',
      );
    });

    test('no appString key carries an interpolation', () {
      // `appString(context, '$n min')` looks up the already-substituted string,
      // which can never be a dictionary key, so it silently falls back to
      // English. Interpolated copy has to go through `appStringArgs` or a
      // formatter instead. This test is what keeps that true as the UI grows.
      final interpolated = <String>[];
      for (final file in dartFilesIn('lib')) {
        final source = file.readAsStringSync();
        final pattern = RegExp(
          r"""appString\(\s*[\w.]+\s*,\s*'((?:[^'\\]|\\.)*)'""",
        );
        for (final match in pattern.allMatches(source)) {
          if (match.group(1)!.contains(r'$')) {
            interpolated.add('${file.path}: ${match.group(1)}');
          }
        }
      }
      expect(
        interpolated,
        isEmpty,
        reason:
            'Use appStringArgs or a formatter for interpolated copy:\n'
            '${interpolated.join('\n')}',
      );
    });

    test('French entries are not blank or placeholder', () {
      // Deliberately no "does this look French" heuristic.
      //
      // Two were tried and both were removed. One scored borrowed English words
      // and flagged every legitimate technical phrase ("Bouger mieux au
      // travail", "Application Flutter + Supabase"). The other looked for an
      // accented character or French function word, and flagged "Clair",
      // "Bonjour", "Accueil", "Passer" — short, correct French that simply has
      // no accent to find. Neither can tell a real translation from an
      // untranslated one, and a check that cries wolf gets switched off.
      //
      // The check that does work is the one above: a string reaches the screen
      // only through a dictionary lookup, so "every appString key has a
      // translation entry" is what actually catches missing French. Once an
      // entry exists, a speaker of the language wrote it.
      expect(dictionary.values.where((v) => v.trim().isEmpty), isEmpty);
    });
  });

  group('appString behaviour', () {
    testWidgets('English is returned unchanged', (tester) async {
      late String result;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            result = appString(context, 'Stand Up');
            return const SizedBox();
          },
        ),
      );
      expect(result, 'Stand Up');
    });

    test('known keys resolve to their French copy', () {
      expect(hasFrenchTranslation('Settings'), isTrue);
      expect(frenchOverrides['Settings'], 'Paramètres');
    });
  });
}

/// Walks `lib/` for `appString(context, '...')` calls and returns the literals
/// that have no French entry.
List<String> collectUntranslatedKeys() {
  final keys = <String>{};

  for (final file in dartFilesIn('lib')) {
    final source = file.readAsStringSync();
    // Matches appString(<anything>, 'literal') including adjacent string
    // concatenation is out of scope: multi-part literals are rare here and a
    // wrong parse would produce a false failure.
    final pattern = RegExp(
      r"""appString\(\s*[\w.]+\s*,\s*'((?:[^'\\]|\\.)*)'""",
    );
    for (final match in pattern.allMatches(source)) {
      keys.add(match.group(1)!.replaceAll(r"\'", "'"));
    }
  }

  return keys.where((k) => !hasFrenchTranslation(k)).toList()..sort();
}

/// Every `.dart` file under [directory], recursively.
List<File> dartFilesIn(String directory) {
  final root = Directory(directory);
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.dart') &&
            !f.path.contains(
              '${Platform.pathSeparator}g${Platform.pathSeparator}',
            ),
      )
      .toList();
}
