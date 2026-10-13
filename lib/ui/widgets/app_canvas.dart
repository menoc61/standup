import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_spacing.dart';

/// The surface every screen sits on.
///
/// ## Why this exists
///
/// Both Scaffolds in the shell set `backgroundColor: Colors.transparent`, and
/// nothing behind them painted anything. That combination is invisible on
/// desktop, where the window supplies a surface, and broken on mobile, where
/// there is no window behind the app — so the leaderboard and the bottom
/// navigation bar rendered against black. On a real device the tab bar was a
/// black slab and the top, right and bottom edges of every screen bled black.
///
/// The second problem this solves is drift. The home screen painted its own
/// background from four hard-coded hexes while the other screens used nothing,
/// which is why the app looked like one product on the timer tab and another
/// everywhere else. There is now one background, derived from the theme, and
/// screens layer on top of it instead of each inventing one.
///
/// ## How it is put together
///
/// A flat ink base, then two very low-opacity radial washes to suggest paper
/// fibre catching light. The washes are intentionally weak — at these alphas
/// they are closer to a texture than a gradient, and they never shift a text
/// contrast ratio enough to matter.
class AppCanvas extends StatelessWidget {
  const AppCanvas({super.key, required this.child, this.ambient = true});

  /// The screen content, drawn above the paper.
  final Widget child;

  /// Whether to lay the soft washes over the base colour.
  ///
  /// Off for surfaces that already carry their own background — a dialog, a
  /// sheet — so the wash is not applied twice.
  final bool ambient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final topLeft = isDark ? AppColors.paperDark : AppColors.paperLight;
    final bottomRight = isDark
        ? AppColors.paperDarkDeep
        : AppColors.paperLightDeep;

    if (!ambient) {
      return ColoredBox(color: topLeft, child: child);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topLeft, bottomRight],
        ),
      ),
      child: child,
    );
  }
}

/// The paper tone for a given brightness, for callers that need the colour
/// without the widget — a [ClipRRect] boundary, a shadow colour, a shader.
Color appCanvasColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.paperDark
    : AppColors.paperLight;

/// The hairline that separates the navigation bar from the content above it.
///
/// Paper has no drop shadow, so a single one-pixel rule does the work a
/// Material bottom app bar achieves with elevation. In dark mode the rule is
/// lighter than the surface; in light mode it is darker.
Color appCanvasDividerColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? AppColors.darkBorder : AppColors.lightBorder;
}

/// Bottom padding that clears the system gesture bar.
///
/// A hard-coded `MediaQuery.padding.bottom` is wrong on a device with a home
/// indicator *and* wrong on one without: it returns zero on the latter, so the
/// nav bar sits flush against the screen edge. Asking for a minimum keeps the
/// bar off the edge either way.
EdgeInsets appCanvasNavInset(BuildContext context) => EdgeInsets.only(
  bottom: MediaQuery.paddingOf(context).bottom < AppSpace.sm
      ? AppSpace.sm
      : MediaQuery.paddingOf(context).bottom,
);
