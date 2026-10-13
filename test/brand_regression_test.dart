import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Locks the CSPH to CNPS rename in place.
///
/// The rename was originally applied to references but not to the files they
/// point at, which broke the Android and iOS builds while `flutter analyze`
/// and the Dart suite stayed green. These tests fail on that whole class of
/// defect: a reference naming a file that does not exist, or the retired
/// brand resurfacing in a source tree.

/// Directories that hold generated output rather than authored source.
///
/// A build directory legitimately keeps stale copies of a previous brand, so
/// scanning it would fail for the wrong reason and prove nothing.
const _generated = ['.git', 'build', '.dart_tool', 'Pods', '.idea'];

/// Source extensions worth scanning for the retired brand.
const _scannable = [
  '.dart',
  '.kt',
  '.swift',
  '.xml',
  '.plist',
  '.pbxproj',
  '.rb',
  '.py',
  '.ps1',
  '.sh',
  '.yml',
  '.yaml',
  '.json',
  '.html',
  '.css',
  '.md',
  '.sql',
  '.rc',
  '.desktop',
  '.cc',
  '.h',
  '.cpp',
  '.iss',
];

bool _isGenerated(String path) {
  final p = path.replaceAll(r'\', '/');
  return p.split('/').any(_generated.contains);
}

/// Deliberate, narrow exceptions to the brand scan.
///
/// Each entry is a historical reference a user has to be able to act on, not a
/// live branding surface. Anything added here has to justify itself: the guard
/// is only useful if it stays strict, so a new entry means re-examining whether
/// the mention is actually load-bearing.
const _allowedMentions = <String, String>{
  // Lists the retired brand as a token to *forbid*, so that a half-applied
  // rename of the bundle id is caught. The mention is the point.
  'test/identity_test.dart':
      'declares the retired brand as a forbidden token for identity_test.dart',
};

/// Every authored source file under the repository root.
List<File> sourceFilesIn(String directory) {
  final root = Directory(directory);
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => !_isGenerated(f.path))
      .where((f) => _scannable.contains(_extensionOf(f.path)))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _extensionOf(String path) {
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  return dot == -1 ? '' : name.substring(dot).toLowerCase();
}

/// The repo root. `flutter test` runs with the package directory as cwd.
String get repoRoot => Directory.current.path;

void main() {
  group('Brand rename', () {
    test('no authored source still mentions the retired brand', () {
      final offenders = <String>[];
      for (final file in sourceFilesIn(repoRoot)) {
        // The guard's own name and these literals must not trip the scan.
        if (file.path.endsWith('brand_regression_test.dart')) continue;
        final relative = file.path
            .substring(repoRoot.length)
            .replaceAll(r'\', '/')
            .replaceFirst(RegExp('^/'), '');
        if (_allowedMentions.containsKey(relative)) continue;

        final contents = file.readAsStringSync();
        if (RegExp('csph', caseSensitive: false).hasMatch(contents)) {
          offenders.add(relative);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'The retired brand is back in:\n${offenders.join('\n')}\n'
            'A rebrand that changes references but not the files they point at '
            'builds green and ships broken, which is how this one got here.\n'
            'If a mention is genuinely load-bearing, add it to '
            '_allowedMentions with a reason.',
      );
    });

    test(
      'no authored source file still carries the retired brand in its name',
      () {
        final offenders = <String>[];
        for (final file in sourceFilesIn(repoRoot)) {
          final relative = file.path
              .substring(repoRoot.length)
              .replaceAll(r'\', '/')
              .replaceFirst(RegExp('^/'), '');
          if (RegExp('csph', caseSensitive: false).hasMatch(relative)) {
            offenders.add(relative);
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'These files are still named after the retired brand, so the '
              'references pointing at them cannot resolve:\n'
              '${offenders.join('\n')}',
        );
      },
    );
  });

  group('Renamed files exist where the references point', () {
    test('the Android widget layout is present under its referenced name', () {
      // StandUpWidgetProvider.kt reads R.layout.cnps_standup_widget. The name
      // is lowercase because the Gradle resource merger rejects uppercase in
      // file-based resource names, and aapt2 compile does NOT catch that —
      // only the merge step does. See the build failure this guards.
      expect(
        File(
          '$repoPath${Platform.pathSeparator}android${Platform.pathSeparator}'
          'app${Platform.pathSeparator}src${Platform.pathSeparator}main'
          '${Platform.pathSeparator}res${Platform.pathSeparator}layout'
          '${Platform.pathSeparator}cnps_standup_widget.xml',
        ).existsSync(),
        isTrue,
      );
    });

    test('no Android resource file name uses an uppercase character', () {
      // Resource merger rule: file-based names are [a-z0-9_] only. This is
      // invisible to the Dart suite, so it has to be asserted here.
      final resRoot = Directory(
        '$repoPath${Platform.pathSeparator}android${Platform.pathSeparator}'
        'app${Platform.pathSeparator}src${Platform.pathSeparator}main'
        '${Platform.pathSeparator}res',
      );
      expect(resRoot.existsSync(), isTrue);

      final bad =
          resRoot
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (f) =>
                    RegExp('[A-Z]')
                        .hasMatch(f.path.split(RegExp(r'[/\\]')).last),
              )
              .map((f) => f.path.split(RegExp(r'[/\\]')).last)
              .toList()
            ..sort();

      expect(
        bad,
        isEmpty,
        reason:
            'Android rejects uppercase in file-based resource names. These '
            'would fail `packageReleaseResources`: $bad',
      );
    });

    test('the Android widget provider config is present under its name', () {
      // AndroidManifest.xml points android:resource at this.
      expect(
        File(
          '$repoPath${Platform.pathSeparator}android${Platform.pathSeparator}'
          'app${Platform.pathSeparator}src${Platform.pathSeparator}main'
          '${Platform.pathSeparator}res${Platform.pathSeparator}xml'
          '${Platform.pathSeparator}cnps_standup_widget_info.xml',
        ).existsSync(),
        isTrue,
      );
    });

    test('the iOS widget entry point is present under its referenced name', () {
      // scripts/ios/add_widget_target.rb adds exactly this file to the
      // WidgetKit target, and release.yml loops over the same name.
      final swift = File(
        '$repoPath${Platform.pathSeparator}ios${Platform.pathSeparator}'
        'StandUpWidget${Platform.pathSeparator}CNPSStandUpWidget.swift',
      );
      expect(swift.existsSync(), isTrue);
      // The struct name must match WidgetBridge._providerIOS, which the Dart
      // side uses to address the WidgetKit bundle.
      expect(swift.readAsStringSync(), contains('struct CNPSStandUpWidget'));
    });

    test('the Dart side names the same WidgetKit bundle as Swift does', () {
      final bridge = File(
        '$repoPath${Platform.pathSeparator}lib${Platform.pathSeparator}data'
        '${Platform.pathSeparator}local${Platform.pathSeparator}'
        'widget_snapshot.dart',
      ).readAsStringSync();
      expect(bridge, contains("_providerIOS = 'CNPSStandUpWidget'"));
    });

    test('the branding asset the icon generator reads is present', () {
      // generate_icons.py resolves SOURCE from this exact filename; every
      // platform icon derives from it.
      final logo = File(
        '$repoPath${Platform.pathSeparator}assets${Platform.pathSeparator}'
        'branding${Platform.pathSeparator}CNPS_standup_logo.png',
      );
      expect(logo.existsSync(), isTrue);

      final generator = File(
        '$repoPath${Platform.pathSeparator}scripts${Platform.pathSeparator}'
        'icons${Platform.pathSeparator}generate_icons.py',
      ).readAsStringSync();
      expect(
        generator,
        contains('CNPS_standup_logo.png'),
        reason: 'The generator points at a filename that no longer exists.',
      );
    });

    test('every @string the Android widget layout reads is defined', () {
      // Renaming the string resources without renaming the definition is the
      // same failure in a different file.
      final stringsXml = File(
        '$repoPath${Platform.pathSeparator}android${Platform.pathSeparator}'
        'app${Platform.pathSeparator}src${Platform.pathSeparator}main'
        '${Platform.pathSeparator}res${Platform.pathSeparator}values'
        '${Platform.pathSeparator}strings.xml',
      ).readAsStringSync();

      final referenced = <String>{};
      for (final relative in const [
        'res/layout/cnps_standup_widget.xml',
        'res/xml/cnps_standup_widget_info.xml',
      ]) {
        final contents = File(
          '$repoPath${Platform.pathSeparator}android${Platform.pathSeparator}'
          'app${Platform.pathSeparator}src${Platform.pathSeparator}main'
          '${Platform.pathSeparator}$relative',
        ).readAsStringSync();
        for (final m in RegExp(r'@string/(\w+)').allMatches(contents)) {
          referenced.add(m.group(1)!);
        }
      }

      expect(referenced, isNotEmpty);
      final undefined =
          referenced
              .where((name) => !stringsXml.contains('name="$name"'))
              .toList()
            ..sort();
      expect(
        undefined,
        isEmpty,
        reason:
            'The widget layout reads undefined string resources: $undefined',
      );
    });
  });

  group('Trademark claims match reality', () {
    test('the licence expands CNPS to the real institution', () {
      final licence = File('$repoPath${Platform.pathSeparator}LICENSE')
          .readAsStringSync();
      expect(
        licence,
        contains('Caisse Nationale de la Prévoyance Sociale'),
        reason:
            'A blind find-and-replace left the old expansion attached to the '
            'new acronym, which names a different organisation.',
      );
    });

    test('the licence does not claim CNPS owns the bundled artwork', () {
      // The bundled mark is project artwork, not a CNPS logo. Asserting CNPS
      // owns it would be a false claim about a real institution, and the
      // fix is only as durable as the test that checks it.
      final licence = File('$repoPath${Platform.pathSeparator}LICENSE')
          .readAsStringSync()
          .toLowerCase();
      expect(
        licence,
        isNot(contains('are covered by this\nrestriction')),
        reason:
            'The licence still implies the bundled mark is CNPS property. It '
            'is original project artwork.',
      );
      expect(licence, contains('not** an official cnps logo'));
    });

    test('the readme makes the same distinction as the licence', () {
      final readme = File('$repoPath${Platform.pathSeparator}README.md')
          .readAsStringSync()
          .toLowerCase();
      expect(readme, contains('not** an official cnps logo'));
    });
  });
}

String get repoPath => Directory.current.path;
