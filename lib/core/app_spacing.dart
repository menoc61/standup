import 'package:flutter/widgets.dart';

/// The Paper & Ink spatial system.
///
/// The audit found 1,783 numeric literals across `lib/ui`, 253 distinct values
/// and 17 distinct corner radii, with the same number meaning different things
/// in different files: `16` was card padding in one place and control padding in
/// another. That is what made the app feel assembled rather than designed.
///
/// Everything here is a named step on a small scale. A value not on the scale
/// is a decision someone forgot to make.
///
/// The scale is 4pt-based with a deliberate half-step at 6 and 20, because
/// those are the two sizes the app genuinely needs and a 4pt grid alone would
/// force an ugly approximation for them.
abstract final class AppSpace {
  /// Hairline gaps: icon-to-label inside a control, dot spacing.
  static const double xxs = 2;

  /// Tight groupings inside a single control or chip.
  static const double xs = 4;

  /// Between closely related elements — a label and its field.
  static const double sm = 6;

  /// The default gap. Icon to text, chip padding.
  static const double md = 8;

  /// Between related groups inside a card.
  static const double lg = 12;

  /// The default card padding.
  static const double xl = 16;

  /// Between sibling cards and between a section heading and its content.
  static const double xxl = 20;

  /// Card-to-card separation on a dashboard.
  static const double xxxl = 24;

  /// Between major sections of a screen.
  static const double section = 32;

  /// Screen-edge padding on a spacious layout.
  static const double screen = 40;

  /// Symmetric padding for a large control. Also the minimum comfortable
  /// touch target height, which is why it is not smaller.
  static const double control = 48;

  /// Minimum touch target. The accessibility floor is 48; 44 is accepted only
  /// where a target sits inside a larger one (a heatmap cell inside a grid).
  static const double touchTarget = 48;

  /// Gutter between dashboard grid columns.
  static const double gutter = 16;

  /// Width of a hairline rule.
  static const double hairline = 1;

  const AppSpace._();
}

/// Corner radii, one per distinct role.
///
/// The audit found 17 radii in use: 1,2,3,4,6,8,9,10,12,14,16,18,20,22,26,28,30.
/// Paper & Ink uses a small set with names, so "the card radius" is one answer
/// rather than 22 or 18 or 20 depending on which file you ask.
abstract final class AppRadius {
  /// Chips, tags, tiny badges.
  static const double sm = 8;

  /// Inputs, small controls, heatmap cells.
  static const double md = 14;

  /// Cards and panels. The app's signature roundness.
  static const double lg = 22;

  /// Sheets and dialogs, which sit above cards.
  static const double xl = 28;

  /// Fully rounded: pills, avatars, FABs.
  static const double pill = 999;

  const AppRadius._();
}

/// Shadows and elevation.
///
/// Shadows are hand-written at six sites in the original code with six
/// different blur/spread/opacity triples. These are the three levels the Paper
/// & Ink surface hierarchy actually needs: resting card, raised card (pressed
/// or hovered), and overlay (sheet, dialog, FAB).
@immutable
class AppElevation {
  final List<BoxShadow> shadow;

  const AppElevation._(this.shadow);

  /// A card at rest. Barely there in light mode; a soft lift in dark, where a
  /// shadow alone is invisible against a near-black ground.
  static const AppElevation card = AppElevation._([
    BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1)),
  ]);

  /// A card that has been pressed, hovered, or dragged.
  static const AppElevation raised = AppElevation._([
    BoxShadow(color: Color(0x1F000000), blurRadius: 28, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 1)),
  ]);

  /// Sheets, dialogs, and the FAB. Reads as a distinct layer.
  static const AppElevation overlay = AppElevation._([
    BoxShadow(color: Color(0x2E000000), blurRadius: 40, offset: Offset(0, 18)),
    BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2)),
  ]);

  /// The dark-theme variants. A black shadow on #0B0B0C is invisible, so the
  /// lift comes from a faint white edge instead.
  static const AppElevation cardDark = AppElevation._([
    BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x1F000000), blurRadius: 2, offset: Offset(0, 1)),
  ]);

  static const AppElevation raisedDark = AppElevation._([
    BoxShadow(color: Color(0x14FFFFFF), blurRadius: 28, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
  ]);

  static const AppElevation overlayDark = AppElevation._([
    BoxShadow(color: Color(0x1FFFFFFF), blurRadius: 40, offset: Offset(0, 18)),
    BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
  ]);

  /// The card-level elevation for [brightness].
  static AppElevation cardFor(Brightness brightness) =>
      brightness == Brightness.dark ? cardDark : card;

  /// The raised elevation for [brightness].
  static AppElevation raisedFor(Brightness brightness) =>
      brightness == Brightness.dark ? raisedDark : raised;

  /// The overlay elevation for [brightness].
  static AppElevation overlayFor(Brightness brightness) =>
      brightness == Brightness.dark ? overlayDark : overlay;
}

/// Motion tokens, expressed as durations and curves.
///
/// `PlatformMotion` already defined page transitions and stagger spacing; this
/// adds the press and reveal durations the design system needs, so that a
/// button press, a card lift and a page transition all feel like one app.
abstract final class AppMotion {
  /// A press down. Fast enough to feel instant.
  static const Duration instant = Duration(milliseconds: 110);

  /// The standard state change — chip selection, colour swap.
  static const Duration fast = Duration(milliseconds: 180);

  /// The standard layout change — a card expanding, a bar sliding.
  static const Duration normal = Duration(milliseconds: 260);

  /// A page or sheet transition.
  static const Duration slow = Duration(milliseconds: 380);

  /// A deliberate, celebratory reveal.
  static const Duration reveal = Duration(milliseconds: 620);

  /// Standard ease-out. The default for almost everything.
  static const Curve standard = Cubic(0.22, 1, 0.36, 1);

  /// Overshoots slightly, for a playful settle.
  static const Curve spring = Curves.easeOutBack;

  /// Symmetric, for motion that starts and ends on screen.
  static const Curve emphasised = Curves.easeInOutCubic;

  const AppMotion._();
}
