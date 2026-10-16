import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:standup_app/services/autostart_service.dart';

/// Autostart is the one reminder control that lives outside the app, and the
/// one whose state the user can change without telling us. These tests pin the
/// two things that matter: the exact session entry each platform gets, and the
/// rule that the answer comes from the OS rather than from the tap.
void main() {
  group('support', () {
    test('the unsupported service is inert', () async {
      const service = UnsupportedAutostartService();
      expect(service.isSupported, isFalse);
      expect(await service.isEnabled(), isFalse);
      expect(await service.setEnabled(true), isFalse);
      expect(await service.setEnabled(false), isFalse);
    });

    test('only the two desktop targets claim support', () {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          expect(
            PlatformAutostartService.platformSupported,
            isTrue,
            reason: '$platform',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }

      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          expect(
            PlatformAutostartService.platformSupported,
            isFalse,
            reason: '$platform',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
    });
  });

  group('Linux autostart entry', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('standup_auto');
      // Held for the whole test: the service answers "unsupported" the instant
      // the override is cleared, which would silently turn every read-back into
      // a false and hide a real regression.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      temp.deleteSync(recursive: true);
    });

    PlatformAutostartService serviceWith({required Map<String, String> env}) {
      return PlatformAutostartService(
        executablePath: '/opt/standup/standup_app',
        environment: env,
      );
    }

    test('nothing is registered to begin with', () async {
      final service = serviceWith(env: {'XDG_CONFIG_HOME': temp.path});
      expect(await service.isEnabled(), isFalse);
    });

    test('enabling writes the freedesktop entry and reads back true', () async {
      final service = serviceWith(env: {'XDG_CONFIG_HOME': temp.path});
      expect(await service.setEnabled(true), isTrue);

      final file = File(
        p.join(
          temp.path,
          'autostart',
          PlatformAutostartService.desktopFileName,
        ),
      );
      expect(file.existsSync(), isTrue);
      final contents = file.readAsStringSync();
      expect(contents, contains('[Desktop Entry]'));
      expect(contents, contains('Type=Application'));
      expect(contents, contains('Exec="/opt/standup/standup_app"'));
      expect(contents, contains('X-GNOME-Autostart-enabled=true'));
      expect(await service.isEnabled(), isTrue);
    });

    test('disabling removes the entry and is repeatable', () async {
      final service = serviceWith(env: {'XDG_CONFIG_HOME': temp.path});
      await service.setEnabled(true);
      expect(await service.setEnabled(false), isFalse);

      final file = File(
        p.join(
          temp.path,
          'autostart',
          PlatformAutostartService.desktopFileName,
        ),
      );
      expect(file.existsSync(), isFalse);
      // A second disable must not throw on a file that is already gone.
      expect(await service.setEnabled(false), isFalse);
    });

    test('an unset or blank XDG_CONFIG_HOME falls back to ~/.config', () async {
      final blank = serviceWith(
        env: {'XDG_CONFIG_HOME': '   ', 'HOME': temp.path},
      );
      expect(
        blank.desktopEntryPath,
        p.join(temp.path, '.config', 'autostart', 'standup.desktop'),
      );

      final unset = serviceWith(env: {'HOME': temp.path});
      expect(
        unset.desktopEntryPath,
        p.join(temp.path, '.config', 'autostart', 'standup.desktop'),
      );
    });

    test('an entry pointing at another binary does not read as ours', () async {
      // The leftover from a debug build: the session would launch a path that
      // no longer exists, so "enabled" would be a lie the user cannot see.
      final autostartDir = Directory(p.join(temp.path, 'autostart'))
        ..createSync(recursive: true);
      File(p.join(autostartDir.path, PlatformAutostartService.desktopFileName))
          .writeAsStringSync(
            '[Desktop Entry]\nType=Application\nExec="/home/dev/build/app"\n',
          );

      final service = serviceWith(env: {'XDG_CONFIG_HOME': temp.path});
      expect(await service.isEnabled(), isFalse);

      // Switching it on rewrites the entry to point at the running binary.
      expect(await service.setEnabled(true), isTrue);
      final rewritten = File(
        p.join(autostartDir.path, PlatformAutostartService.desktopFileName),
      ).readAsStringSync();
      expect(rewritten, contains('Exec="/opt/standup/standup_app"'));
    });
  });

  group('Windows autostart entry', () {
    test('enabling writes the quoted path to the per-user Run key', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final commands = <List<String>>[];
        final registered = <String>{};

        Future<ProcessResult> runner(String exe, List<String> args) async {
          commands.add([exe, ...args]);
          switch (args.first) {
            case 'query':
              return ProcessResult(
                0,
                registered.contains(args.last) ? 0 : 1,
                '',
                '',
              );
            case 'add':
              registered.add(args[args.indexOf('/v') + 1]);
              return ProcessResult(0, 0, '', '');
            case 'delete':
              registered.remove(args[args.indexOf('/v') + 1]);
              return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 1, '', '');
        }

        final service = PlatformAutostartService(
          executablePath: r'C:\Program Files\StandUp\standup_app.exe',
          run: runner,
        );

        expect(await service.isEnabled(), isFalse);
        expect(await service.setEnabled(true), isTrue);
        expect(await service.setEnabled(false), isFalse);

        final add = commands.firstWhere((c) => c[1] == 'add');
        expect(add[0], 'reg');
        expect(add, contains(PlatformAutostartService.windowsRunKey));
        expect(add, contains(PlatformAutostartService.windowsValueName));
        expect(add, contains('REG_SZ'));
        // Quoted, because the Run value is a command line and this path has a
        // space in it.
        expect(add, contains(r'"C:\Program Files\StandUp\standup_app.exe"'));
        expect(add, contains('/f'));

        expect(
          commands.where((c) => c[1] == 'delete'),
          isNotEmpty,
          reason: 'disabling removes the value rather than blanking it',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('a missing value reads as disabled rather than throwing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final service = PlatformAutostartService(
          executablePath: 'C:/standup/app.exe',
          run: (exe, args) async => ProcessResult(0, 1, '', 'value not found'),
        );
        expect(await service.isEnabled(), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('a failing registry command leaves the switch on the truth', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final service = PlatformAutostartService(
          executablePath: 'C:/standup/app.exe',
          run: (exe, args) async {
            if (args.first == 'add') {
              throw ProcessException(exe, args, 'denied');
            }
            // The value was never written.
            return ProcessResult(0, 1, '', '');
          },
        );
        // No exception escapes, and the reported state is the OS state.
        expect(await service.setEnabled(true), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
