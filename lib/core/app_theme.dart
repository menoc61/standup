import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/platform_motion.dart';

/// Accent roles that a [ColorScheme] does not have a slot for.
///
/// A [ColorScheme] carries one `primary`, which is a *fill* colour. Using it for
/// a label produced text that failed contrast on the dark surface, so the
/// text-safe variant travelled separately. Putting it on the theme means a
/// widget reads `context.accentText` instead of re-deriving the right value for
/// the current brightness and accent.
@immutable
class AccentTheme extends ThemeExtension<AccentTheme> {
  /// Fill and icon variant.
  final Color accent;

  /// Variant that is legal as body text on the current surface.
  final Color accentText;

  /// Placeholder and disabled text.
  final Color faint;

  const AccentTheme({
    required this.accent,
    required this.accentText,
    required this.faint,
  });

  /// Reads the accent roles from [context], or a neutral fallback if absent.
  ///
  /// The fallback matters: a widget rendered outside the app's `Theme` — in a
  /// test, or inside a `Navigator` carrying an unrelated theme — should degrade
  /// to plain ink rather than throw.
  static AccentTheme of(BuildContext context) {
    return Theme.of(context).extension<AccentTheme>() ??
        const AccentTheme(
          accent: AppColors.brand,
          accentText: AppColors.brand,
          faint: AppColors.inkFaint,
        );
  }

  @override
  AccentTheme copyWith({Color? accent, Color? accentText, Color? faint}) {
    return AccentTheme(
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      faint: faint ?? this.faint,
    );
  }

  @override
  AccentTheme lerp(ThemeExtension<AccentTheme>? other, double t) {
    if (other is! AccentTheme) return this;
    return AccentTheme(
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
    );
  }
}

/// Builds the app's light and dark themes.
///
/// [colorSystem] selects the accent; see `AppColors.accents` for the options and
/// the default. The accent is the only coloured element — surfaces are
/// monochrome so that intent, not decoration, carries the hue.
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

    // Every ink, muted-ink and outline value comes from the palette rather than
    // being written inline. An earlier version hardcoded slightly green-tinted
    // greys here (#202D25, #647168, #D2DCD1 ...), and that is precisely why the
    // app kept reading as green no matter which accent was selected: the accent
    // never applied to the text, only to the fills. Contrast for each of these
    // is asserted in test/contrast_test.dart.
    final ink = isDark ? AppColors.inkOnDark : AppColors.ink;
    final mutedInk = isDark ? AppColors.inkMutedOnDark : AppColors.inkMuted;
    final faintInk = isDark ? AppColors.inkMutedOnDark : AppColors.inkFaint;
    final outline = border;

    // Control borders need 3:1 against their own fill (WCAG 1.4.11). The
    // general `border` token is deliberately softer for decorative hairlines.
    final inputBorder = isDark
        ? AppColors.darkBorderStrong
        : AppColors.lightBorderStrong;

    // On dark surfaces the accent needs its brightened variant to stay legible;
    // the light-mode value measures only 4.07:1 on near-black.
    final accentOnSurface = isDark
        ? AppColors.getAccentOnDark(colorSystem)
        : AppColors.getAccentTextColor(colorSystem);

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
      // The accent applied to text — section labels, the active tab, link copy.
      // Exposed on the theme so widgets stop reaching for `AppColors` directly
      // and picking the fill variant, which is not always legal as body text.
      extensions: <ThemeExtension<dynamic>>[
        AccentTheme(
          accent: accent,
          accentText: accentOnSurface,
          faint: faintInk,
        ),
      ],
      // Adds a slight scale and fade on top of the default page slide so a
      // step feels replaced rather than merely translated. Platform-aware and
      // reduced-motion aware; see core/platform_motion.dart.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PlatformPageTransition(),
          TargetPlatform.iOS: PlatformPageTransition(),
          TargetPlatform.macOS: PlatformPageTransition(),
          TargetPlatform.linux: PlatformPageTransition(),
          TargetPlatform.windows: PlatformPageTransition(),
        },
      ),
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
        // A visible 3:1 boundary is required by WCAG 1.4.11 for the edge of an
        // interactive control. The previous near-white fill behind a near-white
        // border measured 1.08:1, which left every text field looking borderless
        // in light mode.
        filled: true,
        // Neutral, near-white fill. The old #F6F8F6 was faintly green and
        // reinforced the tinted look the rebrand removed.
        fillColor: isDark ? card : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: mutedInk),
        hintStyle: TextStyle(color: mutedInk.withValues(alpha: 0.78)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: inputBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: inputBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.skipped, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.skipped, width: 2),
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
        // The snackbar is an interruption, so it inverts the surface rather than
        // tinting it. The old greens (#27372D / #263B30) are gone; using the
        // near-black ink keeps the one place that *should* be loud monochrome.
        backgroundColor: isDark ? AppColors.inkOnDark : AppColors.ink,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.darkBackground : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
