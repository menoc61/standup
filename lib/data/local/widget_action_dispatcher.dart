import 'package:flutter/widgets.dart';
import 'package:standup_app/data/local/app_database.dart';
import 'package:standup_app/data/local/local_repository.dart';
import 'package:standup_app/data/local/widget_snapshot.dart';
import 'package:standup_app/data/remote/supabase_service.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/audio_service.dart';
import 'package:standup_app/services/notification_service.dart';

/// Entry point for widget actions that arrive while the app is not running.
///
/// Android starts a headless Flutter engine for this and iOS reaches it through
/// the same plugin, so the function must stay top-level, must keep its name, and
/// must be annotated so the VM can resolve it from a raw callback handle. Moving
/// it or renaming it silently breaks launcher taps at runtime, with no compiler
/// error.
///
/// A background isolate starts with nothing but this closure, so the whole app
/// is brought up here: the database, the services, and then the action. That is
/// why this is deliberately heavier than a notification action — the trade is
/// paid only when a user actually taps the widget.
@pragma('vm:entry-point')
Future<void> widgetActionDispatcher(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();

  final action = uri?.host;
  if (action != 'complete') return;

  // Supabase is intentionally absent from this graph. A launcher tap has to be
  // fast and must never fail because the network did; the change is written to
  // the local database and the ordinary background sync picks it up later.
  final db = AppDatabase();
  final localRepo = LocalDatabaseRepository(db);
  final audioService = AudioService();
  final notificationService = NotificationService();

  final state = AppState(
    localRepo: localRepo,
    // Offline-only: the tap is recorded locally and synced on next launch.
    supabaseService: SupabaseService(),
    notificationService: notificationService,
    audioService: audioService,
  );

  try {
    await state.init();
    // Routed through the same method as an in-app tap, so the action window
    // and the one-per-window rule are applied identically. The durable check
    // inside `completeReminder` is what stops a cold start from double
    // counting a break that the widget already recorded.
    await state.completeReminder();
  } catch (e, stack) {
    debugPrint('Widget action failed: $e\n$stack');
  } finally {
    // Republish so the countdown and streak on the launcher reflect the change
    // even though the user never opened the app.
    await state.syncWidget();
    state.dispose();
    await db.close();
  }
}

/// Registers the headless dispatcher with the plugin.
///
/// Called once at startup. The returned future reports whether the platform
/// accepted the registration; a `false` is not fatal, it only means launcher
/// actions will be delivered to the foreground handler instead.
Future<bool> registerWidgetBackgroundAction() async {
  try {
    final accepted = await WidgetBridge.registerBackgroundCallback(
      widgetActionDispatcher,
    );
    return accepted ?? false;
  } catch (e) {
    debugPrint('Unable to register widget background action: $e');
    return false;
  }
}
