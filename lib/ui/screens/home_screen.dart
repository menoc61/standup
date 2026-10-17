import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_spacing.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/data/models/gamification_metrics.dart';
import 'package:standup_app/data/models/workday_metrics.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/services/guidance_provider.dart';
import 'package:standup_app/ui/layout/adaptive.dart';
import 'package:standup_app/ui/widgets/account_button.dart';
import 'package:standup_app/ui/widgets/countdown_ring.dart';
import 'package:standup_app/ui/widgets/glass_card.dart';
import 'package:standup_app/ui/widgets/guided_stretch.dart';
import 'package:standup_app/ui/widgets/particle_burst.dart';
import 'package:standup_app/ui/widgets/posture_avatar.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

// =============================================================================
// HomeScreen — a calm, editorial wellness dashboard.
// =============================================================================
class HomeScreen extends StatefulWidget {
  final AppState appState;

  final VoidCallback onRerunOnboarding;

  const HomeScreen({
    super.key,
    required this.appState,
    required this.onRerunOnboarding,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _celebrationTrigger = false;

  void _handleComplete() async {
    final accepted = await widget.appState.completeReminder();
    if (!mounted) return;
    final reason = widget.appState.lastActionRejection;

    if (accepted) {
      unawaited(HapticsService.celebration());
      setState(() => _celebrationTrigger = true);
      // Reset the trigger after the animation window.
      unawaited(
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) setState(() => _celebrationTrigger = false);
        }),
      );
      return;
    }

    // A refused action must always be visible and explained. Silent no-ops
    // read as a broken button.
    unawaited(HapticsService.light());
    _toast(
      reason ?? appString(context, 'Not inside the movement window'),
      icon: Icons.info_outline,
    );
  }

  /// Shows a short, non-blocking message. Uses a snackbar so it works on every
  /// platform without needing a custom overlay.
  void _toast(String message, {IconData icon = Icons.info_outline}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: AppSpace.lg),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  void _showGuidedStretchDialog(BuildContext context) {
    HapticsService.medium();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GuidedStretchSheet(appState: widget.appState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = AppColors.getAccentColor(
      widget.appState.preferences.colorSystem,
    );
    final user = widget.appState.userProfile;
    final today = widget.appState.todayAnalytics;
    // The alert means "your break window is open, go now", so it belongs to the
    // window being open rather than to the countdown having run out.
    // remainingDuration counts down to the window's CLOSING instant, so it
    // reached zero only AFTER the break had expired - the one moment the action
    // is refused. That made the app announce "It's time to stand up! Your body
    // will thank you." exactly when the user could no longer log a stand-up.
    final isAlert = widget.appState.isActionWindowOpen;
    return Scaffold(
      // Let the paper-toned canvas sit behind the dashboard panels.
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // A quiet paper-and-ink canvas with a single botanical wash.
          CustomPaint(
            painter: _CalmCanvasPainter(accent: accent, isDark: isDark),
            size: Size.infinite,
          ),

          // ── Main scrollable content ────────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The shell's sidebar consumes space on desktop, so choose the
                // dashboard layout from the actual content width, not the
                // physical monitor width. The breakpoint comes from
                // lib/ui/layout/adaptive.dart so it cannot drift from the one the
                // shell uses to decide between a sidebar and a bottom bar.
                final useTwoColumnLayout =
                    windowClassOf(constraints) == WindowClass.expanded;
                return constrainContent(
                  useTwoColumnLayout
                      ? _buildDesktopLayout(
                          context,
                          theme,
                          isDark,
                          accent,
                          user,
                          today,
                          isAlert,
                        )
                      : _buildMobileLayout(
                          context,
                          theme,
                          isDark,
                          accent,
                          user,
                          today,
                          isAlert,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile Layout — full-bleed immersive glass panels
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Color accent,
    user,
    today,
    bool isAlert,
  ) {
    final guidance = widget.appState.personalGuidance;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.md,
            AppSpace.xl,
            AppSpace.xs,
          ),
          child: _buildProfileNotificationHeader(context, theme, accent),
        ).animate().fadeIn(duration: 450.ms).slideY(begin: -0.12),

        // Scrollable body — pull down to sync with Supabase.
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => widget.appState.triggerCloudSync(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                18,
                AppSpace.md,
                18,
                AppSpace.section,
              ),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  _buildGreeting(context, theme, accent, user)
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 500.ms)
                      .slideX(begin: -0.15),

                  const SizedBox(height: AppSpace.xxl),

                  // Level & daily-goal strip
                  _buildProgressStrip(theme, accent)
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 500.ms)
                      .slideY(begin: 0.1),

                  const SizedBox(height: AppSpace.xxl),

                  // Posture card — glassmorphism
                  _buildPostureCard(theme, isDark, accent)
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 500.ms)
                      .slideY(begin: 0.15),

                  const SizedBox(height: AppSpace.huge),

                  // Countdown ring — centred, particle burst wrapper
                  Center(
                    child: ParticleBurst(
                      accentColor: accent,
                      trigger: _celebrationTrigger,
                      child: CountdownRing(
                        remainingTime: widget.appState.remainingDuration,
                        progress: widget.appState.timerProgress,
                        accentColor: accent,
                        isBreakActive: widget.appState.isBreakActive,
                        size: 230,
                      ),
                    ),
                  ).animate().scale(
                    delay: 300.ms,
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  ),

                  const SizedBox(height: AppSpace.section),

                  // Action buttons
                  _buildActionRow(context, isDark, accent)
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 400.ms)
                      .slideY(begin: 0.2),

                  const SizedBox(height: AppSpace.xl),

                  // Guided stretch button
                  _buildStretchButton(
                    context,
                    accent,
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                  const SizedBox(height: AppSpace.huge),

                  // Today summary card — glass
                  _buildSummaryCard(theme, isDark, accent, today)
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 500.ms)
                      .slideY(begin: 0.1),

                  if (guidance != null ||
                      widget.appState.isAiGuidanceOptedIn) ...[
                    const SizedBox(height: AppSpace.xl),
                    _buildGuidanceCard(context, theme, accent, guidance),
                  ],

                  // Alert nudge badge when overdue
                  if (isAlert) ...[
                    const SizedBox(height: AppSpace.xl),
                    // The shimmer is an unbounded repeat loop. Honour the
                    // platform reduced-motion signal so it cannot run forever
                    // for a user who has asked for less motion.
                    if (MediaQuery.disableAnimationsOf(context))
                      _buildAlertBadge(accent)
                    else
                      _buildAlertBadge(accent)
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .shimmer(
                            duration: 1200.ms,
                            color: accent.withValues(alpha: 0.3),
                          ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileNotificationHeader(
    BuildContext context,
    ThemeData theme,
    Color accent,
  ) {
    final user = widget.appState.userProfile;
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : appString(context, 'Your account');
    final windowOpen = widget.appState.isActionWindowOpen;
    final remaining = formatClock(
      windowOpen
          ? widget.appState.windowTimeRemaining
          : widget.appState.timeUntilNextWindow,
    );

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: Row(
        children: [
          AccountButton(
            appState: widget.appState,
            onRerunOnboarding: widget.onRerunOnboarding,
            size: 46,
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  appString(context, 'Profile and reminders'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          // Quiet mode is the one control the user reaches for *during* an
          // interruption ("I am about to share my screen"), so it lives on the
          // dashboard rather than two screens deep in Settings.
          IconButton(
            onPressed: () =>
                widget.appState.setQuietMode(!widget.appState.isQuietMode),
            tooltip: appString(
              context,
              widget.appState.isQuietMode
                  ? 'Resume reminders'
                  : 'Pause reminders',
            ),
            icon: Icon(
              widget.appState.isQuietMode
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_active_outlined,
              color: widget.appState.isQuietMode
                  ? theme.colorScheme.onSurfaceVariant
                  : accent,
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  appString(
                    context,
                    windowOpen ? 'WINDOW CLOSES IN' : 'NEXT WINDOW IN',
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  remaining,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact level + daily-goal strip. Gives the Duolingo-style sense of
  /// progress right on the dashboard instead of hiding it in another tab.
  Widget _buildProgressStrip(ThemeData theme, Color accent) {
    final prefs = widget.appState.preferences;
    final today = widget.appState.todayAnalytics;
    final history = widget.appState.dailyHistory;
    final totalXp = GamificationMetrics.totalXp(history);
    final level = GamificationMetrics.levelFor(totalXp);
    final levelProgress = GamificationMetrics.levelProgress(totalXp);
    final streak = WorkdayMetrics.currentStreak(history, DateTime.now());
    final goalProgress = GamificationMetrics.dailyGoalProgress(
      today,
      prefs.streakGoal,
    );

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xxl,
        vertical: AppSpace.xl,
      ),
      child: Row(
        children: [
          // Level badge
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              border: Border.all(
                color: accent.withValues(alpha: 0.5),
                width: AppSpace.xxs,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      appString(context, 'Level'),
                      style: const TextStyle(
                        fontSize: AppFontSize.footnote,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$totalXp ${appString(context, 'XP')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: levelProgress <= 0 ? 0.001 : levelProgress,
                    minHeight: 7,
                    backgroundColor: accent.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.xl),
          // Daily goal + streak
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: AppSpace.xxl,
                    color: streak > 0
                        ? Colors.orange.shade700
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontSize: AppFontSize.small,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              SizedBox(
                width: 54,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: goalProgress <= 0 ? 0.001 : goalProgress,
                    minHeight: 7,
                    backgroundColor: accent.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation(
                      accent.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Layout — wider, centered ring with side panel
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Color accent,
    user,
    today,
    bool isAlert,
  ) {
    final guidance = widget.appState.personalGuidance;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left panel: ring + buttons
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _buildProfileNotificationHeader(context, theme, accent),
                const SizedBox(height: AppSpace.xl),
                // Greeting
                _buildGreeting(
                  context,
                  theme,
                  accent,
                  user,
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: AppSpace.section),

                // Ring with particles
                Center(
                  child: ParticleBurst(
                    accentColor: accent,
                    trigger: _celebrationTrigger,
                    child: CountdownRing(
                      remainingTime: widget.appState.remainingDuration,
                      progress: widget.appState.timerProgress,
                      accentColor: accent,
                      isBreakActive: widget.appState.isBreakActive,
                      size: 280,
                    ),
                  ),
                ).animate().scale(duration: 700.ms, curve: Curves.easeOutBack),

                const SizedBox(height: AppSpace.gutter),
                _buildActionRow(
                  context,
                  isDark,
                  accent,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: AppSpace.xl),
                _buildStretchButton(
                  context,
                  accent,
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),

          const SizedBox(width: AppSpace.gutter),

          // Right panel: posture card + summary
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildPostureCard(
                  theme,
                  isDark,
                  accent,
                ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.15),
                const SizedBox(height: AppSpace.huge),
                _buildSummaryCard(
                  theme,
                  isDark,
                  accent,
                  today,
                ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.15),
                if (guidance != null ||
                    widget.appState.isAiGuidanceOptedIn) ...[
                  const SizedBox(height: AppSpace.xl),
                  _buildGuidanceCard(context, theme, accent, guidance),
                ],
                if (isAlert) ...[
                  const SizedBox(height: AppSpace.xl),
                  _buildAlertBadge(accent),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildGreeting(
    BuildContext context,
    ThemeData theme,
    Color accent,
    user,
  ) {
    final name = user?.name.split(' ').first ?? 'CNPS';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appString(context, greeting).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontSize: AppFontSize.micro,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              '${user?.designation ?? appString(context, 'Team Member')} · ${user?.department ?? appString(context, 'General')}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: AppFontSize.footnote,
              ),
            ),
          ],
        ),
        if (user?.organizationName != null)
          _OrgPill(name: user!.organizationName!, accent: accent),
      ],
    );
  }

  Widget _buildPostureCard(ThemeData theme, bool isDark, Color accent) {
    final isAlert = widget.appState.isActionWindowOpen;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.xxl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    appString(context, 'A MOMENT TO RESET'),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  appString(
                    context,
                    isAlert
                        ? 'Time for a movement break'
                        : 'Take a posture moment',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  appString(
                    context,
                    isAlert
                        ? '5 minutes of movement restores spinal fluids and reduces fatigue.'
                        : 'Let your shoulders soften and your spine settle comfortably.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: AppFontSize.caption,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          PostureAvatar(
            isStanding: isAlert,
            stretchProgress: isAlert ? 0.9 : 0.2,
            accentColor: accent,
            size: 90,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, bool isDark, Color accent) {
    final windowOpen = widget.appState.isActionWindowOpen;
    return Column(
      children: [
        _buildWindowBanner(context, accent, windowOpen),
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Opacity(
                // Outside the window the primary action is visibly unavailable
                // rather than failing silently on tap.
                opacity: windowOpen ? 1 : 0.45,
                child: SpringButton(
                  onTap: _handleComplete,
                  backgroundColor: AppColors.completed,
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.accessibility_new, size: 18),
                      const SizedBox(width: AppSpace.sm),
                      // Flexible, not a bare Text: this row is a flex-4 share
                      // of a phone's width, and the French label ("Je me suis
                      // levé·e !") is far longer than the English one.
                      Flexible(
                        child: Text(
                          appString(context, 'I Stood Up!'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              flex: 3,
              child: SpringButton(
                onTap: () {
                  unawaited(HapticsService.medium());
                  unawaited(widget.appState.snoozeReminder());
                },
                backgroundColor: isDark
                    ? const Color(0xFF2D2517)
                    : const Color(0xFFFEF3C7),
                foregroundColor: AppColors.snoozed,
                border: Border.all(
                  color: AppColors.snoozed.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.snooze, size: AppSpace.xxl),
                    const SizedBox(width: AppSpace.xs),
                    Flexible(
                      child: Text(
                        appString(context, 'Next reminder'),
                        style: const TextStyle(fontSize: AppFontSize.small),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              flex: 2,
              child: SpringButton(
                onTap: () {
                  unawaited(HapticsService.light());
                  unawaited(widget.appState.skipReminder());
                },
                backgroundColor: isDark
                    ? const Color(0xFF2A1719)
                    : const Color(0xFFFFE4E6),
                foregroundColor: AppColors.skipped,
                border: Border.all(
                  color: AppColors.skipped.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
                child: Center(
                  child: Text(
                    appString(context, 'Skip'),
                    style: const TextStyle(fontSize: AppFontSize.small),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Always-visible explanation of the action-window rule. Users must be able to
  /// see why a button is disabled without trial and error.
  Widget _buildWindowBanner(BuildContext context, Color accent, bool isOpen) {
    final state = widget.appState;
    final theme = Theme.of(context);
    // The cut-off is a third state, not "closed": without it the banner counts
    // down to tomorrow's first window while the app refuses to open one, which
    // reads as a bug rather than as a setting the user chose.
    final cutOffReached = !isOpen && state.isDailyLimitReached;
    final label = isOpen
        ? appString(context, 'Movement window open')
        : cutOffReached
        ? appString(context, 'Breaks have stopped for today')
        : appString(context, 'Next movement window');
    final countdown = isOpen
        ? formatClock(state.windowTimeRemaining)
        : formatClock(state.timeUntilNextWindow);
    final detail = isOpen
        ? appString(context, 'Log your stand-up before the window closes')
        : cutOffReached
        ? appString(context, 'Reminders resume on your next work day.')
        : appString(
            context,
            'A break only counts in the last minutes of each hour',
          );

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xxl,
        vertical: AppSpace.xl,
      ),
      tintColor: isOpen ? accent.withValues(alpha: 0.12) : null,
      border: Border.all(
        color: isOpen
            ? accent.withValues(alpha: 0.4)
            : theme.colorScheme.outlineVariant,
      ),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.check_circle_rounded : Icons.schedule_rounded,
            color: isOpen ? accent : theme.colorScheme.onSurfaceVariant,
            size: AppSpace.huge,
          ),
          const SizedBox(width: AppSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: AppFontSize.small,
                  ),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          if (!cutOffReached)
            Text(
              countdown,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: AppFontSize.label,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isOpen ? accent : theme.colorScheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStretchButton(BuildContext context, Color accent) {
    return SpringButton(
      onTap: () => _showGuidedStretchDialog(context),
      backgroundColor: accent.withValues(alpha: 0.12),
      foregroundColor: accent,
      border: Border.all(color: accent.withValues(alpha: 0.3)),
      isFullWidth: true,
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: AppSpace.xxl),
          const SizedBox(width: AppSpace.md),
          // The longest label in the app in French
          // ("Commencer les étirements guidés (5 min)"), and it overflows even
          // in English at 320px without a flex constraint.
          Flexible(
            child: Text(
              appString(context, 'Start 5-Min Guided Stretch Routine'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard(
    BuildContext context,
    ThemeData theme,
    Color accent,
    GuidanceResult? guidance,
  ) {
    final completed = widget.appState.todayAnalytics.remindersCompleted;
    final goal = widget.appState.preferences.streakGoal;
    final titleKey = guidance == null
        ? 'Personal wellness guidance'
        : switch (guidance.kind) {
            GuidanceKind.takeShortMovementBreak =>
              'A short movement break may help',
            GuidanceKind.adjustReminderCadence =>
              'Try a gentler reminder cadence',
            GuidanceKind.celebrate =>
              guidance.reason == GuidanceReason.goalProgress
                  ? 'Daily movement goal reached'
                  : 'Nice consistency today',
          };
    final detail = guidance == null
        ? appString(
            context,
            'Ask the company AI for one suggestion based on your daily summary.',
          )
        : switch (guidance.reason) {
            GuidanceReason.goalProgress =>
              guidance.kind == GuidanceKind.celebrate
                  ? appString(
                      context,
                      'You have reached your daily movement goal.',
                    )
                  : '$completed / $goal ${appString(context, 'breaks')} today',
            GuidanceReason.repeatedSnoozes => appString(
              context,
              'Several reminders were postponed or skipped today.',
            ),
            GuidanceReason.consistentActivity => appString(
              context,
              'You have completed several breaks today.',
            ),
            GuidanceReason.noActivityYet => appString(
              context,
              'No break is recorded yet today.',
            ),
            GuidanceReason.feedbackTooFrequent => appString(
              context,
              'You told us these suggestions come too often.',
            ),
          };
    final suggestionKey = guidance == null
        ? null
        : switch (guidance.kind) {
            GuidanceKind.takeShortMovementBreak =>
              'Take a short movement break when your next window opens.',
            GuidanceKind.adjustReminderCadence => 'If reminders feel too frequent, try a longer interval in Settings.',
            GuidanceKind.celebrate =>
              'Your steady movement is building a healthy rhythm.',
          };
    final icon = switch (guidance?.kind) {
      GuidanceKind.takeShortMovementBreak => Icons.directions_walk_outlined,
      GuidanceKind.adjustReminderCadence => Icons.schedule_outlined,
      GuidanceKind.celebrate => Icons.celebration_outlined,
      null => Icons.auto_awesome_outlined,
    };

    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.xl),
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  appString(context, titleKey),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(detail, style: theme.textTheme.bodyMedium),
          if (guidance != null)
            Text(
              appString(
                context,
                widget.appState.hasAiGuidanceResult
                    ? 'Company AI guidance'
                    : 'Local guidance',
              ),
              style: theme.textTheme.labelSmall,
            ),
          const SizedBox(height: AppSpace.xs),
          if (suggestionKey != null)
            Text(
              appString(context, suggestionKey),
              style: theme.textTheme.bodySmall,
            ),
          if (widget.appState.isAiGuidanceOptedIn) ...[
            const SizedBox(height: AppSpace.sm),
            TextButton.icon(
              onPressed:
                  widget.appState.isAiGuidanceLoading ||
                      !widget.appState.canRequestAiGuidance
                  ? null
                  : widget.appState.requestAiGuidance,
              icon: widget.appState.isAiGuidanceLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined, size: 17),
              label: Text(
                appString(
                  context,
                  widget.appState.isAiGuidanceLoading
                      ? 'Asking company AI…'
                      : 'Ask company AI',
                ),
              ),
            ),
            if (!widget.appState.canRequestAiGuidance &&
                !widget.appState.isAiGuidanceLoading)
              Text(
                appString(context, 'Sign in to request company AI guidance.'),
                style: theme.textTheme.bodySmall,
              ),
            if (widget.appState.aiGuidanceUnavailable)
              Text(
                appString(
                  context,
                  'Company AI is unavailable. Showing local guidance.',
                ),
                style: theme.textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              TextButton.icon(
                onPressed: () => widget.appState.recordGuidanceFeedback(
                  GuidanceFeedback.suggestionsHelpful,
                ),
                icon: const Icon(Icons.thumb_up_outlined, size: 16),
                label: Text(appString(context, 'Helpful')),
              ),
              TextButton.icon(
                onPressed: () => widget.appState.recordGuidanceFeedback(
                  GuidanceFeedback.suggestionsTooFrequent,
                ),
                icon: const Icon(Icons.notifications_off_outlined, size: 16),
                label: Text(appString(context, 'Too frequent')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, bool isDark, Color accent, today) {
    final targetMinutes = WorkdayMetrics.standTargetMinutes(
      widget.appState.preferences.notificationFrequency,
    );
    final goalProgress = WorkdayMetrics.targetProgress(
      today.totalStandTime,
      targetMinutes,
    );

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                appString(context, "Today's Activity"),
                style: theme.textTheme.titleMedium,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.completed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${today.adherenceRate.toStringAsFixed(0)}% ${appString(context, 'Completion rate')}',
                  style: const TextStyle(
                    fontSize: AppFontSize.caption,
                    fontWeight: FontWeight.bold,
                    color: AppColors.completed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xxl),
          Row(
            children: [
              _buildSummaryItem(
                label: appString(context, 'Completed'),
                value: '${today.remindersCompleted}',
                unit: appString(context, 'breaks'),
                color: AppColors.completed,
              ),
              _buildSummaryItem(
                label: appString(context, 'Stand Time'),
                value: '${today.totalStandTime}',
                unit: appString(context, 'minutes'),
                color: accent,
              ),
              _buildSummaryItem(
                label: appString(context, 'Snoozed'),
                value: '${today.remindersSnoozed}',
                unit: appString(context, 'times'),
                color: AppColors.snoozed,
              ),
              _buildSummaryItem(
                label: appString(context, 'Skipped'),
                value: '${today.remindersSkipped}',
                unit: appString(context, 'times'),
                color: AppColors.skipped,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${today.totalStandTime} / $targetMinutes ${appString(context, 'minutes')} · ${appString(context, '8-hour workday target')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(goalProgress * 100).round()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: goalProgress,
              minHeight: 7,
              backgroundColor: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBadge(Color accent) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xxl,
        vertical: AppSpace.xl,
      ),
      tintColor: accent.withValues(alpha: 0.15),
      border: Border.all(color: accent.withValues(alpha: 0.4)),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_rounded,
            color: accent,
            size: AppSpace.huge,
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Text(
              appString(
                context,
                'It\'s time to stand up! Your body will thank you.',
              ),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: AppFontSize.small,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppFontSize.caption,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Org pill chip
// =============================================================================
class _OrgPill extends StatelessWidget {
  final String name;
  final Color accent;
  const _OrgPill({required this.name, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business, color: accent, size: 14),
          const SizedBox(width: AppSpace.sm),
          Text(
            name,
            style: TextStyle(
              fontSize: AppFontSize.caption,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Restrained botanical wash and fine orbit lines; no neon mesh or color cycling.
// =============================================================================
class _CalmCanvasPainter extends CustomPainter {
  final Color accent;
  final bool isDark;

  const _CalmCanvasPainter({required this.accent, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // No base fill here. The page colour belongs to `AppCanvas`, which every
    // screen shares; this painter only adds the accent wash that gives the
    // timer a quiet focal point. Painting a gradient here as well is what made
    // the home screen a different colour from every other screen.

    // One low-contrast wash gives the timer a quiet focal point.
    final center = Offset(size.width * 0.82, size.height * 0.18);
    final radius = math.max(size.width, size.height) * 0.46;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: isDark ? 0.055 : 0.075),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final ornament = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.07 : 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      math.pi * 0.58,
      math.pi * 0.46,
      false,
      ornament,
    );
  }

  @override
  bool shouldRepaint(_CalmCanvasPainter old) =>
      old.accent != accent || old.isDark != isDark;
}
