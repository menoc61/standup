import 'package:flutter/material.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_spacing.dart';
import 'package:standup_app/ui/widgets/app_canvas.dart';

/// One destination in the bottom bar.
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;

  /// Already resolved through the string dictionary by the caller.
  final String label;
}

/// The Paper & Ink bottom navigation.
///
/// ## The idea
///
/// The bar is not a bar. It is a strip of paper laid on the desk the app is
/// painted on: inset from both edges, rounded at the top, resting on the page
/// with a soft shadow and a hairline. Every other surface in the app is a card
/// floating on paper, so the navigation is one more card rather than a chrome
/// strip bolted to the window — which is what made the previous version read as
/// generic Material with the theme swapped.
///
/// ## Selection
///
/// The active destination is marked three ways at once: the icon swaps to its
/// filled variant, the label switches from Plex Sans to Fraunces, and a short
/// ink stroke appears beneath it. Three signals rather than one, because colour
/// alone fails for a monochrome accent and for a colour-blind reader.
///
/// The type change is the one that carries the design. Setting the active label
/// in the display serif is what separates a considered navigation from a
/// template, and it costs nothing.
///
/// ## Accessibility
///
/// Each destination is at least [AppSpace.control] tall, and the whole bar sits
/// inside a `SafeArea` so it clears the home indicator. Selection is exposed to
/// screen readers as `Semantics(selected:)`, not only as a visual change.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
    required this.accent,
    this.trailing,
  });

  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color accent;

  /// Controls pinned to the trailing edge — settings and the reminder bell.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ColoredBox(
      color: appCanvasColor(context),
      child: SafeArea(
        top: false,
        child: Padding(
          // Inset so the strip reads as a separate sheet of paper rather than
          // as a full-width bar welded to the window edge.
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.md,
            AppSpace.xl,
            AppSpace.md,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightCard,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
                bottom: Radius.circular(AppRadius.lg),
              ),
              border: Border.all(color: appCanvasDividerColor(context)),
              boxShadow: isDark
                  ? AppElevation.raised.shadow
                  : AppElevation.card.shadow,
            ),
            child: SizedBox(
              height: AppSpace.control + AppSpace.md,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        destination: destinations[i],
                        selected: i == currentIndex,
                        accent: accent,
                        onTap: () => onTap(i),
                      ),
                    ),
                  if (trailing != null) ...[
                    Container(
                      width: 1,
                      height: AppSpace.huge,
                      margin: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                      color: appCanvasDividerColor(context),
                    ),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = selected
        ? accent
        : (isDark ? AppColors.inkMutedOnDark : AppColors.inkMuted);

    final label = selected
        ? theme.textTheme.labelMedium?.copyWith(
            fontFamily: 'Fraunces',
            fontSize: AppFontSize.small,
            fontWeight: FontWeight.w600,
            color: color,
          )
        : theme.textTheme.labelSmall?.copyWith(
            fontSize: AppFontSize.caption,
            fontWeight: FontWeight.w500,
            color: color,
          );

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.activeIcon : destination.icon,
              size: AppIconSize.medium,
              color: color,
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: label,
            ),
            const SizedBox(height: AppSpace.xxs),
            // The ink stroke. Animated so the selection travels between
            // destinations rather than blinking.
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: Curves.easeOut,
              height: 2,
              width: selected ? AppSpace.huge : 0,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
