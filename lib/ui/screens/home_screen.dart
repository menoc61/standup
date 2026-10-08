import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/data/models/gamification_metrics.dart';
import 'package:standup_app/data/models/workday_metrics.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/ui/widgets/countdown_ring.dart';
import 'package:standup_app/ui/widgets/dynamic_island.dart';
import 'package:standup_app/ui/widgets/glass_card.dart';
import 'package:standup_app/ui/widgets/particle_burst.dart';
import 'package:standup_app/ui/widgets/posture_avatar.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

// =============================================================================
// HomeScreen — a calm, editorial wellness dashboard.
// =============================================================================
class HomeScreen extends StatefulWidget {
  final AppState appState;

  const HomeScreen({super.key, required this.appState});

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
              const SizedBox(width: 10),
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
      builder: (ctx) => _GuidedStretchSheet(appState: widget.appState),
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
    final isAlert = widget.appState.remainingDuration == Duration.zero;
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
                // physical monitor width.
                final useTwoColumnLayout = constraints.maxWidth >= 900;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1480),
                    child: useTwoColumnLayout
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
    return Column(
      children: [
        // Dynamic Island pill — always at top of safe area
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: DynamicIsland(
            remainingDuration: widget.appState.remainingDuration,
            isBreakActive: widget.appState.isBreakActive,
            accentColor: accent,
            onComplete: _handleComplete,
            onSnooze: () {
              HapticsService.medium();
              widget.appState.snoozeReminder(minutes: 10);
            },
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3),

        // Scrollable body — pull down to sync with Supabase.
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => widget.appState.triggerCloudSync(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
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

                  const SizedBox(height: 16),

                  // Level & daily-goal strip
                  _buildProgressStrip(theme, accent)
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 500.ms)
                      .slideY(begin: 0.1),

                  const SizedBox(height: 16),

                  // Posture card — glassmorphism
                  _buildPostureCard(theme, isDark, accent)
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 500.ms)
                      .slideY(begin: 0.15),

                  const SizedBox(height: 20),

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

                  const SizedBox(height: 24),

                  // Action buttons
                  _buildActionRow(context, isDark, accent)
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 400.ms)
                      .slideY(begin: 0.2),

                  const SizedBox(height: 12),

                  // Guided stretch button
                  _buildStretchButton(
                    context,
                    accent,
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                  const SizedBox(height: 20),

                  // Today summary card — glass
                  _buildSummaryCard(theme, isDark, accent, today)
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 500.ms)
                      .slideY(begin: 0.1),

                  // Alert nudge badge when overdue
                  if (isAlert) ...[
                    const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                width: 2,
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
          const SizedBox(width: 12),
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
                        fontSize: 12,
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
                const SizedBox(height: 6),
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
          const SizedBox(width: 14),
          // Daily goal + streak
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: streak > 0
                        ? Colors.orange.shade700
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left panel: ring + buttons
          Expanded(
            flex: 5,
            child: Column(
              children: [
                // Greeting
                _buildGreeting(
                  context,
                  theme,
                  accent,
                  user,
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 24),

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

                const SizedBox(height: 32),
                _buildActionRow(
                  context,
                  isDark,
                  accent,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 12),
                _buildStretchButton(
                  context,
                  accent,
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),

          const SizedBox(width: 32),

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
                const SizedBox(height: 20),
                _buildSummaryCard(
                  theme,
                  isDark,
                  accent,
                  today,
                ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.15),
                if (isAlert) ...[
                  const SizedBox(height: 12),
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
    final name = user?.name.split(' ').first ?? 'CSPH';
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
                fontSize: 10,
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
            const SizedBox(height: 2),
            Text(
              '${user?.designation ?? appString(context, 'Team Member')} · ${user?.department ?? appString(context, 'General')}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
        if (user?.organizationName != null)
          _OrgPill(name: user!.organizationName!, accent: accent),
      ],
    );
  }

  Widget _buildPostureCard(ThemeData theme, bool isDark, Color accent) {
    final isAlert = widget.appState.remainingDuration == Duration.zero;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 8),
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
                const SizedBox(height: 4),
                Text(
                  appString(
                    context,
                    isAlert
                        ? '5 minutes of movement restores spinal fluids and reduces fatigue.'
                        : 'Let your shoulders soften and your spine settle comfortably.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
        const SizedBox(height: 12),
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.accessibility_new, size: 18),
                      SizedBox(width: 6),
                      Text(appString(context, 'I Stood Up!')),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: SpringButton(
                onTap: () {
                  unawaited(HapticsService.medium());
                  unawaited(widget.appState.snoozeReminder(minutes: 10));
                },
                backgroundColor: isDark
                    ? const Color(0xFF2D2517)
                    : const Color(0xFFFEF3C7),
                foregroundColor: AppColors.snoozed,
                border: Border.all(
                  color: AppColors.snoozed.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.snooze, size: 16),
                    SizedBox(width: 4),
                    Text(
                      appString(context, 'Snooze 10m'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    appString(context, 'Skip'),
                    style: const TextStyle(fontSize: 13),
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
    final label = isOpen
        ? appString(context, 'Movement window open')
        : appString(context, 'Next movement window');
    final countdown = isOpen
        ? _formatDuration(state.windowTimeRemaining)
        : _formatDuration(state.timeUntilNextWindow);
    final detail = isOpen
        ? appString(context, 'Log your stand-up before the window closes')
        : appString(
            context,
            'A break only counts in the last minutes of each hour',
          );

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            countdown,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isOpen ? accent : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final restMinutes = minutes % 60;
      return restMinutes == 0
          ? '${hours}h'
          : '${hours}h${restMinutes.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
          Icon(Icons.fitness_center, size: 16),
          SizedBox(width: 8),
          Text(appString(context, 'Start 5-Min Guided Stretch Routine')),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.completed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${today.adherenceRate.toStringAsFixed(0)}% ${appString(context, 'Adherence')}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.completed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 14),
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
            borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      tintColor: accent.withValues(alpha: 0.15),
      border: Border.all(color: accent.withValues(alpha: 0.4)),
      child: Row(
        children: [
          Icon(Icons.notifications_active_rounded, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appString(
                context,
                'It\'s time to stand up! Your body will thank you.',
              ),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(unit, style: const TextStyle(fontSize: 9, color: Colors.grey)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business, color: accent, size: 14),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
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
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF141A17), Color(0xFF171F1B)]
              : const [Color(0xFFF3F0E7), Color(0xFFEDECE3)],
        ).createShader(bounds),
    );

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

// =============================================================================
// Guided Desk Stretch Bottom Sheet
// =============================================================================
class _GuidedStretchSheet extends StatefulWidget {
  final AppState appState;

  const _GuidedStretchSheet({required this.appState});

  @override
  State<_GuidedStretchSheet> createState() => _GuidedStretchSheetState();
}

class _GuidedStretchSheetState extends State<_GuidedStretchSheet> {
  // Stored as English source strings and translated at render time so the whole
  // routine switches language with the rest of the interface.
  final List<Map<String, String>> _stretches = [
    {
      'title': '1. Overhead Reach & Spinal Stretch',
      'instruction': 'Interlace fingers, reach palms upward towards ceiling, lengthen spine and breathe deeply for 60 seconds.',
    },
    {
      'title': '2. Chest Opener & Shoulder Retraction',
      'instruction': 'Clasp hands behind lower back, pull shoulders down and back, lift chin gently, expanding lungs.',
    },
    {
      'title': '3. Standing Quad & Hip Flexor Stretch',
      'instruction': 'Hold desk for balance, grasp right ankle behind you for 30s, then switch to left ankle.',
    },
    {
      'title': '4. Standing Calf Raises',
      'instruction': 'Slowly rise onto balls of both feet, hold 2 seconds, lower slowly. Repeat 15 times.',
    },
    {
      'title': '5. Gentle Torso Twists',
      'instruction': 'With feet shoulder-width apart, gently rotate torso left and right with arms relaxed.',
    },
  ];

  @override
  void initState() {
    super.initState();
    widget.appState.startGuidedStretch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = AppColors.getAccentColor(
      widget.appState.preferences.colorSystem,
    );
    final step = widget.appState.activeBreakStep.clamp(
      0,
      _stretches.length - 1,
    );
    final current = _stretches[step];
    final remaining = widget.appState.breakSecondsRemaining;
    final mins = remaining ~/ 60;
    final secs = remaining % 60;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.80),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1.2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    appString(context, '5-Min Guided Stretch'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accent,
                        fontSize: 15,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Step progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_stretches.length, (i) {
                  final active = i == step;
                  final done = i < step;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: done
                          ? AppColors.completed
                          : active
                          ? accent
                          : Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Center(
                      child: PostureAvatar(
                        isStanding: true,
                        stretchProgress: 0.35 + step * 0.1,
                        accentColor: accent,
                        size: 92,
                      ),
                    ),
                  )
                  .animate(key: ValueKey(step))
                  .scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 12),
              Text(
                appString(context, current['title']!),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate(key: ValueKey('$step-title')).fadeIn(duration: 300.ms),
              const SizedBox(height: 8),
              Text(
                    appString(context, current['instruction']!),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    textAlign: TextAlign.center,
                  )
                  .animate(key: ValueKey('$step-body'))
                  .fadeIn(delay: 100.ms, duration: 300.ms),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: SpringButton(
                      onTap: () {
                        HapticsService.celebration();
                        widget.appState.completeReminder();
                        Navigator.of(context).pop();
                      },
                      backgroundColor: AppColors.completed,
                      child: Text(appString(context, 'Finish & Log Stand')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SpringButton(
                    onTap: () {
                      HapticsService.light();
                      widget.appState.cancelGuidedStretch();
                      Navigator.of(context).pop();
                    },
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    foregroundColor: theme.textTheme.bodyLarge?.color,
                    child: Text(appString(context, 'Cancel')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
