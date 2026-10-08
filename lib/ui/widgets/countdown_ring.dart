import 'dart:math' as math;

import 'package:flutter/material.dart';

class CountdownRing extends StatelessWidget {
  final Duration remainingTime;
  final double progress; // 0.0 to 1.0
  final Color accentColor;
  final bool isBreakActive;
  final double size;

  const CountdownRing({
    super.key,
    required this.remainingTime,
    required this.progress,
    required this.accentColor,
    this.isBreakActive = false,
    this.size = 240,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circular Ring Painter
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: progress,
                accentColor: accentColor,
                trackColor: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.48,
                ),
                strokeWidth: 14.0,
                isBreakActive: isBreakActive,
              ),
            ),
            // Central Info
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isBreakActive
                        ? accentColor.withValues(alpha: 0.14)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isBreakActive ? "BREAK IN PROGRESS" : "FOCUS CADENCE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isBreakActive
                              ? accentColor
                              : theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Timer
                Text(
                  _formatDuration(remainingTime),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBreakActive ? "Movement Time" : "until next 5-min stand",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final Color trackColor;
  final double strokeWidth;
  final bool isBreakActive;

  _RingPainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
    required this.strokeWidth,
    required this.isBreakActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Active Arc
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    final arcPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );

    // Small matte progress marker, tuned for both light and dark themes.
    if (progress > 0.02) {
      final angle = -math.pi / 2 + sweepAngle;
      final bx = center.dx + radius * math.cos(angle);
      final by = center.dy + radius * math.sin(angle);

      canvas.drawCircle(
        Offset(bx, by),
        strokeWidth * 0.32,
        Paint()..color = accentColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isBreakActive != isBreakActive;
  }
}
