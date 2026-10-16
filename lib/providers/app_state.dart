import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import 'package:uuid/uuid.dart';
import 'package:standup_app/core/app_cadence.dart';
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
import 'package:standup_app/data/models/work_schedule.dart';
import 'package:standup_app/data/remote/supabase_service.dart';
import 'package:standup_app/services/audio_service.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/services/guidance_provider.dart';
import 'package:standup_app/services/supabase_guidance_provider.dart';
import 'package:standup_app/services/live_countdown_service.dart';
import 'package:standup_app/services/notification_service.dart';

/// Prefix for a profile that has never been claimed by a cloud account.
///
/// Minted at init for a device-only profile, and the discriminator that decides
/// whether local history may be handed to an account on sign-in: a `local_` id
/// has no owner to protect, an account id does.
const String kLocalUserIdPrefix = 'local_';

bool _isLocalUserId(String userId) => userId.startsWith(kLocalUserIdPrefix);

class AppState extends ChangeNotifier {
  final LocalDatabaseRepository localRepo;
  final SupabaseService supabaseService;
  final NotificationService notificationService;
  final AudioService audioService;
  final GuidanceProvider _aiGuidanceProvider;

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
  bool _preludeAlertPlayed = false;
  int _activeBreakStep = 0;
  int _breakSecondsRemaining = AppCadence.guidedStretchSeconds;
  Timer? _breakTimer;

  /// The window key a guided stretch was started under, so its completion is
  /// still honoured after the window's end instant has passed.
  int? _breakWindowKey;

  SyncStatus _syncStatus = SyncStatus.idle;
  Future<void>? _syncInFlight;
  String? _syncInFlightUserId;
  String _languageCode = 'fr';
  DeviceProfile? _deviceProfile;
  final LocalGuidanceProvider _localGuidanceProvider =
      const LocalGuidanceProvider();
  GuidanceFeedback _guidanceFeedback = GuidanceFeedback.none;
  GuidanceResult? _aiGuidanceResult;
  GuidanceInput? _aiGuidanceInput;
  String? _aiGuidanceUserId;
  bool _isAiGuidanceLoading = false;
  bool _aiGuidanceUnavailable = false;
  GuidanceInput? _aiGuidanceUnavailableInput;
  String? _aiGuidanceUnavailableUserId;

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
    GuidanceProvider? aiGuidanceProvider,
  }) : _aiGuidanceProvider =
           aiGuidanceProvider ?? SupabaseGuidanceProvider(supabaseService);

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
  GuidanceInput get _guidanceInput => GuidanceInput(
    completedToday: _todayAnalytics.remindersCompleted,
    snoozedToday: _todayAnalytics.remindersSnoozed,
    skippedToday: _todayAnalytics.remindersSkipped,
    dailyGoal: preferences.streakGoal,
    cadenceMinutes: _cadenceMinutes,
    feedback: _guidanceFeedback,
  );
  GuidanceResult? get personalGuidance =>
      _aiGuidanceInput == _guidanceInput &&
          _aiGuidanceUserId == supabaseService.signedInUserId
      ? _aiGuidanceResult ?? _localGuidanceProvider.evaluate(_guidanceInput)
      : _localGuidanceProvider.evaluate(_guidanceInput);
  bool get isAiGuidanceLoading => _isAiGuidanceLoading;
  bool get aiGuidanceUnavailable =>
      _aiGuidanceUnavailable &&
      _aiGuidanceUnavailableInput == _guidanceInput &&
      _aiGuidanceUnavailableUserId == supabaseService.signedInUserId;
  bool get hasAiGuidanceResult =>
      _aiGuidanceResult != null &&
      _aiGuidanceInput == _guidanceInput &&
      _aiGuidanceUserId == supabaseService.signedInUserId;
  bool get canRequestAiGuidance =>
      preferences.aiGuidanceOptIn &&
      supabaseService.isInitialized &&
      supabaseService.signedInUserId != null;
  bool get isAiGuidanceOptedIn => preferences.aiGuidanceOptIn;

  /// Explicitly requests one company-hosted insight. The local result is
  /// already available and remains the fallback for network/model failures.
  Future<void> requestAiGuidance() async {
    if (!canRequestAiGuidance || _isAiGuidanceLoading) return;
    final requestInput = _guidanceInput;
    final requestUserId = supabaseService.signedInUserId;
    _isAiGuidanceLoading = true;
    _aiGuidanceUnavailable = false;
    _aiGuidanceUnavailableInput = null;
    _aiGuidanceUnavailableUserId = null;
    notifyListeners();
    try {
      final result = await _aiGuidanceProvider.suggest(requestInput);
      final requestStillCurrent =
          preferences.aiGuidanceOptIn &&
          _guidanceInput == requestInput &&
          supabaseService.signedInUserId == requestUserId;
      if (requestStillCurrent && result != null) {
        _aiGuidanceResult = result;
        _aiGuidanceInput = requestInput;
        _aiGuidanceUserId = requestUserId;
      } else if (requestStillCurrent) {
        _aiGuidanceUnavailable = true;
        _aiGuidanceUnavailableInput = requestInput;
        _aiGuidanceUnavailableUserId = requestUserId;
      }
    } catch (_) {
      if (preferences.aiGuidanceOptIn &&
          _guidanceInput == requestInput &&
          supabaseService.signedInUserId == requestUserId) {
        _aiGuidanceUnavailable = true;
        _aiGuidanceUnavailableInput = requestInput;
        _aiGuidanceUnavailableUserId = requestUserId;
      }
    } finally {
      _isAiGuidanceLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void recordGuidanceFeedback(GuidanceFeedback feedback) {
    if (_guidanceFeedback == feedback) return;
    _guidanceFeedback = feedback;
    _aiGuidanceUnavailable = false;
    _aiGuidanceUnavailableInput = null;
    _aiGuidanceUnavailableUserId = null;
    notifyListeners();
  }

  /// The captured device profile, or null before [captureDeviceProfile] runs.
  DeviceProfile? get deviceProfile => _deviceProfile;

  /// Captures the transparent device profile from the running app. Called from
  /// the widget layer once a real screen size and locale are available.
  /// Records the window size, pixel ratio and locale used for reporting.
  ///
  /// ## Why this does not notify
  ///
  /// The shell captures the profile during `build`. If this called
  /// `notifyListeners`, the rebuild would reach the root `ListenableBuilder` that
  /// is an *ancestor already built in this frame*, which trips Flutter's
  /// "setState() or markNeedsBuild() called during build" assertion — a red
  /// screen in debug on the very first frame, and a one-frame delay in release.
  ///
  /// No notification is needed: the only consumer is the Settings device report,
  /// which reads the value while building, and the capture is guarded to run once.
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
  bool get isActionWindowOpen => activeWindow != null;

  /// Time left before the current window shuts, or zero when closed.
  Duration get windowTimeRemaining {
    final now = DateTime.now();
    final active = activeWindow;
    return active == null ? Duration.zero : active.end.difference(now);
  }

  /// Time until the next window opens, or zero while one is open.
  Duration get timeUntilNextWindow {
    final now = DateTime.now();
    if (activeWindow != null) return Duration.zero;
    return (_nextEligibleWindow(now)?.start ?? now).difference(now);
  }

  /// The actionable window currently open, for the UI to render.
  WindowSpan? get activeWindow {
    final now = DateTime.now();
    final candidate = StandWindow.activeWindow(
      now: now,
      actionWindowMinutes: _actionWindowMinutes,
      cadenceMinutes: _cadenceMinutes,
    );
    if (candidate == null ||
        !preferences.workSchedule.allowsWindow(
          candidate.start,
          candidate.end,
        )) {
      return null;
    }
    return candidate;
  }

  /// The advisory prelude currently open, or null when none is.
  ///
  /// The prelude is derived from the next *eligible* window — one the work
  /// schedule actually allows — so a weekday-only user is never warned before a
  /// weekend window that would not have been offered anyway. It is also
  /// suppressed while a window is open: at the instant the window begins the
  /// prelude is over, which is what keeps "get ready" from racing "go".
  ///
  /// Purely presentational. It never changes whether a break counts.
  WindowSpan? get preludeWindow {
    if (!preferences.preludeEnabled) return null;
    final now = DateTime.now();
    if (activeWindow != null) return null;
    final upcoming = _nextEligibleWindow(now);
    if (upcoming == null) return null;
    final minutes = AppCadence.resolvePrelude(
      preferences.preludeMinutes,
      _cadenceMinutes,
    );
    final candidate = WindowSpan(
      upcoming.start.subtract(Duration(minutes: minutes)),
      upcoming.start,
    );
    return candidate.contains(now) ? candidate : null;
  }

  /// Whether the advisory prelude before an upcoming break is currently open.
  bool get isPreludeOpen => preludeWindow != null;

  WindowSpan? _nextEligibleWindow(DateTime now) {
    var cursor = now;
    final lookAheadWindows = 7 * 24 * 60 ~/ _cadenceMinutes + 4;
    for (var i = 0; i < lookAheadWindows; i++) {
      final candidate = StandWindow.nextWindow(
        now: cursor,
        actionWindowMinutes: _actionWindowMinutes,
        cadenceMinutes: _cadenceMinutes,
      );
      if (candidate == null) return null;
      if (preferences.workSchedule.allowsWindow(
        candidate.start,
        candidate.end,
      )) {
        return candidate;
      }
      cursor = candidate.start.add(const Duration(seconds: 1));
    }
    return null;
  }

  /// The window length, clamped so a corrupt or hand-edited preference row can
  /// never make `StandWindow` throw `ArgumentError` from inside the 1 Hz
  /// ticker. Without this clamp a single bad value would produce an unhandled
  /// async error every second and freeze the visible timer at zero.
  int get _actionWindowMinutes => AppCadence.resolveActionWindow(
    preferences.actionWindowMinutes,
    _cadenceMinutes,
  );

  int get _cadenceMinutes =>
      AppCadence.clampCadence(preferences.notificationFrequency);

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

  static bool _inQuietHours(String? raw) =>
      QuietHours.isQuietAt(raw, DateTime.now());

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
    final userId =
        _userProfile?.id ?? '$kLocalUserIdPrefix${const Uuid().v4()}';

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
    final clockWasUnreliable = isClockUnreliable;

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
    if (clockWasUnreliable != isClockUnreliable) {
      unawaited(syncWidget());
    }

    if (_nextReminderTime != null) {
      _remainingDuration = ReminderClock.remaining(now, _nextReminderTime!);
    }

    // The chime is the invitation to stand, so it belongs to the moment a
    // window OPENS - that is the first instant a break can be recorded. It used
    // to fire when _nextReminderTime (the window's CLOSING instant) passed, so
    // the app stayed silent exactly when the opportunity appeared and nagged
    // instead after the window had expired, which is the one moment the user
    // can no longer act. The doc comment further down already described the
    // opposite intent, and the onboarding copy says "stand up when you hear
    // the gentle chime".
    final windowOpen = isActionWindowOpen;
    if (windowOpen && !_isBreakActive && !_reminderAlertPlayed) {
      _reminderAlertPlayed = true;
      if (!isInQuietHours) unawaited(audioService.playChime());
    }

    // The prelude is the "get ready to stop" warning that precedes the window.
    // It plays a distinct, softer cue so it can never be mistaken for the
    // invitation to stand, which still belongs to the moment the window opens.
    // The flag is reset when the next window is scheduled, so each window warns
    // exactly once.
    if (isPreludeOpen && !_isBreakActive && !_preludeAlertPlayed) {
      _preludeAlertPlayed = true;
      if (!isInQuietHours) unawaited(audioService.playNudge());
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
    _preludeAlertPlayed = false;
    final now = DateTime.now();
    final safeMinutes = AppCadence.clampCadence(minutes);
    final active = activeWindow;
    final lookupFrom = active == null
        ? now
        : active.end.add(const Duration(microseconds: 1));
    final next = _nextEligibleWindow(lookupFrom);

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
    final safeMinutes = AppCadence.clampCadence(minutes);
    final next = _nextEligibleWindow(now);

    if (next == null) {
      _timerStartTime = now;
      _nextReminderTime = now.add(Duration(minutes: safeMinutes));
    } else {
      _timerStartTime = next.start;
      _nextReminderTime = next.end;
    }
    _remainingDuration = _nextReminderTime!.difference(now);

    final active = activeWindow;
    // Suppress the chime if we are already inside a window that opened while
    // the app was closed, otherwise reopening mid-window would nag.
    _reminderAlertPlayed = active != null;
    // Same for the prelude: reopening already inside it must not replay the cue.
    _preludeAlertPlayed = isPreludeOpen;

    await _persistReminderInterval();
    await _scheduleReminderQueue(_nextReminderTime!);
    // This path is taken on app launch and on resume, and _syncLiveCountdown
    // was only ever called from _scheduleNextInterval. So a cold launch started
    // the timer and the OS queue but never started the ongoing notification,
    // leaving no countdown on screen until the next cadence roll-over - up to
    // an hour later. The claim in _syncLiveCountdown's own doc comment that
    // every path updating the timer updates the shade was not true of launch.
    await _syncLiveCountdown();
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
      preludeMinutes: preferences.preludeEnabled
          ? AppCadence.resolvePrelude(
              preferences.preludeMinutes,
              _cadenceMinutes,
            )
          : 0,
      workDays: preferences.workDays,
      workStartMinute: preferences.workStartMinute,
      workEndMinute: preferences.workEndMinute,
    );
  }

  Future<void> refreshReminderQueue() {
    final firstReminder =
        _nextReminderTime ??
        DateTime.now().add(Duration(minutes: _cadenceMinutes));
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

    // Outside a window the key is still a closing instant, just the one that
    // has already passed. Returning a cadence bucket index here instead made
    // this function return two different kinds of number, and
    // _alreadyCompletedInWindow could not tell them apart reliably once the
    // window had closed in between.
    return StandWindow.lastBoundaryAtOrBefore(
      now: when,
      cadenceMinutes: _cadenceMinutes,
    ).millisecondsSinceEpoch;
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
    if (!inProgressStretch && !preferences.workSchedule.isWorkingAt(now)) {
      _lastActionRejection = _languageCode == 'fr'
          ? 'Cette pause peut être enregistrée pendant vos horaires de travail.'
          : 'Breaks can be logged during your scheduled work hours.';
      unawaited(audioService.playClick());
      notifyListeners();
      return false;
    }
    if (preferences.enforceActionWindow &&
        windowKey == null &&
        !inProgressStretch &&
        !isActionWindowOpen) {
      final windowMinutes = _actionWindowMinutes;
      final cadenceMinutes = _cadenceMinutes;
      _lastActionRejection = _languageCode == 'fr'
          ? 'La pause peut être enregistrée pendant les $windowMinutes '
                'dernières minutes de chaque intervalle de $cadenceMinutes minutes.'
          : 'You can log a break during the last $windowMinutes minutes of '
                'each $cadenceMinutes-minute interval.';
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

    // The database transaction is the durable gate. It claims the window,
    // writes the event and updates the daily aggregate atomically, including
    // races from a notification or widget action in another isolate.
    final log = ReminderLog(
      id: const Uuid().v4(),
      userId: _userProfile!.id,
      scheduledTime: now,
      actionTaken: 'completed',
      timestamp: now,
    );
    final windowEnd = DateTime.fromMillisecondsSinceEpoch(key);
    final updatedAnalytics = await localRepo.recordReminderAction(
      log,
      completionWindowStart: windowEnd.subtract(
        Duration(minutes: _actionWindowMinutes),
      ),
      completionWindowEnd: windowEnd,
      orgId: _userProfile!.organizationId,
      standMinutes: _actionWindowMinutes,
    );
    if (updatedAnalytics == null) {
      _actedWindows.add(key);
      _lastActionRejection = _languageCode == 'fr'
          ? 'Cette pause a déjà été enregistrée.'
          : 'This break has already been recorded.';
      notifyListeners();
      return false;
    }
    _todayAnalytics = updatedAnalytics;

    _lastActionRejection = null;
    _consecutiveSkips = 0;
    _isBreakActive = false;
    _breakTimer?.cancel();
    _breakTimer = null;
    _breakWindowKey = null;

    unawaited(audioService.playSuccess());
    unawaited(HapticsService.celebration());

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

  /// Defers a break to the next normal action window.
  ///
  /// Keeping snooze on the normal cadence preserves the one-window completion
  /// rule. Record the actual time until that window so analytics never claim a
  /// fixed ten-minute delay that the scheduler did not provide.
  Future<void> snoozeReminder() async {
    final now = DateTime.now();
    final active = activeWindow;
    final nextWindow = _nextEligibleWindow(
      active == null ? now : active.end.add(const Duration(microseconds: 1)),
    );
    final delayMinutes = nextWindow == null
        ? _cadenceMinutes
        : ((nextWindow.start.difference(now).inSeconds + 59) ~/ 60)
              .clamp(0, 7 * 24 * 60)
              .toInt();
    final log = ReminderLog(
      id: const Uuid().v4(),
      userId: _userProfile!.id,
      scheduledTime: now,
      actionTaken: 'snoozed',
      snoozeDuration: delayMinutes,
    );
    final updatedAnalytics = await localRepo.recordReminderAction(
      log,
      orgId: _userProfile!.organizationId,
    );
    if (updatedAnalytics == null) {
      throw StateError('A non-completion action was not recorded.');
    }
    _todayAnalytics = updatedAnalytics;
    _dailyHistory = await localRepo.getAllDailyAnalytics(_userProfile!.id);

    unawaited(audioService.playChime());
    unawaited(HapticsService.medium());
    _isBreakActive = false;
    _consecutiveSkips = 0;
    _breakTimer?.cancel();
    _breakTimer = null;
    _breakWindowKey = null;

    await _scheduleNextInterval(minutes: _cadenceMinutes);

    _triggerBackgroundSync();
    notifyListeners();
  }

  Future<void> skipReminder() async {
    final now = DateTime.now();
    final log = ReminderLog(
      id: const Uuid().v4(),
      userId: _userProfile!.id,
      scheduledTime: now,
      actionTaken: 'skipped',
    );
    final updatedAnalytics = await localRepo.recordReminderAction(
      log,
      orgId: _userProfile!.organizationId,
    );
    if (updatedAnalytics == null) {
      throw StateError('A non-completion action was not recorded.');
    }
    _todayAnalytics = updatedAnalytics;
    _dailyHistory = await localRepo.getAllDailyAnalytics(_userProfile!.id);

    unawaited(audioService.playClick());
    HapticsService.light();
    _consecutiveSkips++;
    _isBreakActive = false;
    _breakTimer?.cancel();
    _breakTimer = null;
    _breakWindowKey = null;

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

    await _scheduleNextInterval(minutes: _cadenceMinutes);
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
    _breakSecondsRemaining = AppCadence.guidedStretchSeconds;
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

  /// Completes the guided stretch against the action window it started in.
  /// A five-minute stretch can outlast that window, so using the current window
  /// here would move the credit to a later interval or incorrectly reject it.
  Future<bool> finishGuidedStretch() {
    final windowKey = _breakWindowKey;
    if (!_isBreakActive || windowKey == null) return Future.value(false);
    return completeReminder(windowKey: windowKey);
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
    bool? aiGuidanceOptIn,
    bool? onboardingCompleted,
    String? selectedSound,
    String? quietHours,
    bool clearQuietHours = false,
    int? streakGoal,
    int? actionWindowMinutes,
    bool? enforceActionWindow,
    bool? preludeEnabled,
    int? preludeMinutes,
    String? workDays,
    int? workStartMinute,
    int? workEndMinute,
  }) async {
    if (workDays != null || workStartMinute != null || workEndMinute != null) {
      final days = (workDays ?? preferences.workDays)
          .split(',')
          .map(int.tryParse)
          .whereType<int>();
      WorkSchedule(
        days: days,
        startMinute: workStartMinute ?? preferences.workStartMinute,
        endMinute: workEndMinute ?? preferences.workEndMinute,
      );
    }
    _preferences = preferences.copyWith(
      themeMode: themeMode,
      colorSystem: colorSystem,
      notificationFrequency: notificationFrequency,
      soundEnabled: soundEnabled,
      hapticsEnabled: hapticsEnabled,
      statisticsOptIn: statisticsOptIn,
      aiGuidanceOptIn: aiGuidanceOptIn,
      onboardingCompleted: onboardingCompleted,
      selectedSound: selectedSound,
      quietHours: quietHours,
      clearQuietHours: clearQuietHours,
      streakGoal: streakGoal,
      actionWindowMinutes: actionWindowMinutes,
      enforceActionWindow: enforceActionWindow,
      preludeEnabled: preludeEnabled,
      preludeMinutes: preludeMinutes,
      workDays: workDays,
      workStartMinute: workStartMinute,
      workEndMinute: workEndMinute,
    );

    if (aiGuidanceOptIn == false ||
        streakGoal != null ||
        notificationFrequency != null) {
      _aiGuidanceResult = null;
      _aiGuidanceInput = null;
      _aiGuidanceUserId = null;
      _aiGuidanceUnavailable = false;
      _aiGuidanceUnavailableInput = null;
      _aiGuidanceUnavailableUserId = null;
    }

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
    if (colorSystem != null ||
        streakGoal != null ||
        workDays != null ||
        workStartMinute != null ||
        workEndMinute != null) {
      unawaited(syncWidget());
    }

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

    if (notificationFrequency != null ||
        workDays != null ||
        workStartMinute != null ||
        workEndMinute != null) {
      await _scheduleNextInterval(minutes: _cadenceMinutes);
    }

    // Changing the window length or the enforcement flag both require the OS
    // queue to be rebuilt, because it decides which instants are scheduled.
    if (actionWindowMinutes != null || enforceActionWindow != null) {
      await _scheduleNextInterval(minutes: _cadenceMinutes);
    }

    // The prelude is in-app everywhere and an OS notification on desktop, so the
    // queue has to be rebuilt there too. Re-arm the one-shot cue, but never
    // replay a warning for the window already showing.
    if (preludeEnabled != null || preludeMinutes != null) {
      _preludeAlertPlayed = isPreludeOpen;
      await refreshReminderQueue();
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
        if (_isLocalUserId(previousId)) {
          // The normal path: this device's own, never-synced history is
          // claimed by the account the user just signed in to.
          await localRepo.reassignLocalUser(previousId, accountId);
        } else {
          // Switching between two real accounts. The previous id belongs to
          // the account that just signed out, so its rows must stay under
          // that id. Reassigning here would hand the previous employee's
          // break history, streak and preferences to whoever signs in next -
          // and markAllAnalyticsAsUnsynced below would then upload it into
          // the new account and its organisation's aggregates.
          await _switchToAccountProfile(accountId, email);
          return;
        }
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

  /// Loads the incoming account's own profile, or creates a blank one.
  ///
  /// Leaves the signed-out account's rows untouched under its own id, so
  /// signing back into it restores that account's history rather than finding
  /// it overwritten.
  Future<void> _switchToAccountProfile(String accountId, String? email) async {
    final existing = await localRepo.getUserProfileById(accountId);
    _userProfile =
        existing?.copyWith(email: email ?? existing.email) ??
        UserProfile(
          id: accountId,
          name: 'Employee',
          role: 'employee',
          email: email,
        );
    await localRepo.saveUserProfile(_userProfile!);

    _preferences =
        await localRepo.getUserPreferences(accountId) ??
        UserPreferences.defaultPreferences(accountId);
    final preferences = _preferences!;
    await localRepo.saveUserPreferences(preferences);
    audioService.soundEnabled = preferences.soundEnabled;
    audioService.selectedSound = preferences.selectedSound;
    HapticsService.enabled = preferences.hapticsEnabled;

    await _restoreReminderInterval(minutes: preferences.notificationFrequency);

    _todayAnalytics = await localRepo.getAnalyticsForDate(
      accountId,
      localRepo.getTodayDateString(),
    );
    _dailyHistory = await localRepo.getAllDailyAnalytics(accountId);
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
    final userId = _userProfile?.id;
    if (userId == null) {
      _syncStatus = SyncStatus.offline;
      notifyListeners();
      return;
    }

    // Several lifecycle/auth callbacks can request a sync at once. Reuse the
    // active operation so pending rows are never raced by parallel uploads.
    final activeSync = _syncInFlight;
    if (activeSync != null) {
      final activeUserId = _syncInFlightUserId;
      await activeSync;
      // An account switch during an upload must not cause the new account's
      // sync request to disappear behind the previous account's operation.
      if (!_disposed && _userProfile?.id != activeUserId) {
        await triggerCloudSync();
      }
      return;
    }

    // Defer the body one microtask so `_syncInFlight` is assigned before its
    // initial notifyListeners() can re-enter triggerCloudSync.
    final operation = Future<void>.microtask(() => _performCloudSync(userId));
    _syncInFlight = operation;
    _syncInFlightUserId = userId;
    try {
      await operation;
    } finally {
      if (identical(_syncInFlight, operation)) {
        _syncInFlight = null;
        _syncInFlightUserId = null;
      }
    }
  }

  Future<void> _performCloudSync(String userId) async {
    if (_disposed) return;
    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    SyncStatus status;
    try {
      status = await supabaseService.syncLocalToCloud(
        userId: userId,
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
    if (_userProfile?.id != userId) status = SyncStatus.offline;
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
