import 'package:flutter/material.dart';

/// A quiet, botanical palette for a workplace wellness app.
///
/// Color is used sparingly: evergreen anchors the product, clay marks a
/// movement moment, and the neutral surfaces keep long sessions comfortable.
class AppColors {
  static const Color emeraldPrimary = Color(0xFF1F4B38);
  static const Color emeraldAccent = Color(0xFF4D8763);
  static const Color emeraldLight = Color(0xFFE5EEE5);
  static const Color emeraldDark = Color(0xFF14271E);

  static const Color tealPrimary = Color(0xFF194650);
  static const Color tealAccent = Color(0xFF43858B);

  static const Color amberPrimary = Color(0xFF755326);
  static const Color amberAccent = Color(0xFFB17A34);

  static const Color indigoPrimary = Color(0xFF394B70);
  static const Color indigoAccent = Color(0xFF667EAA);

  static const Color coralPrimary = Color(0xFF773F38);
  static const Color coralAccent = Color(0xFFB86D5D);

  // Status colors are intentionally softened, while remaining distinguishable.
  static const Color completed = Color(0xFF4F815E);
  static const Color snoozed = Color(0xFF9A672F);
  static const Color skipped = Color(0xFFAA584D);
  static const Color empty = Color(0xFF39463E);
  static const Color emptyLight = Color(0xFFE5E6DC);

  // Pure white background in light mode; deep green charcoal in dark mode.
  static const Color darkBackground = Color(0xFF111915);
  static const Color darkSurface = Color(0xFF18231D);
  static const Color darkCard = Color(0xFF1D2A23);
  static const Color darkBorder = Color(0xFF314238);

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE4E7E2);

  static Color getAccentColor(String colorSystem) {
    switch (colorSystem) {
      case 'teal':
        return tealAccent;
      case 'amber':
        return amberAccent;
      case 'indigo':
        return indigoAccent;
      case 'coral':
        return coralAccent;
      case 'emerald':
      default:
        return emeraldAccent;
    }
  }

  static Color getPrimaryColor(String colorSystem) {
    switch (colorSystem) {
      case 'teal':
        return tealPrimary;
      case 'amber':
        return amberPrimary;
      case 'indigo':
        return indigoPrimary;
      case 'coral':
        return coralPrimary;
      case 'emerald':
      default:
        return emeraldPrimary;
    }
  }
}
