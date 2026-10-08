import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_colors.dart';

/// Locks down the accessibility properties of the palette.
///
/// The contrast numbers in `AppColors`'s comments are the reason the palette
/// works; re-deriving them here means a future "just nudge this hex" edit fails
/// the build instead of quietly shipping unreadable text. The checks are
/// deliberately about the palette's own guarantees, not about every widget,
/// because a widget can misuse a good colour but a bad colour cannot be fixed by
/// a widget.
void main() {
  group('Contrast ratios', () {
    test('brand crimson is legal as text on white', () {
      // The default accent is used for labels as well as fills, so it has to
      // clear the 4.5:1 body-text bar on the light surface.
      expect(
        ratio(AppColors.brand, AppColors.lightBackground),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('brand crimson is legal as text on a white card', () {
      expect(
        ratio(AppColors.brand, AppColors.lightCard),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('white is legal on the brand fill', () {
      // The primary action is a filled button, so this pairing carries the most
      // important text in the app.
      expect(ratio(Colors.white, AppColors.brand), greaterThanOrEqualTo(4.5));
    });

    test('every light-mode text ramp clears AA on white', () {
      final inks = <String, Color>{
        'ink': AppColors.ink,
        'inkMuted': AppColors.inkMuted,
        'brand': AppColors.brand,
        'blueText': AppColors.blueText,
        'tealText': AppColors.tealText,
        'violetText': AppColors.violetText,
        'amberText': AppColors.amberText,
        'completed': AppColors.completed,
        'snoozed': AppColors.snoozed,
        'skipped': AppColors.skipped,
      };
      inks.forEach((name, color) {
        expect(
          ratio(color, AppColors.lightBackground),
          greaterThanOrEqualTo(4.5),
          reason:
              '$name (#${color.toARGB32().toRadixString(16).substring(2)}) '
              'is below 4.5:1 on white',
        );
      });
    });

    test('every dark-mode text ramp clears AA on the dark surface', () {
      final inks = <String, Color>{
        'inkOnDark': AppColors.inkOnDark,
        'inkMutedOnDark': AppColors.inkMutedOnDark,
        'brandOnDark': AppColors.brandOnDark,
        'blueOnDark': AppColors.blueOnDark,
        'tealOnDark': AppColors.tealOnDark,
        'violetOnDark': AppColors.violetOnDark,
        'amberOnDark': AppColors.amberOnDark,
      };
      inks.forEach((name, color) {
        expect(
          ratio(color, AppColors.darkBackground),
          greaterThanOrEqualTo(4.5),
          reason: '$name is below 4.5:1 on the dark background',
        );
      });
    });

    test('inkFaint is reserved for large text, not body copy', () {
      // It is used for placeholders and disabled labels. Documenting the limit
      // here stops someone later using it for a paragraph.
      expect(
        ratio(AppColors.inkFaint, AppColors.lightBackground),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        ratio(AppColors.inkFaint, AppColors.lightBackground),
        lessThan(4.5),
        reason:
            'inkFaint clears the large-text bar only; do not use for body copy',
      );
    });

    test('meaningful borders clear the 3:1 non-text bar', () {
      expect(
        ratio(AppColors.lightBorderStrong, AppColors.lightBackground),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        ratio(AppColors.darkBorderStrong, AppColors.darkBackground),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  group('Accent selection', () {
    test('the default accent is the brand crimson', () {
      // The default has to follow the logo; this is the assertion that keeps a
      // later "let's try another default" from going unnoticed.
      expect(AppColors.defaultAccentId, 'brand');
      expect(
        AppColors.getAccentColor(AppColors.defaultAccentId),
        AppColors.brand,
      );
    });

    test('an unknown accent falls back to the brand rather than throwing', () {
      expect(AppColors.getAccentColor('chartreuse'), AppColors.brand);
      expect(AppColors.getAccentTextColor(''), AppColors.brand);
      expect(AppColors.getPrimaryColor('nope'), AppColors.brandPrimary);
    });

    test('every advertised accent resolves in all three variants', () {
      for (final option in AppColors.accents) {
        expect(
          () => AppColors.getAccentColor(option.id),
          returnsNormally,
          reason: '${option.id} has no fill variant',
        );
        expect(
          () => AppColors.getAccentTextColor(option.id),
          returnsNormally,
          reason: '${option.id} has no text variant',
        );
        expect(
          () => AppColors.getAccentOnDark(option.id),
          returnsNormally,
          reason: '${option.id} has no dark variant',
        );
        expect(
          () => AppColors.getPrimaryColor(option.id),
          returnsNormally,
          reason: '${option.id} has no primary variant',
        );
      }
    });

    test(
      'accent ids are unique, so a picker cannot select the wrong swatch',
      () {
        final ids = AppColors.accents.map((a) => a.id).toList();
        expect(ids.toSet().length, ids.length, reason: 'duplicate accent id');
      },
    );

    test('isKnownAccent rejects values the picker does not offer', () {
      expect(AppColors.isKnownAccent('brand'), isTrue);
      expect(AppColors.isKnownAccent('brand'), isTrue);
      expect(AppColors.isKnownAccent('emerald'), isFalse);
      expect(AppColors.isKnownAccent(''), isFalse);
      expect(AppColors.isKnownAccent(null), isFalse);
    });

    test('every light-mode accent text variant is AA on white', () {
      for (final option in AppColors.accents) {
        expect(
          ratio(
            AppColors.getAccentTextColor(option.id),
            AppColors.lightBackground,
          ),
          greaterThanOrEqualTo(4.5),
          reason: 'the ${option.id} accent is used for labels and must be AA',
        );
      }
    });

    test('every dark-mode accent variant is AA on the dark background', () {
      for (final option in AppColors.accents) {
        expect(
          ratio(AppColors.getAccentOnDark(option.id), AppColors.darkBackground),
          greaterThanOrEqualTo(4.5),
          reason: 'the ${option.id} accent needs a legible dark-mode variant',
        );
      }
    });
  });

  group('Surface sanity', () {
    test('light surfaces stay near-white so the accent does the talking', () {
      // If a surface drifts towards tinted, the app starts looking coloured
      // again, which is the look the rebrand removed.
      for (final entry in {
        'lightBackground': AppColors.lightBackground,
        'lightSurface': AppColors.lightSurface,
        'lightCard': AppColors.lightCard,
      }.entries) {
        final color = entry.value;
        final max = [color.r, color.g, color.b].reduce(math.max);
        final min = [color.r, color.g, color.b].reduce(math.min);
        // A neutral has r == g == b. Allow a small tolerance for compression.
        expect(
          max - min,
          lessThanOrEqualTo(0.02),
          reason: '${entry.key} is tinted; light surfaces must be neutral',
        );
        expect(color.computeLuminance(), greaterThan(0.85));
      }
    });

    test('dark surfaces stay near-black and neutral', () {
      for (final entry in {
        'darkBackground': AppColors.darkBackground,
        'darkSurface': AppColors.darkSurface,
        'darkCard': AppColors.darkCard,
      }.entries) {
        final color = entry.value;
        final max = [color.r, color.g, color.b].reduce(math.max);
        final min = [color.r, color.g, color.b].reduce(math.min);
        expect(
          max - min,
          lessThanOrEqualTo(0.02),
          reason: '${entry.key} is tinted',
        );
        expect(color.computeLuminance(), lessThan(0.05));
      }
    });

    test('brand constants match the logo asset', () {
      // Sampled from assets/branding/csph_standup_logo.png. If the logo is ever
      // re-exported, this fails and the two are updated together rather than
      // the app quietly drifting from its own mark.
      expect(AppColors.brand, const Color(0xFFDA244D));
      expect(AppColors.brandSilver, const Color(0xFFE4E5E0));
    });
  });
}

/// WCAG 2.1 relative-contrast ratio between two opaque colours.
double ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}
