import 'package:flutter/widgets.dart';

/// The Paper & Ink spatial system.
///
/// The audit found 1,783 numeric literals across `lib/ui`, 253 distinct values
/// and 17 distinct corner radii, with the same number meaning different things
/// in different files: `16` was card padding in one place and control padding in
/// another. That is what made the app feel assembled rather than designed.
///
/// Everything here is a named step on a small scale.
///
/// ## Why this exists
///
/// An audit of `lib/ui` found 1,783 numeric literals across 253 distinct values,
/// and 17 distinct corner radii where five roles would do. The same number meant
/// different things in different files — `16` was card padding in one place and
/// control padding in another — which is what made the app feel assembled
/// rather than designed.
///
/// ## Adoption status
///
/// Adoption is progressive and is tracked by how many of these tokens are
/// referenced outside this file. The scale is fully wired up for spacing, radius,
/// type size and motion; individual screens are converted as they are touched for
/// other reasons. A literal that survives on a screen is not automatically a
/// defect — icon sizes, illustration geometry and one-off diagrams are not
/// spacing decisions and should stay literal.
///
/// What matters is that a *repeating* value has one name. If a screen needs a
/// sixth radius or a seventh type size, that is a signal to reconsider the scale
/// rather than to add another literal.
abstract final class AppSpace {
  /// The steps are not a 4pt grid with tidy half-steps; they are the values the
  /// app actually uses. Counted across `lib/ui`, in order of frequency: 12 (52
  /// times), 10 (33), 24 (29), 8 (29), 16 (22), 6 (17), 20 (16), 18 (9), 28
  /// (9), 2 (8), 3 (8), 14 (7), 4 (7), 1 (6), 32 (5), 44 (5).
  ///
  /// A scale of 4/8/16/32 would be tidier to explain and would leave the second
  /// and fourth most common gaps in the app unnamed. Converting a value to a
  /// neighbouring step shifts a layout by a few pixels, and with no device
  /// available to check the result, a value-preserving ladder is the honest
  /// choice: converting to these tokens changes no geometry at all.
  ///
  /// The values left unnamed — 1, 3, 14, 18, 28, 44 — are the six that together
  /// account for about a sixth of all spacing sites. They stay literal rather
  /// than being snapped, because snapping is a visual decision that deserves a
  /// screen in front of you.

  /// Hairline gaps: icon-to-label inside a control, dot spacing.
  static const double xxs = 2;

  /// Tight groupings inside a single control or chip.
  static const double xs = 4;

  /// Between closely related elements — a label and its field.
  static const double sm = 6;

  /// Icon to text, chip padding.
  static const double md = 8;

  /// The default gap between items in a list or a row of chips.
  static const double lg = 10;

  /// The most common gap in the app, by a wide margin. Card padding, the space
  /// between a label and the control it describes.
  static const double xl = 12;

  /// Between related groups inside a card.
  static const double xxl = 16;

  /// Between sibling cards, and between a section heading and its content.
  static const double huge = 20;

  /// Between major sections of a screen.
  static const double section = 24;

  /// Card-to-card separation on a dashboard.
  static const double gutter = 32;

  /// Symmetric padding for a large control, and the accessibility floor for a
  /// touch target.
  static const double control = 48;

  /// Width of a hairline rule.
  static const double hairline = 1;

  const AppSpace._();
}

/// Corner radii, one per distinct role.
///
/// The audit found 17 radii in use: 1,2,3,4,6,8,9,10,12,14,16,18,20,22,26,28,30.
/// Paper & Ink uses a small set with names, so "the card radius" is one answer
/// rather than 22 or 18 or 20 depending on which file you ask.
/// Corner radii, named by role.
///
/// These values are not invented. They are the radii the app actually uses,
/// counted: 12 appears sixteen times, 4 nine times, 28 six, 16 six, 20 five.
/// Naming only the top of that distribution would leave the commonest radius in
/// the app un-named, which is the failure this scale exists to prevent. The two
/// that fell off the end — 14 and 22 — are now off-scale literals.
///
/// An earlier draft of this file named 8/14/22/28 instead. That was wrong: 14
/// and 22 occur six and twice, while 12 and 20 occur sixteen and five. Converting
/// to this scale therefore nudges a handful of corners by two to six pixels.
/// That is a deliberate normalisation towards the radii the app already used
/// most, not a redesign.
abstract final class AppRadius {
  /// Chips, tags, badges, dividers inside a card.
  static const double xs = 4;

  /// Inputs, small controls, heatmap cells, tiles.
  static const double sm = 8;

  /// Cards and panels. The app's signature roundness, and by a wide margin the
  /// most common radius in the codebase.
  static const double md = 12;

  /// Sheets, dialogs, large cards — surfaces that sit above other cards.
  static const double lg = 16;

  /// Hero panels and full-width feature blocks.
  static const double xl = 20;

  /// Full-bleed panels and the largest surfaces.
  static const double xxl = 28;

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

/// Type sizes.
///
/// The audit found 35 separate uses of `fontSize: 13`, 21 of `11`, 17 of `10`
/// and 14 of `12` — four sizes carrying most of the interface — and eleven
/// distinct sizes in total across the app. Those four recur because they are the
/// sizes that work for the roles the app actually has, which is an argument for
/// naming them, not an accident.
///
/// Sizes are named for their role rather than their magnitude, so a retune does
/// not have to walk every call site.
abstract final class AppFontSize {
  /// Chart axes, heatmap cell labels, legal text. Rarely, and small.
  static const double micro = 10;

  /// Secondary body, captions, timestamps, helper text.
  static const double caption = 11;

  /// Dense supporting text that still needs to read comfortably: tooltips,
  /// inline notes, the least important line in a card.
  static const double footnote = 12;

  /// Section headings, labels inside dense cards, table headers.
  static const double small = 13;

  /// The default body size, and the smallest size a label may use for anything
  /// that must stay legible.
  static const double body = 14;

  /// Secondary buttons, chips, dropdown items.
  static const double label = 15;

  /// Primary button text, card titles.
  static const double title = 18;

  /// Page and section headings.
  static const double heading = 23;

  /// Screen-level display headings.
  static const double display = 31;

  /// Numerals in the countdown ring.
  static const double numeral = 48;

  const AppFontSize._();
}

/// Icon sizes.
///
/// Kept apart from [AppSpace] deliberately. An icon's box is not a gap and not a
/// padding — it is the glyph's optical size — and folding the two together is
/// how a 22dp icon ends up in a `SizedBox(height: 16)` and looks clipped.
abstract final class AppIconSize {
  /// Inline with body text: a chevron, a disclosure triangle.
  static const double inline = 14;

  /// A small affordance inside a control.
  static const double small = 18;

  /// Navigation destinations.
  static const double nav = 22;

  /// A standalone control, or an icon in a list row.
  static const double medium = 24;

  /// An empty-state or feature illustration.
  static const double large = 32;

  const AppIconSize._();
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
