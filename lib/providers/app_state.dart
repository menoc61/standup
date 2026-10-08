import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import 'package:uuid/uuid.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/data/local/local_repository.dart';
import 'package:standup_app/data/local/widget_snapshot.dart';
import 'package:standup_app/data/models/daily_analytics.dart';
import 'package:standup_app/data/models/device_profile.dart';
import 'package:standup_app/data/models/gamification_metrics.dart';
import 'package:standup_app/data/models/org_analytics.dart';
import 'package:standup_app/data/models/reminder_log.dart';
import 'package:standup_app/data/models/stand_window.dart';
import 'package:standup_app/data/models/user_preferences.dart';
import 'package:standup_app/data/models/user_profile.dart';
import 'package:standup_app/data/models/workday_metrics.dart';
import 'package:standup_app/data/remote/supabase_service.dart';
import 'package:standup_app/services/audio_service.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/services/live_countdown_service.dart';
import 'package:standup_app/services/notification_service.dart';

class AppState extends ChangeNotifier {
  final LocalDatabaseRepository localRepo;
  final SupabaseService supabaseService;
  final NotificationService notificationService;
  final AudioService audioService;

  /// Persistent notification that counts down to the next break.
  ///
  /// Owned here rather than injected so there is a single place that decides
  /// whether the shade should show a countdown, which keeps the reminder,
  /// snooze and skip paths from disagreeing with each other.
  late final LiveCountdownService liveCountdownService = LiveCountdownService()
    ..accentResolver = () => AppColors.getAccentColor(preferences.colorSystem);

  UserProfile? _userProfile;
  UserPreferences? _preferences;
  DailyAnalytics _todayAnalytics = DailyAnalytics.empty('user_local', '');
  List<DailyAnalytics> _dailyHistory = [];
  OrgAnalytics? _orgAnalytics;

  DateTime? _nextReminderTime;
  DateTime? _timerStartTime;
  String? _analyticsDate;
  Timer? _ticker;
  StreamSubscription<void>? _authSubscription;
  Future<void> _accountTransition = Future<void>.value();
  Duration _remainingDuration = Duration.zero;

  int _consecutiveSkips = 0;
  bool _isBreakActive = false;
  bool _reminderAlertPlayed = false;
  int _activeBreakStep = 0;
  int _breakSecondsRemaining = 300; // 5 minutes
  Timer? _breakTimer;

  /// The window key a guided stretch was started under, so its completion is
  /// still honoured after the window's end instant has passed.
  int? _breakWindowKey;

  SyncStatus _syncStatus = SyncStatus.idle;
  String _languageCode = 'fr';
  DeviceProfile? _deviceProfile;

  // Anti-bypass bookkeeping. The monotonic stopwatch is the reference that lets
  // ordinary OS suspend/resume be told apart from deliberate clock tampering.
  final Stopwatch _uptime = Stopwatch()..start();
  final ClockIntegrityTracker _clockTracker = ClockIntegrityTracker();
  bool _disposed = false;
  String? _lastActionRejection;

  /// Windows already acted on this session, preventing double counting when a
  /// notification action and a tap race each other.
  final Set<int> _actedWindows = <int>{};

  AppState({
    required this.localRepo,
    required this.supabaseService,
    required this.notificationService,
    required this.audioService,
  });

  // Getters
  UserProfile? get userProfile => _userProfile;
  UserPreferences get preferences =>
      _preferences ?? UserPreferences.defaultPreferences('default_user');
  DailyAnalytics get todayAnalytics => _todayAnalytics;
  List<DailyAnalytics> get dailyHistory => _dailyHistory;
  OrgAnalytics? get orgAnalytics => _orgAnalytics;
  DateTime? get nextReminderTime => _nextReminderTime;
  Duration get remainingDuration => _remainingDuration;
  int get consecutiveSkips => _consecutiveSkips;
  bool get isBreakActive => _isBreakActive;
  int get activeBreakStep => _activeBreakStep;
  int get breakSecondsRemaining => _breakSecondsRemaining;
  SyncStatus get syncStatus => _syncStatus;
  String get languageCode => _languageCode;

  /// The captured device profile, or null before [captureDeviceProfile] runs.
  DeviceProfile? get deviceProfile => _deviceProfile;

  /// Captures the transparent device profile from the running app. Called from
  /// the widget layer once a real screen size and locale are available.
  void captureDeviceProfile({
    required Size screenSize,
    required double pixelRatio,
    required String locale,
  }) {
    if (_deviceProfile != null) return;
    _deviceProfile = DeviceProfile.capture(
      screenSize: screenSize,
      pixelRatio: pixelRatio,
      locale: locale,
    );
    notifyListeners();
  }

  double get timerProgress {
    if (_nextReminderTime == null || _timerStartTime == null) return 0.0;
    return ReminderClock.progress(
      now: DateTime.now(),
      startedAt: _timerStartTime!,
      dueAt: _nextReminderTime!,
    );
  }

  /// True while the local time falls inside the user's configured quiet window.
  /// Used to silence the in-app cue; OS-scheduled reminders are filtered out
  /// when the queue is built.
  bool get isInQuietHours => _inQuietHours(preferences.quietHours);

  /// Whether a stand action is currently permitted. A break counts only inside
  /// the final [_actionWindowMinutes] minutes of each cadence hour.
  bool get isActionWindowOpen => StandWindow.isActionable(
    now: DateTime.now(),
    actionWindowMinutes: _actionWindowMinutes,
    cadenceMinutes: _cadenceMinutes,
  );

  /// Time left before the current window shuts, or zero when closed.
  Duration get windowTimeRemaining => StandWindow.remainingInWindow(
    now: DateTime.now(),
    actionWindowMinutes: _actionWindowMinutes,
    cadenceMinutes: _cadenceMinutes,
  );

  /// Time until the next window opens, or zero while one is open.
  Duration get timeUntilNextWindow => StandWindow.untilNextWindow(
    now: DateTime.now(),
    actionWindowMinutes: _actionWindowMinutes,
    cadenceMinutes: _cadenceMinutes,
  );

  /// The actionable window currently open, for the UI to render.
  WindowSpan? get activeWindow => StandWindow.activeWindow(
    now: DateTime.now(),
    actionWindowMinutes: _actionWindowMinutes,
    cadenceMinutes: _cadenceMinutes,
  );

  /// The window length, clamped so a corrupt or hand-edited preference row can
  /// never make `StandWindow` throw `ArgumentError` from inside the 1 Hz
  /// ticker. Without this clamp a single bad value would produce an unhandled
  /// async error every second and freeze the visible timer at zero.
  int get _actionWindowMinutes {
    final requested = preferences.actionWindowMinutes;
    final cadence = _cadenceMinutes;
    if (requested <= 0) return cadence < 1 ? 1 : (cadence < 5 ? cadence : 5);
    if (requested > cadence) return cadence;
    return requested;
  }

  int get _cadenceMinutes =>
      preferences.notificationFrequency.clamp(1, 24 * 60);

  /// Whether the device's clock has moved suspiciously often, which makes the
  /// reported totals unreliable for the leaderboard.
  bool get isClockUnreliable => _clockTracker.isDistrusted;

  /// Publishes the current state to the home-screen widget.
  ///
  /// Called whenever a displayed figure changes so the widget never shows a
  /// stale countdown or an out-of-date streak. Failures are swallowed by the
  /// bridge: a widget that will not update must never break the reminder loop.
  Future<void> syncWidget() async {
    if (_disposed) return;
    final snapshot = WidgetSnapshot.fromState(
      streak: WorkdayMetrics.currentStreak(_dailyHistory, DateTime.now()),
      totalXp: GamificationMetrics.totalXp(_dailyHistory),
      todayCompleted: _todayAnalytics.remindersCompleted,
      dailyGoal: preferences.streakGoal,
      windowOpen: isActionWindowOpen,
      windowMinutes: _actionWindowMinutes,
      cadenceMinutes: _cadenceMinutes,
      clockSuspect: isClockUnreliable,
      // The widget follows the user's accent, so the preference is part of the
      // payload rather than something the native side guesses.
      colorSystem: preferences.colorSystem,
    );
    final payload = snapshot.toMap();
    // Language is a widget-level concern, so it rides along in the payload
    // rather than being guessed by the native side.
    payload['lang'] = _languageCode;
    await WidgetBridge.publish(payload);
  }

  /// The reason the last [completeReminder] was refused, or null when it was
  /// accepted. The UI shows this so a refusal is never silent.
  String? get lastActionRejection => _lastActionRejection;

  static bool _inQuietHours(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    final parts = raw.split('-');
    if (parts.length != 2) return false;
    int? parse(String value) {
      final bits = value.split(':');
      if (bits.length != 2) return null;
      final hours = int.tryParse(bits[0]);
      final minutes = int.tryParse(bits[1]);
      if (hours == null || minutes == null) return null;
      if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
      return hours * 60 + minutes;
    }

    final start = parse(parts[0]);
    final end = parse(parts[1]);
    if (start == null || end == null) return false;
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    if (start <= end) return current >= start && current < end;
    return current >= start || current < end;
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    final storedLanguage = (await SharedPreferences.getInstance()).getString(
      'language_code',
    );
    _languageCode = storedLanguage == 'en' ? 'en' : 'fr';

    // Set up before anything can schedule a reminder, so the first countdown is
    // never posted against an uninitialised channel.
    await liveCountdownService.initialize(
      isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      languageCode: _languageCode,
    );

    // 1. Load Profile
    _userProfile = await localRepo.getUserProfile();
    final userId = _userProfile?.id ?? 'local_${const Uuid().v4()}';

    if (_userProfile == null) {
      _userProfile = UserProfile(
        id: userId,
        name: 'Employee',
        role: 'employee',
      );
      await localRepo.saveUserProfile(_userProfile!);
    }

    final signedInId = supabaseService.signedInUserId;
    if (signedInId != null && signedInId != _userProfile!.id) {
      await _adoptAuthenticatedAccount(
        signedInId,
        supabaseService.signedInEmail,
      );
    }
    if (signedInId != null) await _refreshRemoteProfile();

    // 2. Load Preferences
    _preferences = await localRepo.getUserPreferences(_userProfile!.id);
    if (_preferences == null) {
      _preferences = UserPreferences.defaultPreferences(_userProfile!.id);
      await localRepo.saveUserPreferences(_preferences!);
    }
    audioService.soundEnabled = _preferences!.soundEnabled;
    audioService.selectedSound = _preferences!.selectedSound;
    HapticsService.enabled = _preferences!.hapticsEnabled;

    // 3. Today's Analytics & History
    final today = localRepo.getTodayDateString();
    _analyticsDate = today;
    _todayAnalytics = await localRepo.getAnalyticsForDate(
      _userProfile!.id,
      today,
    );
    _dailyHistory = await localRepo.getAllDailyAnalytics(_userProfile!.id);
    _consecutiveSkips = (await localRepo.getRecentSkips(
      _userProfile!.id,
      3,
    )).length;

    // Never show fabricated organization metrics. Only admins in a configured
    // and authenticated workspace can load the aggregate dashboard.
    if (_userProfile!.isAdmin &&
        _userProfile!.organizationId != null &&
        supabaseService.client?.auth.currentUser?.id == _userProfile!.id) {
      try {
        _orgAnalytics = await supabaseService.fetchOrganizationAnalytics(
          _userProfile!.organizationId!,
        );
      } catch (_) {
        _orgAnalytics = null;
      }
    }

    // 5. Restore the absolute due time. Restarting the app must not restart a
    // full reminder interval or make an overdue break disappear.
    await _restoreReminderInterval(
      minutes: _preferences!.notificationFrequency,
    );

    // 6. Start 1-second UI ticker
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _authSubscription ??= supabaseService.authStateChanges.listen((_) {
      unawaited(_handleAuthStateChanged());
    });
    if (preferences.statisticsOptIn) await _startRealtimeAnalytics();

    registerWidgetActions();
    await syncWidget();

    notifyListeners();
  }

  void _tick() {
    final now = DateTime.now();

    // Watch for wall-clock manipulation by comparing it against a monotonic
    // stopwatch. Ordinary suspend/resume is classified separately, so a user
    // who sleeps is never flagged. The stopwatch is re-based each tick so it
    // always measures the interval since the previous reading.
    final monotonic = _uptime.elapsed;
    _uptime
      ..stop()
      ..reset()
      ..start();
    _clockTracker.observe(wallNow: now, monotonicDelta: monotonic);

    if (_nextReminderTime != null) {
      _remainingDuration = ReminderClock.remaining(now, _nextReminderTime!);
      if (_remainingDuration == Duration.zero) {
        // The window has shut. Announce it once, and never for a window that
        // was already acted on.
        if (!_isBreakActive && !_reminderAlertPlayed) {
          _reminderAlertPlayed = true;
          if (!isInQuietHours) unawaited(audioService.playChime());
        }
      }
    }

    // When the boundary passes, roll forward to the following window.
    if (now.isAfter(_nextReminderTime ?? now)) {
      unawaited(_scheduleNextInterval(minutes: _cadenceMinutes));
    }

    final today = localRepo.getTodayDateString();
    if (today != _analyticsDate) {
      _analyticsDate = today;
      _actedWindows.clear();
      unawaited(_loadAnalyticsForDate(today));
    }
    notifyListeners();
  }

  Future<void> _loadAnalyticsForDate(String date) async {
    final userId = _userProfile?.id;
    if (userId == null) return;
    _todayAnalytics = await localRepo.getAnalyticsForDate(userId, date);
    _dailyHistory = await localRepo.getAllDailyAnalytics(userId);
    notifyListeners();
  }

  /// Reconciles the visible timer and daily totals after an OS suspend/resume.
  Future<void> onAppResumed() async {
    _tick();
    await refreshReminderQueue();
    await drainPendingWidgetAction();
    // The launcher may have missed a state change while the app was away.
    await syncWidget();
  }

  /// Applies a stand-up requested from a widget while the app was closed.
  ///
  /// iOS cannot start a Dart isolate from an App Intent, so the extension records
  /// the tap and the app applies it here on the next resume. Consuming the
  /// pending action and then routing it through [completeReminder] means a
  /// widget tap and an in-app tap share the same window and dedupe checks.
  Future<void> drainPendingWidgetAction() async {
    final action = await WidgetBridge.takePendingAction();
    if (action != 'complete') return;
    await completeReminder();
  }

  // ---------------------------------------------------------------------------
  // Reminder Actions
  // ---------------------------------------------------------------------------

  /// Aligns the timer to the next hourly action window instead of re-anchoring
  /// a rolling interval. Snoozing therefore moves to the next window rather than
  /// granting a free extra break.
  Future<void> _scheduleNextInterval({required int minutes}) async {
    _reminderAlertPlayed = false;
    final now = DateTime.now();
    final safeMinutes = minutes.clamp(1, 24 * 60);
    final next = StandWindow.nextWindow(
      now: now,
      actionWindowMinutes: _actionWindowMinutes,
      cadenceMinutes: safeMinutes,
    );

    if (next == null) {
      // Defensive: a malformed preference must never leave the app without a
      // timer, so fall back to a plain interval.
      _timerStartTime = now;
      _nextReminderTime = now.add(Duration(minutes: safeMinutes));
    } else {
      _timerStartTime = next.start;
      _nextReminderTime = next.end;
    }
    _remainingDuration = _nextReminderTime!.difference(now);

    await _persistReminderInterval();
    await _scheduleReminderQueue(_nextReminderTime!);
    await _syncLiveCountdown();
  }

  /// Pushes the next break time to the ongoing notification.
  ///
  /// Kept as a separate step so every path that recomputes the timer — a cadence
  /// change, a snooze, a language change, a window that rolls over — updates the
  /// shade too. Skipping any one of them would leave a stale countdown on screen.
  Future<void> _syncLiveCountdown() async {
    final next = _nextReminderTime;
    if (next == null) {
      await liveCountdownService.cancel();
      return;
    }
    await liveCountdownService.start(next);
  }

  /// Rebuilds the timer purely from the wall clock. Because the window is
  /// derived from the current time rather than from stored state, a device whose
  /// clock moved, or whose storage was cleared, resynchronises on the next
  /// launch without needing any recovery logic.
  Future<void> _restoreReminderInterval({required int minutes}) async {
    final now = DateTime.now();
    final safeMinutes = minutes.clamp(1, 24 * 60);
    final next = StandWindow.nextWindow(
      now: now,
      actionWindowMinutes: _actionWindowMinutes,
      cadenceMinutes: safeMinutes,
    );

    if (next == null) {
      _timerStartTime = now;
      _nextReminderTime = now.add(Duration(minutes: safeMinutes));
    } else {
      _timerStartTime = next.start;
      _nextReminderTime = next.end;
    }
    _remainingDuration = _nextReminderTime!.difference(now);

    final active = StandWindow.activeWindow(
      now: now,
      actionWindowMinutes: _actionWindowMinutes,
      cadenceMinutes: safeMinutes,
    );
    // Suppress the chime if we are already inside a window that opened while
    // the app was closed, otherwise reopening mid-window would nag.
    _reminderAlertPlayed = active != null;

    await _persistReminderInterval();
    await _scheduleReminderQueue(_nextReminderTime!);
  }

  Future<void> _persistReminderInterval() async {
    // Deliberately a no-op. The timer is derived from the wall clock on every
    // launch (see _restoreReminderInterval), so persisting the due time would
    // write state nothing ever reads and leave stale values on disk. Kept as a
    // call-site anchor so the derivation stays easy to find.
  }

  /// Schedules the OS queue. Reminders are emitted at the *start* of each
  /// actionable window so the alert and the rule the user sees agree.
  Future<void> _scheduleReminderQueue(DateTime windowBoundary) {
    final french = _languageCode == 'fr';
    return notificationService.scheduleReminderSeries(
      firstReminder: windowBoundary,
      frequencyMinutes: _cadenceMinutes,
      title: french ? 'C’est le moment de bouger !' : 'Time to stand up!',
      body: french
          ? 'Prenez 5 minutes pour vous étirer, respirer et bouger.'
          : 'Take a 5-minute break to stretch, breathe, and move.',
      quietHours: preferences.quietHours,
      actionWindowMinutes: _actionWindowMinutes,
    );
  }

  Future<void> refreshReminderQueue() {
    final firstReminder =
        _nextReminderTime ??
        DateTime.now().add(
          Duration(minutes: preferences.notificationFrequency),
        );
    return _scheduleReminderQueue(firstReminder);
  }

  void handleNotificationAction(String action, int notificationId) {
    switch (action) {
      case 'snooze':
        unawaited(snoozeReminder());
        return;
      case 'skip':
        unawaited(skipReminder());
        return;
      case 'complete':
      case '':
        unawaited(completeReminder());
        return;
    }
  }

  /// A stable key for the window [now] belongs to, used to deduplicate actions.
  ///
  /// When no window is open the key falls back to a coarse bucket derived from
  /// the cadence boundary rather than the current instant. Keying on the exact
  /// second would let a burst of rapid taps each produce a fresh key, so the
  /// guard would never block anything.
  int _currentWindowKey([DateTime? at]) {
    final when = at ?? DateTime.now();
    final window = StandWindow.activeWindow(
      now: when,
      actionWindowMinutes: _actionWindowMinutes,
      cadenceMinutes: _cadenceMinutes,
    );
    if (window != null) return window.end.millisecondsSinceEpoch;

    final cadenceMs = _cadenceMinutes * 60 * 1000;
    return when.millisecondsSinceEpoch ~/ cadenceMs;
  }

  /// Asks the database whether the window identified by [key] was already used.
  ///
  /// A key derived from an active window is the window's closing instant, which
  /// is the lower bound to search from; the width comes from the configured
  /// action window. A key derived outside any window is a coarse cadence bucket
  /// instead, so it is searched over the whole cadence slot.
  ///
  /// Any failure resolves to `false` so a database problem cannot silently block
  /// a legitimate break; the analytics transaction is what actually guarantees
  /// the totals stay correct.
  Future<bool> _alreadyCompletedInWindow(DateTime now, int key) async {
    try {
      final active = StandWindow.activeWindow(
        now: now,
        actionWindowMinutes: _actionWindowMinutes,
        cadenceMinutes: _cadenceMinutes,
      );
      if (active != null && active.end.millisecondsSinceEpoch == key) {
        return await localRepo.hasCompletedReminderInWindow(
          _userProfile!.id,
          active.start,
          active.end,
        );
      }
      final cadenceMs = _cadenceMinutes * 60 * 1000;
      return await localRepo.hasCompletedReminderInWindow(
        _userProfile!.id,
        DateTime.fromMillisecondsSinceEpoch(key * cadenceMs),
        DateTime.fromMillisecondsSinceEpoch((key + 1) * cadenceMs),
      );
    } catch (e) {
      debugPrint('Completion dedupe check failed: $e');
      return false;
    }
  }

  /// Records a completed stand-up break.
  ///
  /// Returns false when the action is refused. Refusals are explicit and
  /// surfaced through [lastActionRejection] rather than being swallowed, so a
  /// rejected tap always produces visible feedback.
  ///
  /// [windowKey] lets an in-flight action that began inside a window finish
  /// even if the window has since closed, which is what the guided stretch
  /// needs. Pass null for a new, user-initiated action.
  Future<bool> completeReminder({int? windowKey}) async {
    final now = DateTime.now();

    // Gate 1: the hourly action window. A stretch that already started is
    // exempt because it was validated when it began.
    final inProgressStretch = _isBreakActive && _breakWindowKey != null;
    if (preferences.enforceActionWindow &&
        windowKey == null &&
        !inProgressStretch &&
        !isActionWindowOpen) {
      _lastActionRejection = _languageCode == 'fr'
          ? 'La fenêtre de pause ouvre à la minute 55 de chaque heure. '
                'Revenez ensuite pour enregistrer votre pause.'
          : 'The movement window opens in the last 5 minutes of each hour. '
                'Come back then to log your break.';
      unawaited(audioService.playClick());
      notifyListeners();
      return false;
    }

    // Gate 2: one completion per window. A notification tap racing an in-app
    // tap must not be counted twice.
    final key = windowKey ?? _currentWindowKey(now);
    if (_actedWindows.contains(key)) {
      _lastActionRejection = _languageCode == 'fr'
          ? 'Cette pause a déjà été enregistrée.'
          : 'This break has already been recorded.';
      notifyListeners();
      return false;
    }

    // Gate 3: the same rule, asked of the database rather than of memory.
    //
    // [_actedWindows] only knows about taps in this isolate. A home-screen
    // widget tap arrives in a headless isolate, and a cold launch or a crash
    // starts a fresh one, so an in-memory-only guard would let a second break
    // through and inflate both the streak and the leaderboard totals.
    if (await _alreadyCompletedInWindow(now, key)) {
      _actedWindows.add(key);
      _lastActionRejection = _languageCode == 'fr'
          ? 'Cette pause a déjà été enregistrée.'
          : 'This break has already been recorded.';
      notifyListeners();
      return false;
    }

    _lastActionRejection = null;
    _consecutiveSkips = 0;
    _isBreakActive = false;
    _breakTimer?.cancel();
    _breakTimer = null;
    _breakWindowKey = null;

    unawaited(audioService.playSuccess());
    unawaited(HapticsService.celebration());

    // 1. Log action
    final log = ReminderLog(
      id: const Uuid().v4(),
      userId: _userProfile!.id,
      scheduledTime: now,
      actionTaken: 'completed',
    );
    await localRepo.logReminder(log);

    // 2. Update local analytics
    _todayAnalytics = await localRepo.updateAnalytics(
      _userProfile!.id,
      'completed',
      orgId: _userProfile!.organizationId,
    );
    _dailyHistory = await localRepo.getAllDailyAnalytics(_userProfile!.id);

    // 3. Claim the window only once the write succeeded, so a failed write does
    // not burn the window and leave the user unable to log it at all.
    _actedWindows.add(key);

    // 4. Move to the next hourly window
    await _scheduleNextInterval(minutes: _cadenceMinutes);

    // 5. Sync
    _triggerBackgroundSync();
    unawaited(syncWidget());
    notifyListeners();
    return true;
  }

  /// Defers a break.
  ///
  /// Under the action-window rule a snooze always advances to the next hourly
  /// window rather than granting an immediate extra break, so repeated snoozes
  /// cannot be used to accumulate extra counted pauses. The `minutes` argument
  /// is retained for compatibility and only influences the label recorded.
  Future<void> snoozeReminder({int minutes = 10}) async {
    unawaited(audioService.playChime());
    unawaited(HapticsService.medium());
    _isBreakActive = false;
    _consecutiveSkips = 0;
    _breakTimer?.cancel();

    final log = ReminderLog(
      id: const Uuid().v4(),
      userId: _userProfile!.id,
      scheduledTime: DateTime.now(),
      actionTaken: 'snoozed',
      snoozeDuration: minutes,
    );
    await localRepo.logReminder(log);

    _todayAnalytics = await localRepo.updateAnalytics(
      _userProfile!.id,
      'snoozed',
      orgId: _userProfile!.organizationId,
    );
    _dailyHistory = await localRepo.getAllDailyAnalytics(_userProfile!.id);

    // Advance to the next window. `_cadenceMinutes` rather than `minutes` is
    // deliberate: a snooze must not shorten the cadence.
    await _scheduleNextInterval(minutes: _cadenceMinutes);

    _triggerBackgroundSync();
    notifyListeners();
  }

  Future<void> skipReminder() async {
    unawaited(audioService.playClick());
    HapticsService.light();
    _consecutiveSkips++;
    _isBreakActive = false;
    _breakTimer?.cancel();

    final log = ReminderLog(
      id: const Uuid().v4(),
      userId: _userProfile!.id,
      scheduledTime: DateTime.now(),
      actionTaken: 'skipped',
    );
    await localRepo.logReminder(log);

    _todayAnalytics = await localRepo.updateAnalytics(
      _userProfile!.id,
      'skipped',
      orgId: _userProfile!.organizationId,
    );
    _dailyHistory = await localRepo.getAllDailyAnalytics(_userProfile!.id);

    // Check consecutive skips. `>= 3` rather than `== 3`: the streak is
    // restored from history at launch and can already sit above three, in
    // which case an equality test would suppress the nudge for the whole
    // session.
    if (_consecutiveSkips >= 3) {
      unawaited(audioService.playNudge());
      await notificationService.showNudgeNotification(
        id: 999,
        message: _languageCode == 'fr'
            ? 'Trois pauses reportées. Une minute d’étirements peut déjà vous faire du bien !'
            : "You've skipped 3 breaks in a row. Even a 60-second stretch refreshes your back and brain!",
      );
    }

    await _scheduleNextInterval(minutes: preferences.notificationFrequency);
    _triggerBackgroundSync();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Guided Stretch Mode
  // ---------------------------------------------------------------------------

  /// Begins the guided stretch.
  ///
  /// A guided stretch lasts five minutes, which is exactly the length of the
  /// default action window. Because a window's end instant is exclusive, a
  /// stretch that starts when the window opens necessarily finishes at or after
  /// the window closes. The stretch is therefore bound to the window it began
  /// in ([_breakWindowKey]) so its completion is still honoured, rather than
  /// being refused by the gate that guards a *new* stand action.
  void startGuidedStretch() {
    unawaited(audioService.playClick());
    _isBreakActive = true;
    _activeBreakStep = 0;
    _breakSecondsRemaining = 300; // 5 minutes
    _breakWindowKey = _currentWindowKey();

    // The break has started, so the countdown to it has nothing left to say.
    // Leaving it up would show a stuck "0:00" next to an in-progress stretch.
    unawaited(liveCountdownService.cancel());

    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_breakSecondsRemaining > 0) {
        _breakSecondsRemaining--;
        // 5 steps: 60s per step
        _activeBreakStep = (4 - (_breakSecondsRemaining ~/ 60)).clamp(0, 4);
        notifyListeners();
        return;
      }
      timer.cancel();
      // A timer callback has no caller to observe a failure, so the completion
      // is handled here and any rejection is surfaced through the UI rather
      // than becoming an unhandled async error.
      try {
        await completeReminder(windowKey: _breakWindowKey);
      } catch (error) {
        debugPrint('Guided stretch completion failed: $error');
      } finally {
        // Always clear the flag. Leaving it set would suppress the reminder
        // chime for the remainder of the session.
        _breakTimer = null;
        _isBreakActive = false;
        _breakWindowKey = null;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void cancelGuidedStretch() {
    _breakTimer?.cancel();
    _breakTimer = null;
    _isBreakActive = false;
    _breakWindowKey = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Settings & Preferences Updates
  // ---------------------------------------------------------------------------
  Future<void> updatePreferences({
    String? themeMode,
    String? colorSystem,
    int? notificationFrequency,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? statisticsOptIn,
    bool? onboardingCompleted,
    String? selectedSound,
    String? quietHours,
    bool clearQuietHours = false,
    int? streakGoal,
    int? actionWindowMinutes,
    bool? enforceActionWindow,
  }) async {
    _preferences = preferences.copyWith(
      themeMode: themeMode,
      colorSystem: colorSystem,
      notificationFrequency: notificationFrequency,
      soundEnabled: soundEnabled,
      hapticsEnabled: hapticsEnabled,
      statisticsOptIn: statisticsOptIn,
      onboardingCompleted: onboardingCompleted,
      selectedSound: selectedSound,
      quietHours: quietHours,
      clearQuietHours: clearQuietHours,
      streakGoal: streakGoal,
      actionWindowMinutes: actionWindowMinutes,
      enforceActionWindow: enforceActionWindow,
    );

    if (soundEnabled != null) {
      audioService.soundEnabled = soundEnabled;
    }
    if (hapticsEnabled != null) {
      HapticsService.enabled = hapticsEnabled;
    }

    // Publish before any I/O so appearance changes land on the next frame.
    //
    // Previously the first `notifyListeners()` sat below the database write, the
    // realtime-analytics toggle and up to three notification-queue rebuilds.
    // Toggling the theme therefore felt broken: the control moved, the screen
    // did not, and the delay scaled with how slow the disk was. The UI is the
    // cheapest and most latency-sensitive part of this method, so it goes first;
    // persistence and rescheduling then run behind it.
    notifyListeners();

    // The widget payload carries the resolved palette, so an accent change has to
    // reach the launcher rather than waiting for the next break.
    if (colorSystem != null) unawaited(syncWidget());

    await localRepo.saveUserPreferences(_preferences!);

    if (statisticsOptIn != null) {
      if (statisticsOptIn) {
        await localRepo.markAllAnalyticsAsUnsynced(_userProfile!.id);
        await _startRealtimeAnalytics();
      } else {
        await supabaseService.stopWatchingAnalytics();
      }
      _triggerBackgroundSync();
    }

    if (notificationFrequency != null) {
      await _scheduleNextInterval(minutes: _cadenceMinutes);
    }

    // Changing the window length or the enforcement flag both require the OS
    // queue to be rebuilt, because it decides which instants are scheduled.
    if (actionWindowMinutes != null || enforceActionWindow != null) {
      await _scheduleNextInterval(minutes: _cadenceMinutes);
    }

    if (selectedSound != null) {
      audioService.selectedSound = selectedSound;
    }

    // Quiet hours change which OS reminders exist, so rebuild the queue.
    if (quietHours != null || clearQuietHours) {
      await refreshReminderQueue();
    }

    // A final notification catches anything the work above changed. Harmless
    // when the early one already reflected everything: ListenableBuilder
    // collapses duplicate notifications into a single rebuild.
    notifyListeners();
  }

  Future<void> updateLanguage(String languageCode) async {
    if (languageCode != 'fr' && languageCode != 'en') return;
    if (languageCode == _languageCode) return;

    _languageCode = languageCode;

    // Repaint before the I/O for the same reason `updatePreferences` does: the
    // whole interface re-renders on this, and the queue rebuild below can take
    // tens of milliseconds on a slow device.
    notifyListeners();

    await notificationService.setLanguageCode(languageCode);
    liveCountdownService.setLanguageCode(languageCode);
    final store = await SharedPreferences.getInstance();
    await store.setString('language_code', languageCode);
    // The widget carries its own copy of the strings, so a language change has
    // to be pushed to the launcher or the two languages disagree on screen.
    unawaited(syncWidget());
    await refreshReminderQueue();
  }

  Future<void> updateProfile({
    String? name,
    String? designation,
    String? department,
    String? email,
    String? organizationId,
    String? organizationName,
    String? role,
  }) async {
    if (_userProfile == null) return;
    _userProfile = _userProfile!.copyWith(
      name: name,
      designation: designation,
      department: department,
      email: email,
      organizationId: organizationId,
      organizationName: organizationName,
      role: role,
    );

    await localRepo.saveUserProfile(_userProfile!);
    await supabaseService.syncProfileToCloud(_userProfile!);
    notifyListeners();
  }

  Future<bool> createAccount({
    required String email,
    required String password,
  }) async {
    return supabaseService.createEmailAccount(email: email, password: password);
  }

  Future<void> signIn({required String email, required String password}) async {
    await supabaseService.signInWithEmail(email: email, password: password);
    final id = supabaseService.signedInUserId;
    if (id == null) {
      throw StateError('Sign in did not return an active session.');
    }
    await _adoptAuthenticatedAccount(id, supabaseService.signedInEmail);
    await supabaseService.syncProfileToCloud(_userProfile!);
    await _refreshRemoteProfile();
    if (preferences.statisticsOptIn) {
      await localRepo.markAllAnalyticsAsUnsynced(_userProfile!.id);
      await triggerCloudSync();
      await _startRealtimeAnalytics();
    }
    notifyListeners();
  }

  Future<void> signInWithProvider(OAuthProvider provider) async {
    await supabaseService.signInWithProvider(provider);
    if (supabaseService.signedInUserId != null) await attachCurrentAccount();
  }

  Future<void> sendMagicLink(String email) =>
      supabaseService.sendMagicLink(email);

  Future<void> attachCurrentAccount() async {
    final id = supabaseService.signedInUserId;
    if (id == null) throw StateError('There is no active account session.');
    await _adoptAuthenticatedAccount(id, supabaseService.signedInEmail);
    await supabaseService.syncProfileToCloud(_userProfile!);
    await _refreshRemoteProfile();
    if (preferences.statisticsOptIn) await _startRealtimeAnalytics();
    notifyListeners();
  }

  Future<void> signOut() async {
    await supabaseService.signOut();
    await supabaseService.stopWatchingAnalytics();
    _syncStatus = SyncStatus.offline;
    notifyListeners();
  }

  Future<void> joinOrganization(String inviteCode) async {
    final organization = await supabaseService.joinOrganization(inviteCode);
    await updateProfile(
      organizationId: organization['id'] as String,
      organizationName: organization['name'] as String,
    );
  }

  Future<void> _adoptAuthenticatedAccount(
    String accountId,
    String? email,
  ) async {
    final operation = _accountTransition.then((_) async {
      if (_userProfile == null) return;
      final previousId = _userProfile!.id;
      if (previousId != accountId) {
        await localRepo.reassignLocalUser(previousId, accountId);
      }
      _userProfile = _userProfile!.copyWith(id: accountId, email: email);
      await localRepo.saveUserProfile(_userProfile!);
      if (_preferences != null) {
        _preferences = _preferences!.copyWith(userId: accountId);
        await localRepo.saveUserPreferences(_preferences!);
      }
      _todayAnalytics = await localRepo.getAnalyticsForDate(
        accountId,
        localRepo.getTodayDateString(),
      );
      _dailyHistory = await localRepo.getAllDailyAnalytics(accountId);
    });
    _accountTransition = operation.catchError((Object _) {});
    await operation;
  }

  Future<void> _handleAuthStateChanged() async {
    final accountId = supabaseService.signedInUserId;
    if (accountId == null) {
      _syncStatus = SyncStatus.offline;
      notifyListeners();
      return;
    }
    if (_userProfile == null) return;
    try {
      await _adoptAuthenticatedAccount(
        accountId,
        supabaseService.signedInEmail,
      );
      await supabaseService.syncProfileToCloud(_userProfile!);
      await _refreshRemoteProfile();
      if (preferences.statisticsOptIn) {
        await triggerCloudSync();
        await _startRealtimeAnalytics();
      }
      notifyListeners();
    } catch (error) {
      debugPrint('Unable to attach the authenticated account: $error');
    }
  }

  Future<void> _refreshRemoteProfile() async {
    try {
      final remote = await supabaseService.fetchMyProfile();
      if (remote == null) return;
      final organizationId = remote['organization_id'] as String?;
      final organizationName = organizationId == null
          ? null
          : await supabaseService.fetchOrganizationName(organizationId);
      _userProfile = _userProfile!.copyWith(
        name: remote['name'] as String?,
        designation: remote['designation'] as String?,
        department: remote['department'] as String?,
        organizationId: organizationId,
        organizationName: organizationName,
        clearOrganization: organizationId == null,
        role: remote['role'] as String?,
      );
      await localRepo.saveUserProfile(_userProfile!);
    } catch (error) {
      debugPrint('Unable to refresh account profile: $error');
    }
  }

  Future<void> _startRealtimeAnalytics() async {
    if (!preferences.statisticsOptIn || _userProfile == null) return;
    await supabaseService.watchMyAnalytics(_userProfile!.id, (record) {
      unawaited(_mergeRealtimeAnalytics(record));
    });
  }

  Future<void> _mergeRealtimeAnalytics(Map<String, dynamic> record) async {
    try {
      final remote = DailyAnalytics.fromJson(record);
      if (_userProfile?.id != remote.userId) return;
      await localRepo.mergeRemoteAnalytics(remote);
      _todayAnalytics = await localRepo.getAnalyticsForDate(
        remote.userId,
        localRepo.getTodayDateString(),
      );
      _dailyHistory = await localRepo.getAllDailyAnalytics(remote.userId);
      notifyListeners();
    } catch (error) {
      debugPrint('Unable to apply realtime analytics: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Cloud Sync
  // ---------------------------------------------------------------------------
  Future<void> triggerCloudSync() async {
    if (_disposed) return;
    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    SyncStatus status;
    try {
      status = await supabaseService.syncLocalToCloud(
        userId: _userProfile!.id,
        localRepo: localRepo,
        optIn: preferences.statisticsOptIn,
        clockUnreliable: isClockUnreliable,
      );
    } catch (error) {
      debugPrint('Cloud sync failed: $error');
      status = SyncStatus.error;
    }

    // An in-flight sync can outlive disposal; notifying afterwards would trip
    // the ChangeNotifier "used after dispose" assertion.
    if (_disposed) return;
    _syncStatus = status;
    notifyListeners();
  }

  void _triggerBackgroundSync() {
    if (_disposed) return;
    unawaited(triggerCloudSync());
  }

  /// Wires the home-screen widget's action button.
  ///
  /// The button deliberately does **not** log the break itself: it routes back
  /// through [completeReminder], so the action window and the
  /// one-completion-per-window rule are enforced identically whether the user
  /// taps in the app or on the launcher.
  void registerWidgetActions() {
    WidgetBridge.registerActionHandler((action) async {
      if (action != 'complete') return;
      await completeReminder();
      await syncWidget();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    _breakTimer?.cancel();
    _breakTimer = null;
    _authSubscription?.cancel();
    _authSubscription = null;
    _uptime.stop();
    // The notification service holds its own Linux timers and a callback into
    // this notifier; both must go or a late timer would notify a dead object.
    unawaited(supabaseService.stopWatchingAnalytics());
    notificationService.dispose();
    audioService.dispose();
    // The countdown owns a repeating timer; left running it would keep posting
    // to a notification service this notifier no longer drives.
    liveCountdownService.dispose();
    super.dispose();
  }
}
