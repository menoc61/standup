import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';

class AppTheme {
  static ThemeData buildTheme({
    required Brightness brightness,
    required String colorSystem,
  }) {
    final isDark = brightness == Brightness.dark;
    final accent = AppColors.getAccentColor(colorSystem);
    final primary = AppColors.getPrimaryColor(colorSystem);
    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final ink = isDark ? const Color(0xFFF2F3EB) : const Color(0xFF202D25);
    final mutedInk = isDark ? const Color(0xFFAFB9AE) : const Color(0xFF647168);
    final outline = isDark ? const Color(0xFF485B4E) : const Color(0xFFD2DCD1);

    final colors =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          secondary: accent,
          onSecondary: Colors.white,
          error: AppColors.skipped,
          onError: Colors.white,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: mutedInk,
          surfaceContainerHighest: card,
          outline: outline,
          outlineVariant: border,
        );

    final baseText = Typography.material2021().black;
    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        color: ink,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.4,
      ),
      displayMedium: baseText.displayMedium?.copyWith(
        color: ink,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.0,
      ),
      // A quiet serif display paired with the platform's native sans body type
      // gives the dashboard an editorial voice without bundling font files.
      headlineLarge: baseText.headlineLarge?.copyWith(
        color: ink,
        fontFamily: 'serif',
        fontSize: 31,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.9,
        height: 1.12,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        color: ink,
        fontFamily: 'serif',
        fontSize: 23,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.55,
        height: 1.18,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        color: ink,
        fontFamily: 'serif',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.35,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        color: ink,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        color: ink,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        color: ink,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        color: ink,
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        color: mutedInk,
        fontSize: 14,
        height: 1.48,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        color: mutedInk,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        color: ink,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        color: mutedInk,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        color: mutedInk,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: colors,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: card,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border, width: 0.8),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: mutedInk, size: 20),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 0.8, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? card : const Color(0xFFF5F7F0),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: mutedInk),
        hintStyle: TextStyle(color: mutedInk.withValues(alpha: 0.78)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: accent.withValues(alpha: isDark ? 0.2 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? primary : mutedInk,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF27372D)
            : const Color(0xFF263B30),
        contentTextStyle: const TextStyle(color: Color(0xFFF7F6F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
