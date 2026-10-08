import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? tintColor;
  final double opacity;
  final Border? border;
  final List<BoxShadow>? shadows;
  final bool reduceMotion;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius,
    this.blur = 12.0,
    this.tintColor,
    this.opacity = 0.76,
    this.border,
    this.shadows,
    this.reduceMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(22);
    final sigma = reduceMotion ? blur * 0.4 : blur;

    final defaultTint =
        tintColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? opacity.clamp(0.8, 0.92).toDouble() : 0.82,
        );

    final defaultBorder =
        border ??
        Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.86),
          width: 0.8,
        );

    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: defaultTint,
            borderRadius: r,
            border: defaultBorder,
            boxShadow:
                shadows ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.12 : 0.035,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }
}
