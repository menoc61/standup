import 'package:flutter/material.dart';

/// The StandUp palette.
///
/// ## Where these values come from
///
/// The two brand constants are sampled directly from
/// `assets/branding/csph_standup_logo.png`, where `STAND` is silver and `UP` is
/// crimson. Everything else is derived from those two plus a neutral ink ramp,
/// which is why the app still reads as the same product as the logo without the
/// screen being *tinted* green.
///
/// ## Monochrome by default
///
/// Surfaces are black and white. Colour is a single accent, reserved for the
/// things that are actionable: the primary action, the active tab, the
/// completion moment. Spending accent on decoration is what made earlier
/// versions feel busy, so surfaces stay neutral and only intent carries hue.
///
/// ## Contrast
///
/// The ratios in the comments are measured, not estimated, and
/// `test/contrast_test.dart` re-derives them so a careless edit cannot quietly
/// break WCAG. Two rules follow from that:
///
///  * An accent used as *text* must clear 4.5:1 against its surface. That is why
///    there is a separate `_Text` variant per accent.
///  * A border that carries meaning (an input outline, a focus ring) must clear
///    3:1. [lightBorder] does not and is for separators only.
class AppColors {
  const AppColors._();

  // ── Brand, sampled from the logo ───────────────────────────────────────────

  /// The deep blue of the oval in the logo. Default accent.
  ///
  /// Sampled from the brand asset at the most saturated blue present
  /// (#0472B1). On white this measures 5.19:1, so it is AA for body text; on
  /// near-black it drops to 3.65:1, which is why [brandOnDark] exists.
  static const Color brand = Color(0xFF0472B1);

  /// Brand blue brightened for dark surfaces. 7.56:1 on [darkBackground].
  static const Color brandOnDark = Color(0xFF5AA8DC);

  /// The lighter blue of the figures in the logo. Used for tints and disabled
  /// states that must still read as brand.
  ///
  /// This was `brandSilver`, taken from the silver `STAND` lettering of the
  /// previous wordmark. That lettering no longer exists, so the token was
  /// renamed rather than left pointing at a colour the logo does not contain.
  static const Color brandTint = Color(0xFF3887BF);

  // ── Ink ramp ───────────────────────────────────────────────────────────────

  /// Primary text. 19.67:1 on white.
  static const Color ink = Color(0xFF0B0B0C);

  /// Secondary text. 5.30:1 on white, so it is still AA for body copy.
  static const Color inkMuted = Color(0xFF6B6B70);

  /// Tertiary text and disabled states. 3.43:1 on white: large text and icons
  /// only, never a paragraph.
  static const Color inkFaint = Color(0xFF8A8A90);

  /// Primary text on dark surfaces. 18.07:1 on [darkBackground].
  static const Color inkOnDark = Color(0xFFF5F5F7);

  /// Secondary text on dark surfaces. 7.03:1 on [darkBackground].
  static const Color inkMutedOnDark = Color(0xFF9A9AA0);

  // ── Surfaces ───────────────────────────────────────────────────────────────

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFAFAFA);
  static const Color lightCard = Color(0xFFFFFFFF);

  /// Hairline separator. 1.27:1 on white — decorative only, never the sole
  /// indicator of a control boundary.
  static const Color lightBorder = Color(0xFFE4E5E0);

  /// Input and focus outlines. 3.34:1 on white, clearing the WCAG floor for a
  /// non-text UI boundary.
  static const Color lightBorderStrong = Color(0xFF8C8D88);

  static const Color darkBackground = Color(0xFF0B0B0C);
  static const Color darkSurface = Color(0xFF151517);
  static const Color darkCard = Color(0xFF151517);

  static const Color darkBorder = Color(0xFF26262A);

  /// 3.90:1 on [darkBackground]. The first candidate, #5A5A62, measured 2.88:1
  /// and was rejected.
  static const Color darkBorderStrong = Color(0xFF6E6E77);

  // ── Status ─────────────────────────────────────────────────────────────────

  /// These carry meaning on their own (a log row, a heatmap cell), so they are
  /// held apart in lightness and are not derived from the accent. Changing the
  /// accent must never change what "skipped" looks like.
  static const Color completed = Color(0xFF1F7A45);
  static const Color snoozed = Color(0xFF8A5A1C);
  static const Color skipped = Color(0xFF9A4638);

  static const Color empty = Color(0xFFD8D9D4);
  static const Color emptyOnDark = Color(0xFF2A2A2E);

  // ── Accents ────────────────────────────────────────────────────────────────
  //
  // `brand` is the default and the only one new installs see. The rest exist
  // because the accent is a user choice from onboarding, and because profiles
  // created before the rebrand may still carry a stored `colorSystem`. Removing
  // them would silently repaint those installs.

  static const Color blueAccent = Color(0xFF2563EB);
  static const Color tealAccent = Color(0xFF0F766E);
  static const Color amberAccent = Color(0xFFB45309);
  static const Color violetAccent = Color(0xFF7C3AED);
  static const Color emeraldAccent = Color(0xFF1F7A45);

  // Text-grade variants. The accent values above are chosen for fills and icons
  // where 3:1 suffices; used as body text they must clear 4.5:1, so labels use
  // these instead.
  static const Color blueText = Color(0xFF2563EB); // 5.17:1
  static const Color tealText = Color(0xFF0F766E); // 5.47:1
  static const Color amberText = Color(0xFFB45309); // 5.02:1
  static const Color violetText = Color(0xFF7C3AED); // 5.70:1
  static const Color emeraldText = Color(0xFF1F7A45);

  /// Dark-mode text variants.
  static const Color blueOnDark = Color(0xFF60A5FA); // 7.74:1
  static const Color tealOnDark = Color(0xFF2DD4BF); // 10.57:1
  static const Color amberOnDark = Color(0xFFF59E0B); // 9.16:1
  static const Color violetOnDark = Color(0xFFA78BFA); // 7.23:1
  static const Color emeraldOnDark = Color(0xFF4ADE80);

  /// Primary variant per accent, used for filled surfaces and app-bar tint.
  static const Color bluePrimary = Color(0xFF1D4ED8);
  static const Color tealPrimary = Color(0xFF115E59);
  static const Color amberPrimary = Color(0xFF92400E);
  static const Color violetPrimary = Color(0xFF6D28D9);
  static const Color emeraldPrimary = Color(0xFF14532D);
  static const Color brandPrimary = Color(0xFF04598A); // 7.50:1 on white

  /// Every accent the user can pick, in the order onboarding presents them.
  ///
  /// The first entry is the default. Keeping this a single list means the
  /// onboarding picker and [getAccentColor] cannot disagree about which options
  /// exist.
  static const List<AccentOption> accents = [
    AccentOption(id: 'brand', label: 'Crimson', swatch: brand),
    // The monochrome swatch is ink itself: choosing it is how a user asks for
    // the app to have no accent at all.
    AccentOption(id: 'ink', label: 'Monochrome', swatch: ink),
    AccentOption(id: 'blue', label: 'Blue', swatch: blueAccent),
    AccentOption(id: 'teal', label: 'Teal', swatch: tealAccent),
    AccentOption(id: 'violet', label: 'Violet', swatch: violetAccent),
    AccentOption(id: 'amber', label: 'Amber', swatch: amberAccent),
  ];

  /// The accent used when a stored value is missing or unrecognised.
  static const String defaultAccentId = 'brand';

  /// Whether [id] is one the picker offers.
  static bool isKnownAccent(String? id) {
    if (id == null) return false;
    return accents.any((option) => option.id == id);
  }

  /// Fill-and-icon variant of the accent.
  static Color getAccentColor(String colorSystem) {
    switch (colorSystem) {
      case 'ink':
        return ink;
      case 'blue':
        return blueAccent;
      case 'teal':
        return tealAccent;
      case 'violet':
        return violetAccent;
      case 'amber':
        return amberAccent;
      case 'emerald':
        return emeraldAccent;
      case 'brand':
      default:
        return brand;
    }
  }

  /// Accent variant legal as body text on a light surface (AA, 4.5:1+).
  static Color getAccentTextColor(String colorSystem) {
    switch (colorSystem) {
      case 'ink':
        return ink;
      case 'blue':
        return blueText;
      case 'teal':
        return tealText;
      case 'violet':
        return violetText;
      case 'amber':
        return amberText;
      case 'emerald':
        return emeraldText;
      case 'brand':
      default:
        return brand;
    }
  }

  /// Accent variant legal as body text on a dark surface.
  static Color getAccentOnDark(String colorSystem) {
    switch (colorSystem) {
      case 'ink':
        return inkOnDark;
      case 'blue':
        return blueOnDark;
      case 'teal':
        return tealOnDark;
      case 'violet':
        return violetOnDark;
      case 'amber':
        return amberOnDark;
      case 'emerald':
        return emeraldOnDark;
      case 'brand':
      default:
        return brandOnDark;
    }
  }

  /// Deep variant for filled surfaces and large headings.
  static Color getPrimaryColor(String colorSystem) {
    switch (colorSystem) {
      case 'ink':
        return ink;
      case 'blue':
        return bluePrimary;
      case 'teal':
        return tealPrimary;
      case 'violet':
        return violetPrimary;
      case 'amber':
        return amberPrimary;
      case 'emerald':
        return emeraldPrimary;
      case 'brand':
      default:
        return brandPrimary;
    }
  }
}

/// One selectable accent, as presented by the onboarding picker.
class AccentOption {
  final String id;

  /// Untranslated label. The picker renders it through the string dictionary.
  final String label;

  /// Colour shown in the swatch.
  final Color swatch;

  const AccentOption({
    required this.id,
    required this.label,
    required this.swatch,
  });
}
