import 'package:flutter/widgets.dart';

/// How much horizontal space the shell has been given.
///
/// ## Why these are derived from `BoxConstraints`
///
/// Deciding "phone or desktop" by looking at `MediaQuery.sizeOf` gets it wrong in
/// every case that matters on a Flutter app:
///
/// * a desktop app resized into a narrow window still reports a large screen,
/// * a phone in split-screen reports a small window, not its real size,
/// * picture-in-picture and foldable postures report neither cleanly.
///
/// Flutter apps run in resizable, multi-windowed containers, so the only
/// trustworthy input is the width the parent hands down through `BoxConstraints`.
///
/// The helpers live here rather than inline in a screen so the breakpoints can be
/// asserted directly in unit tests without booting the service graph.
enum WindowClass {
  /// Phone-sized. Bottom navigation, single column.
  compact,

  /// Large phone, small tablet, narrow desktop window. Bottom navigation, room
  /// for a two-column body.
  medium,

  /// Desktop window. Persistent sidebar navigation.
  expanded,
}

/// Width at or above which the shell shows a sidebar instead of a bottom bar.
///
/// Matches the Material "large" window class so the layout change coincides
/// with the platform's own adaptive breakpoints.
const double kExpandedMinWidth = 720;

/// Width at or above which a single column can hold a readable two-up grid.
const double kMediumMinWidth = 600;

/// Readable upper bound for dashboard content.
///
/// Without a cap, cards stretch to the full width of a desktop monitor and the
/// countdown ends up marooned in the middle of a very wide row.
const double kContentMaxWidth = 1100;

/// Classifies a width into a [WindowClass].
WindowClass windowClassForWidth(double width) {
  if (width >= kExpandedMinWidth) return WindowClass.expanded;
  if (width >= kMediumMinWidth) return WindowClass.medium;
  return WindowClass.compact;
}

/// Classifies the width [constraints] allocates.
///
/// Passing the constraints straight through, rather than a screen width, is what
/// makes the result correct inside nested layouts as well as at the root.
WindowClass windowClassOf(BoxConstraints constraints) =>
    windowClassForWidth(constraints.maxWidth);

/// Whether this width should use the sidebar navigation.
bool useSidebarNavigation(BoxConstraints constraints) =>
    windowClassOf(constraints) == WindowClass.expanded;

/// Chooses the column count for a card grid at this width.
///
/// Returns 1 rather than 0 so a grid never renders a zero-height sliver while
/// the parent is still measuring.
int gridColumnCount(BoxConstraints constraints) {
  return switch (windowClassOf(constraints)) {
    WindowClass.compact => 1,
    WindowClass.medium => 2,
    WindowClass.expanded => 2,
  };
}

/// Centres [child] and caps its width at [kContentMaxWidth].
///
/// Applied to every full-width tab body so the layout is identical at 800px and
/// at 2400px instead of merely "not overflowing" in both.
Widget constrainContent(Widget child, {double maxWidth = kContentMaxWidth}) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
