import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:standup_app/data/local/widget_palette.dart';
import 'package:standup_app/data/models/gamification_metrics.dart';
import 'package:standup_app/data/models/stand_window.dart';

/// The snapshot of state a home-screen widget needs.
///
/// A home-screen widget cannot run Dart: the launcher process reads it, so the
/// app has to publish a plain key/value payload the native side can render on
/// its own. This class owns that payload and keeps it in one place so the four
/// widgets cannot drift apart.
///
/// ## Privacy
///
/// Everything here is the user's own data — their own countdown, streak, XP and
/// goal. No device identifier, no location, no network address and no employer
/// visible figure is ever written to the widget store. Team standing was
/// deliberately left out of this payload; if it is added later it must stay
/// anonymised and opt-in, exactly as the in-app dashboards are.
///
/// ## Accuracy
///
/// The countdown is published as an absolute timestamp plus the window length,
/// never as a pre-computed string. The widget computes the remaining time
/// itself from the device clock, so the number stays correct between updates and
/// does not go stale while the launcher sits idle.
class WidgetSnapshot {
  /// Absolute instant the current actionable window closes (ISO-8601, UTC).
  final String? windowEndsAtIso;

  /// Absolute instant the next window opens, when none is open right now.
  final String? windowOpensAtIso;

  /// Whether the action window is open at the moment of publication.
  final bool windowOpen;

  /// Length of the actionable window in minutes.
  final int windowMinutes;

  /// Cadence in minutes.
  final int cadenceMinutes;

  /// Current streak in days.
  final int streak;

  /// Total XP earned.
  final int totalXp;

  /// Current level.
  final int level;

  /// Completed breaks today.
  final int todayCompleted;

  /// Daily stand goal.
  final int dailyGoal;

  /// Whether today's goal has been met.
  final bool goalMet;

  /// True when the device clock was flagged, so the widget should not present
  /// the figures as authoritative.
  final bool clockSuspect;

  /// Resolved colours for the widget, as 8-digit `AARRGGBB` hex.
  ///
  /// The palette travels from Dart rather than being duplicated in the Kotlin and
  /// Swift providers. That is deliberate: the accent is a user choice, and three
  /// hand-maintained copies of the colour table would drift the moment someone
  /// added an option. The native side applies whatever arrives, so "the widget
  /// follows the user's colour" is true by construction rather than by
  /// remembering to update three files.
  ///
  /// Values are opaque, so they are `FF` + RRGGBB.
  final WidgetPaletteHex palette;

  const WidgetSnapshot({
    this.windowEndsAtIso,
    this.windowOpensAtIso,
    this.windowOpen = false,
    this.windowMinutes = 5,
    this.cadenceMinutes = 60,
    this.streak = 0,
    this.totalXp = 0,
    this.level = 1,
    this.todayCompleted = 0,
    this.dailyGoal = 8,
    this.goalMet = false,
    this.clockSuspect = false,
    this.palette = const WidgetPaletteHex(),
  });

  /// Builds the snapshot from live app state.
  factory WidgetSnapshot.fromState({
    DateTime? now,
    required int streak,
    required int totalXp,
    required int todayCompleted,
    required int dailyGoal,
    required bool windowOpen,
    required int windowMinutes,
    required int cadenceMinutes,
    required bool clockSuspect,
    String colorSystem = 'brand',
  }) {
    final resolved = now ?? DateTime.now();
    final active = StandWindow.activeWindow(
      now: resolved,
      actionWindowMinutes: windowMinutes,
      cadenceMinutes: cadenceMinutes,
    );
    final upcoming = StandWindow.nextWindow(
      now: resolved,
      actionWindowMinutes: windowMinutes,
      cadenceMinutes: cadenceMinutes,
    );

    return WidgetSnapshot(
      windowEndsAtIso: active?.end.toUtc().toIso8601String(),
      windowOpensAtIso: (active == null ? upcoming?.start : null)
          ?.toUtc()
          .toIso8601String(),
      windowOpen: active != null,
      windowMinutes: windowMinutes,
      cadenceMinutes: cadenceMinutes,
      streak: streak,
      totalXp: totalXp,
      level: GamificationMetrics.levelFor(totalXp),
      todayCompleted: todayCompleted,
      dailyGoal: dailyGoal,
      goalMet: dailyGoal > 0 && todayCompleted >= dailyGoal,
      clockSuspect: clockSuspect,
      palette: WidgetPaletteHex.forAccent(colorSystem),
    );
  }

  Map<String, dynamic> toMap({DateTime? now}) => {
    'window_ends_at': windowEndsAtIso,
    'window_opens_at': windowOpensAtIso,
    'window_open': windowOpen,
    'window_minutes': windowMinutes,
    'cadence_minutes': cadenceMinutes,
    'streak': streak,
    'total_xp': totalXp,
    'level': level,
    'today_completed': todayCompleted,
    'daily_goal': dailyGoal,
    'goal_met': goalMet,
    'clock_suspect': clockSuspect,
    'c_surface': palette.surface,
    'c_on_surface': palette.onSurface,
    'c_muted': palette.muted,
    'c_accent': palette.accent,
    'c_on_accent': palette.onAccent,
    'c_streak': palette.streak,
    'c_surface_2': palette.surfaceAlt,
    'published_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
  };

  factory WidgetSnapshot.fromMap(Map<String, dynamic> map) {
    return WidgetSnapshot(
      windowEndsAtIso: map['window_ends_at'] as String?,
      windowOpensAtIso: map['window_opens_at'] as String?,
      windowOpen: map['window_open'] as bool? ?? false,
      windowMinutes: (map['window_minutes'] as num?)?.toInt() ?? 5,
      cadenceMinutes: (map['cadence_minutes'] as num?)?.toInt() ?? 60,
      streak: (map['streak'] as num?)?.toInt() ?? 0,
      totalXp: (map['total_xp'] as num?)?.toInt() ?? 0,
      level: (map['level'] as num?)?.toInt() ?? 1,
      todayCompleted: (map['today_completed'] as num?)?.toInt() ?? 0,
      dailyGoal: (map['daily_goal'] as num?)?.toInt() ?? 8,
      goalMet: map['goal_met'] as bool? ?? false,
      clockSuspect: map['clock_suspect'] as bool? ?? false,
      palette: WidgetPaletteHex(
        surface: map['c_surface'] as String?,
        onSurface: map['c_on_surface'] as String?,
        muted: map['c_muted'] as String?,
        accent: map['c_accent'] as String?,
        onAccent: map['c_on_accent'] as String?,
        streak: map['c_streak'] as String?,
        surfaceAlt: map['c_surface_2'] as String?,
      ),
    );
  }

  /// Convenience for callers holding a snapshot rather than a raw map.
  static Map<String, dynamic> buildPayload(WidgetSnapshot snapshot) =>
      snapshot.toMap();
}

/// Publishes snapshots and routes taps back into the app.
///
/// The publish calls are deliberately wrapped: a widget that fails to update is
/// a cosmetic problem, and it must never take down the reminder loop that the
/// app exists to perform.
class WidgetBridge {
  WidgetBridge._();

  /// `home_widget` resolves a bare name against the application id, but this
  /// provider lives in the `.widget` sub-package, so the qualified name is
  /// required for `updateWidget` to find it.
  static const _qualifiedProviderAndroid =
      'com.healthwellness.standup_app.widget.StandUpWidgetProvider';
  static const _providerIOS = 'CSPHStandUpWidget';

  static const String keySnapshot = 'snapshot';

  /// Route used by the widget's action button, on both platforms.
  static const String uriComplete = 'csphwidget://complete';

  /// Route used when the widget body is tapped, to open the app.
  static const String uriOpen = 'csphwidget://open';

  /// App Group shared with the WidgetKit extension.
  ///
  /// This is the iOS counterpart of the Android SharedPreferences file both
  /// sides read: the app writes, the extension renders. It must match the
  /// entitlement in `ios/Runner/Runner.entitlements` and
  /// `ios/StandUpWidget/StandUpWidget.entitlements`.
  static const String appGroupId = 'group.com.healthwellness.standupApp';

  /// Key the iOS widget writes a pending action into.
  static const String pendingActionKey = 'home_widget_pending_action';

  static bool _appGroupReady = false;

  /// Tells the plugin which App Group to use. Required on iOS before any read or
  /// write; a no-op elsewhere, so it is safe to call unconditionally.
  static Future<void> _ensureAppGroup() async {
    if (_appGroupReady) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      _appGroupReady = true;
    } catch (e) {
      debugPrintSafe('Unable to set widget App Group: $e');
    }
  }

  /// Publishes the current snapshot to every registered widget.
  static Future<void> publish(Map<String, dynamic> payload) async {
    try {
      await _ensureAppGroup();
      await HomeWidget.saveWidgetData<String>(keySnapshot, _encode(payload));
      await HomeWidget.updateWidget(
        qualifiedAndroidName: _qualifiedProviderAndroid,
        iOSName: _providerIOS,
      );
    } catch (e) {
      // Intentionally swallowed and logged: see the class doc comment.
      debugPrintSafe('Unable to publish widget snapshot: $e');
    }
  }

  /// Reads the last published snapshot, if any.
  static Future<WidgetSnapshot?> read() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>(keySnapshot);
      if (raw == null || raw.isEmpty) return null;
      final decoded = _decode(raw);
      if (decoded == null) return null;
      return WidgetSnapshot.fromMap(decoded);
    } catch (e) {
      debugPrintSafe('Unable to read widget snapshot: $e');
      return null;
    }
  }

  /// Registers the handler for taps that arrive while the app is running.
  ///
  /// Taps that arrive with the app closed are routed to
  /// [registerBackgroundCallback] instead, because this listener belongs to the
  /// foreground isolate only.
  static void registerActionHandler(
    Future<void> Function(String action) handler,
  ) {
    HomeWidget.widgetClicked.listen((uri) {
      final action = _actionFrom(uri);
      if (action == null) return;
      handler(action);
    });
  }

  /// Registers the headless handler that runs when the app is not running.
  ///
  /// Android launches a background Flutter engine for this; iOS reaches it
  /// through the same plugin. The callback must be a top-level function so the
  /// engine can resolve it from a raw handle.
  static Future<bool?> registerBackgroundCallback(
    FutureOr<void> Function(Uri?) callback,
  ) {
    return HomeWidget.registerInteractivityCallback(callback);
  }

  /// Maps a widget URI onto an action name, or null when it is not ours.
  static String? _actionFrom(Uri? uri) {
    if (uri == null) return null;
    if (uri.host == 'complete') return 'complete';
    if (uri.host == 'open') return 'open';
    return null;
  }

  /// Consumes a pending action left behind by the iOS widget button.
  ///
  /// An iOS App Intent cannot start a Dart isolate, so the extension records the
  /// tap in the shared App Group instead and the app applies it on its next
  /// resume. Reading and clearing in one step is what keeps a single tap from
  /// being counted twice, which matters because this runs on every resume.
  static Future<String?> takePendingAction() async {
    try {
      await _ensureAppGroup();
      final raw = await HomeWidget.getWidgetData<String>(pendingActionKey);
      if (raw == null || raw.isEmpty) return null;
      await HomeWidget.saveWidgetData<String>(pendingActionKey, '');
      return raw == 'logStandUp' ? 'complete' : null;
    } catch (e) {
      debugPrintSafe('Unable to drain pending widget action: $e');
      return null;
    }
  }

  /// Android needs an explicit request for the widget to be re-rendered.
  static Future<void> requestAndroidRefresh() {
    return publish(<String, dynamic>{});
  }

  static String _encode(Map<String, dynamic> map) {
    // A tiny pipe-delimited encoding avoids pulling in a JSON encoder purely
    // for the widget channel, which is the hot path when a break is logged.
    final buffer = StringBuffer();
    map.forEach((key, value) {
      if (value == null) return;
      buffer
        ..write(key)
        ..write('=')
        ..write(value is bool ? (value ? '1' : '0') : value.toString())
        ..write(';');
    });
    return buffer.toString();
  }

  static Map<String, dynamic>? _decode(String raw) {
    final result = <String, dynamic>{};
    for (final pair in raw.split(';')) {
      if (pair.isEmpty) continue;
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      final key = pair.substring(0, index);
      final value = pair.substring(index + 1);
      result[key] =
          int.tryParse(value) ??
          (value == '1' || value == '0' ? value == '1' : value);
    }
    return result;
  }
}

void debugPrintSafe(String message) {
  // Kept as a function so the widget layer has a single, easily-swappable
  // logging seam without importing Flutter's foundation into a path that the
  // native side also touches.
  assert(() {
    // ignore: avoid_print
    print('[WidgetBridge] $message');
    return true;
  }());
}
