import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';

/// The colours a home-screen widget needs, resolved from the user's accent.
///
/// ## Why this is a value and not a lookup table on each platform
///
/// The accent is a user choice, and the widget has to honour it. The obvious
/// implementation is to give the Kotlin provider and the Swift extension their
/// own copy of the palette and look the accent up by name. That is three copies
/// — Dart, Kotlin, Swift — and the day someone adds a seventh accent, two of
/// them will quietly fall back and the widget will stop matching the app.
///
/// So the resolution happens once, here, and the result is published as plain
/// hex strings. The native side applies whatever arrives. If the palette changes,
/// the widget changes with it on the next publish, with nothing to remember.
///
/// ## Encoding
///
/// `AARRGGBB`, uppercase, no `#`. The pipe-delimited widget encoding splits on
/// `=` and `;`, so the value is deliberately restricted to characters that
/// cannot collide with that format. Parse failures fall back to
/// [fallbackSurface] and friends rather than rendering a blank widget.
class WidgetPaletteHex {
  /// Widget background.
  final String? surface;

  /// A slightly lighter surface, for the logo chip and the goal track.
  final String? surfaceAlt;

  /// Primary text and the countdown.
  final String? onSurface;

  /// Secondary text — the status line.
  final String? muted;

  /// The user's accent. Used for the goal fill and the progress ring.
  final String? accent;

  /// Text drawn on top of [accent] — the action button label.
  final String? onAccent;

  /// The streak highlight.
  final String? streak;

  const WidgetPaletteHex({
    this.surface,
    this.surfaceAlt,
    this.onSurface,
    this.muted,
    this.accent,
    this.onAccent,
    this.streak,
  });

  /// Resolves the palette for [colorSystem] in the app's default appearance.
  ///
  /// The widget is drawn by the launcher, which knows nothing about the app's
  /// current brightness, so this resolves for light mode — the app's default.
  /// A user who forces dark mode still gets a light widget, which is the
  /// correct trade: a widget that is illegible against a light wallpaper is
  /// worse than one that is not the exact shade the app is using.
  factory WidgetPaletteHex.forAccent(String colorSystem) {
    return WidgetPaletteHex(
      surface: _hex(AppColors.lightBackground),
      surfaceAlt: _hex(AppColors.brandTint),
      onSurface: _hex(AppColors.ink),
      muted: _hex(AppColors.inkMuted),
      accent: _hex(AppColors.getAccentColor(colorSystem)),
      onAccent: '#FFFFFFFF',
      streak: _hex(AppColors.getAccentColor(colorSystem)),
    );
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';

  /// Neutral values used when the payload is missing or unparseable.
  ///
  /// These match the light palette rather than the retired evergreen, so a
  /// widget that has never received a publish still looks like the app.
  static const String fallbackSurface = '#FFFFFFFF';
  static const String fallbackOnSurface = '#FF0B0B0C';
  static const String fallbackMuted = '#FF6B6B70';
  static const String fallbackAccent = '#FF0472B1';
  static const String fallbackOnAccent = '#FFFFFFFF';
  static const String fallbackStreak = '#FF0472B1';
  static const String fallbackSurfaceAlt = '#FF3887BF';
}

/// Parses an `AARRGGBB` string into an Android colour, or returns null.
Color? parseWidgetColor(String? hex) {
  if (hex == null) return null;
  var value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}
