import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/services/haptics_service.dart';

class DynamicIsland extends StatefulWidget {
  final Duration remainingDuration;
  final bool isBreakActive;
  final Color accentColor;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;

  const DynamicIsland({
    super.key,
    required this.remainingDuration,
    required this.isBreakActive,
    required this.accentColor,
    required this.onComplete,
    required this.onSnooze,
  });

  @override
  State<DynamicIsland> createState() => _DynamicIslandState();
}

class _DynamicIslandState extends State<DynamicIsland>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    // The wave bars are only painted in the expanded layout, so the controller
    // stays stopped until the island is actually opened.
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWavePlayback();
  }

  @override
  void didUpdateWidget(covariant DynamicIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWavePlayback();
  }

  void _syncWavePlayback() {
    final expanded =
        _isExpanded ||
        widget.remainingDuration == Duration.zero ||
        widget.isBreakActive;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (expanded && !reduceMotion && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!expanded && _waveController.isAnimating) {
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _toggleExpanded() {
    HapticsService.light();
    setState(() => _isExpanded = !_isExpanded);
    _syncWavePlayback();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlert =
        widget.remainingDuration == Duration.zero || widget.isBreakActive;
    final expanded = _isExpanded || isAlert;
    // Never exceed the available width: a fixed 340 overflows on small phones.
    final available = MediaQuery.sizeOf(context).width - 32;
    final expandedWidth = available.clamp(180.0, 340.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Center(
      child: GestureDetector(
        onTap: _toggleExpanded,
        child: AnimatedContainer(
          // This is the largest single motion event in the app (height 40 to 96
          // with an overshoot curve), so it must honour reduced motion.
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 380),
          curve: reduceMotion ? Curves.linear : Curves.easeOutBack,
          height: expanded ? 96 : 40,
          width: expanded ? expandedWidth : 220,
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 16 : 12,
            vertical: expanded ? 12 : 6,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(expanded ? 22 : 14),
            border: Border.all(
              color: isAlert
                  ? widget.accentColor.withValues(alpha: 0.6)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              width: isAlert ? 1.2 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              if (isAlert)
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.14),
                  blurRadius: 12,
                ),
            ],
          ),
          child: expanded ? _buildExpandedContent() : _buildCompactContent(),
        ),
      ),
    );
  }

  Widget _buildCompactContent() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Breathing Aura Dot
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.accentColor,
                shape: BoxShape.circle,
                // A simple indicator reads clearly without a neon halo.
              ),
            ),
            const SizedBox(width: 8),
            Text(
              appString(context, 'StandUp'),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        // Right: Formatted Timer
        Text(
          _formatDuration(widget.remainingDuration),
          style: TextStyle(
            color: widget.accentColor,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent() {
    final theme = Theme.of(context);
    final isAlert = widget.remainingDuration == Duration.zero;

    return Row(
      children: [
        // Left avatar or stretch icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.accentColor.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isBreakActive
                ? Icons.fitness_center
                : Icons.accessibility_new,
            color: widget.accentColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        // Center text & Audio Wave Bars
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    isAlert ? 'Time to Stand Up!' : 'Focus Cadence',
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  // Animated sound waves
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(4, (i) {
                          final h =
                              6 +
                              (math
                                      .sin(
                                        (_waveController.value * 2 * math.pi) +
                                            (i * 0.8),
                                      )
                                      .abs() *
                                  10);
                          return Container(
                            margin: const EdgeInsets.only(right: 2),
                            width: 2.5,
                            height: h,
                            decoration: BoxDecoration(
                              color: widget.accentColor,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isAlert
                    ? '5-minute posture reset ready'
                    : '${_formatDuration(widget.remainingDuration)} until break',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        // Right quick buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                HapticsService.celebration();
                widget.onComplete();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.completed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Stand',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                HapticsService.medium();
                widget.onSnooze();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.snooze,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
