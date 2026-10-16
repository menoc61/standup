import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:path/path.dart' as p;

/// Port for the operating system's "start with the session" registration.
///
/// Every other part of the reminder loop assumes the app is running. On desktop
/// nothing happens when it is not: Linux reminders are foreground timers and
/// Windows reminders are a queue of toasts that stops being refilled, so a
/// reboot the user never follows with a launch is a day without reminders. This
/// is the one piece of the desktop story that lives outside the app, and it is
/// what makes "it works while you work" true rather than aspirational.
///
/// The session entry is the state of record, never a local flag: the user can
/// remove it from their desktop settings at any moment, and a checkbox that
/// remembered its own last value would then be lying.
abstract interface class AutostartService {
  /// Whether this platform has an implementation at all.
  bool get isSupported;

  /// Reads the current registration from the operating system.
  Future<bool> isEnabled();

  /// Registers ([enabled] true) or unregisters the app.
  ///
  /// Best effort by design: a refusal is reported as the state the OS is
  /// actually in, never as an exception. A user who cannot be registered gets a
  /// switch that snaps back rather than a crash in Settings.
  Future<bool> setEnabled(bool enabled);
}

/// The autostart used wherever the app cannot touch the session.
class UnsupportedAutostartService implements AutostartService {
  const UnsupportedAutostartService();

  @override
  bool get isSupported => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<bool> setEnabled(bool enabled) async => false;
}

/// Runs a command and returns its result.
///
/// Injectable so the Windows branch — a registry edit made through `reg.exe` —
/// can be exercised on any host without touching a real registry.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Registers the app with the two desktop sessions the project targets.
///
/// * **Windows** — a `REG_SZ` value under
///   `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, written through
///   `reg.exe`. No native code and no new dependency; the same entry the user
///   would see in Task Manager's startup tab.
/// * **Linux** — a `standup.desktop` file in
///   `${XDG_CONFIG_HOME:-$HOME/.config}/autostart`, the freedesktop session
///   convention every desktop environment reads.
///
/// macOS is absent on purpose: the release pipeline has never produced a macOS
/// build, so a registration path nobody can test would be worse than the honest
/// "not supported" the UI shows.
class PlatformAutostartService implements AutostartService {
  /// The registry key Windows reads at sign-in.
  static const String windowsRunKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  /// The value name, which is what shows in Task Manager's startup list.
  static const String windowsValueName = 'StandUp';

  /// The desktop entry file name.
  static const String desktopFileName = 'standup.desktop';

  /// The absolute path of the executable that should be launched.
  final String executablePath;

  /// The environment the session paths are resolved from.
  final Map<String, String> environment;

  final ProcessRunner _run;

  PlatformAutostartService({
    String? executablePath,
    Map<String, String>? environment,
    ProcessRunner? run,
  }) : executablePath = executablePath ?? Platform.resolvedExecutable,
       environment = environment ?? Platform.environment,
       _run = run ?? _runProcess;

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments,
  ) => Process.run(executable, arguments, runInShell: false);

  /// Whether a desktop session can be registered with.
  ///
  /// Named apart from the instance getter because the interface already claims
  /// `isSupported`; this is the same answer available without an instance, which
  /// is what a build-time or UI check wants.
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  bool get isSupported => PlatformAutostartService.platformSupported;

  @override
  Future<bool> isEnabled() async {
    if (!isSupported) return false;
    try {
      return defaultTargetPlatform == TargetPlatform.windows
          ? await _windowsIsEnabled()
          : await _linuxIsEnabled();
    } catch (_) {
      // An unreadable session file or a missing `reg.exe` is "not registered"
      // as far as the UI is concerned, which is the safe answer: it invites the
      // user to switch it on rather than claiming a registration that is not
      // there.
      return false;
    }
  }

  @override
  Future<bool> setEnabled(bool enabled) async {
    if (!isSupported) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await _windowsSet(enabled);
      } else {
        await _linuxSet(enabled);
      }
    } catch (_) {
      // Fall through to the read-back, which reports the truth either way.
    }
    // Never report the request as done: report what the session now says.
    return isEnabled();
  }

  // ── Windows ────────────────────────────────────────────────────────────────

  Future<bool> _windowsIsEnabled() async {
    final result = await _run('reg', [
      'query',
      windowsRunKey,
      '/v',
      windowsValueName,
    ]);
    return result.exitCode == 0;
  }

  Future<void> _windowsSet(bool enabled) async {
    if (enabled) {
      await _run('reg', [
        'add',
        windowsRunKey,
        '/v',
        windowsValueName,
        '/t',
        'REG_SZ',
        '/d',
        // The path is quoted because `Run` entries are command lines: an
        // install under "C:\Program Files\…" would otherwise be split on its
        // first space and never start.
        '"$executablePath"',
        '/f',
      ]);
    } else {
      await _run('reg', [
        'delete',
        windowsRunKey,
        '/v',
        windowsValueName,
        '/f',
      ]);
    }
  }

  // ── Linux ──────────────────────────────────────────────────────────────────

  /// The autostart file the desktop environment will read.
  ///
  /// `XDG_CONFIG_HOME` wins when it is set and non-empty, which is what the
  /// freedesktop spec requires; the manual says so, and a user who moved it
  /// would otherwise get an entry their session never looks at.
  String get desktopEntryPath {
    final configured = environment['XDG_CONFIG_HOME']?.trim();
    final configHome = (configured != null && configured.isNotEmpty)
        ? configured
        : p.join(environment['HOME'] ?? '', '.config');
    return p.join(configHome, 'autostart', desktopFileName);
  }

  /// The file body, exactly as it is written.
  String get desktopEntryContents =>
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=StandUp\n'
      'Comment=Stand-up and stretch reminders\n'
      'Exec="$executablePath"\n'
      'Terminal=false\n'
      'X-GNOME-Autostart-enabled=true\n';

  Future<bool> _linuxIsEnabled() async {
    final file = File(desktopEntryPath);
    if (!file.existsSync()) return false;
    // A leftover entry from an older build can point at a path that no longer
    // exists. Reporting "enabled" for it would leave the user with a session
    // that silently launches nothing, so the entry has to name *this* binary.
    return _entryLaunches(file.readAsStringSync());
  }

  /// Whether [contents] is a desktop entry that launches [executablePath].
  bool _entryLaunches(String contents) {
    for (final rawLine in contents.split('\n')) {
      final line = rawLine.trim();
      if (!line.startsWith('Exec=')) continue;
      var value = line.substring('Exec='.length).trim();
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      return value == executablePath;
    }
    return false;
  }

  Future<void> _linuxSet(bool enabled) async {
    final file = File(desktopEntryPath);
    if (!enabled) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(desktopEntryContents, flush: true);
  }
}
