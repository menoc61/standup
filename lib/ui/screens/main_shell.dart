import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/ui/screens/analytics_screen.dart';
import 'package:standup_app/ui/screens/home_screen.dart';
import 'package:standup_app/ui/screens/leaderboard_screen.dart';
import 'package:standup_app/ui/screens/org_admin_screen.dart';
import 'package:standup_app/ui/screens/settings_screen.dart';
import 'package:standup_app/ui/widgets/reminder_fab.dart';

class MainShell extends StatefulWidget {
  final AppState appState;
  final VoidCallback onRerunOnboarding;

  const MainShell({
    super.key,
    required this.appState,
    required this.onRerunOnboarding,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Keyboard shortcut intents
  static const _kComplete = 'standup_complete';
  static const _kSnooze = 'standup_snooze';
  static const _kSkip = 'standup_skip';
  static const _kNav1 = 'nav_timer';
  static const _kNav2 = 'nav_leaderboard';
  static const _kNav3 = 'nav_analytics';
  static const _kNav4 = 'nav_org';
  static const _kNav5 = 'nav_settings';

  void _navigate(int idx) {
    if (idx == _currentIndex) return;
    HapticsService.selection();
    widget.appState.audioService.playClick();
    setState(() => _currentIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    // Capture the transparent device profile once a real window size is known.
    final media = MediaQuery.of(context);
    widget.appState.captureDeviceProfile(
      screenSize: media.size,
      pixelRatio: media.devicePixelRatio,
      locale: Localizations.localeOf(context).languageCode,
    );

    final accent = AppColors.getAccentColor(
      widget.appState.preferences.colorSystem,
    );

    final screens = [
      HomeScreen(appState: widget.appState),
      LeaderboardScreen(appState: widget.appState),
      AnalyticsScreen(appState: widget.appState),
      OrgAdminScreen(appState: widget.appState),
      SettingsScreen(
        appState: widget.appState,
        onRerunOnboarding: widget.onRerunOnboarding,
      ),
    ];

    // Keyboard shortcut map
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.space): const _AppIntent(
        _kComplete,
      ),
      const SingleActivator(LogicalKeyboardKey.keyS): const _AppIntent(
        _kSnooze,
      ),
      const SingleActivator(LogicalKeyboardKey.escape): const _AppIntent(
        _kSkip,
      ),
      const SingleActivator(LogicalKeyboardKey.digit1): const _AppIntent(
        _kNav1,
      ),
      const SingleActivator(LogicalKeyboardKey.digit2): const _AppIntent(
        _kNav2,
      ),
      const SingleActivator(LogicalKeyboardKey.digit3): const _AppIntent(
        _kNav3,
      ),
      const SingleActivator(LogicalKeyboardKey.digit4): const _AppIntent(
        _kNav4,
      ),
      const SingleActivator(LogicalKeyboardKey.digit5): const _AppIntent(
        _kNav5,
      ),
    };

    final actions = <Type, Action<Intent>>{
      _AppIntent: CallbackAction<_AppIntent>(
        onInvoke: (intent) {
          switch (intent.action) {
            case _kComplete:
              widget.appState.completeReminder();
            case _kSnooze:
              widget.appState.snoozeReminder(minutes: 10);
            case _kSkip:
              widget.appState.skipReminder();
            case _kNav1:
              _navigate(0);
            case _kNav2:
              _navigate(1);
            case _kNav3:
              _navigate(2);
            case _kNav4:
              _navigate(3);
            case _kNav5:
              _navigate(4);
          }
          return null;
        },
      ),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: actions,
        child: Focus(
          autofocus: true,
          child: isDesktop
              ? _buildDesktop(context, theme, isDark, accent, screens)
              : _buildMobile(context, accent, screens),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop — frosted glass sidebar + content canvas
  // ---------------------------------------------------------------------------
  Widget _buildDesktop(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Color accent,
    List<Widget> screens,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: ReminderFab(appState: widget.appState),
      body: Row(
        children: [
          // Glass sidebar
          _GlassSidebar(
            currentIndex: _currentIndex,
            accent: accent,
            isDark: isDark,
            onDestinationSelected: _navigate,
          ),

          // Subtle divider
          Container(
            width: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),

          // Main content
          Expanded(child: _buildAnimatedScreenStack(context, screens)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile — glassmorphism bottom nav bar
  // ---------------------------------------------------------------------------
  Widget _buildMobile(
    BuildContext context,
    Color accent,
    List<Widget> screens,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: ReminderFab(appState: widget.appState),
      body: _buildAnimatedScreenStack(context, screens),
      bottomNavigationBar: _GlassBottomNav(
        currentIndex: _currentIndex,
        accent: accent,
        isDark: isDark,
        onDestinationSelected: _navigate,
      ),
    );
  }

  /// Keeps each tab alive while fading and gently shifting the selected page.
  /// The same short transition works with touch, mouse, and keyboard input.
  Widget _buildAnimatedScreenStack(BuildContext context, List<Widget> screens) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 240);

    return Stack(
      fit: StackFit.expand,
      children: screens.asMap().entries.map((entry) {
        final index = entry.key;
        final selected = index == _currentIndex;
        return Positioned.fill(
          // Tabs stay mounted so their scroll position survives, but tickers in
          // hidden tabs must stop or hidden animations keep burning battery.
          child: TickerMode(
            enabled: selected,
            child: IgnorePointer(
              ignoring: !selected,
              child: ExcludeFocus(
                excluding: !selected,
                child: ExcludeSemantics(
                  excluding: !selected,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedSlide(
                      offset: selected || reduceMotion
                          ? Offset.zero
                          : const Offset(0, 0.018),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: entry.value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// =============================================================================
// Glass Sidebar (Desktop)
// =============================================================================
class _GlassSidebar extends StatelessWidget {
  final int currentIndex;
  final Color accent;
  final bool isDark;
  final ValueChanged<int> onDestinationSelected;

  const _GlassSidebar({
    required this.currentIndex,
    required this.accent,
    required this.isDark,
    required this.onDestinationSelected,
  });

  static const _destinations = [
    (icon: Icons.timer_outlined, selected: Icons.timer, label: 'Timer'),
    (
      icon: Icons.emoji_events_outlined,
      selected: Icons.emoji_events_rounded,
      label: 'Leaderboard',
    ),
    (
      icon: Icons.grid_view_outlined,
      selected: Icons.grid_view_rounded,
      label: 'Analytics',
    ),
    (
      icon: Icons.corporate_fare_outlined,
      selected: Icons.corporate_fare,
      label: 'Org Health',
    ),
    (icon: Icons.tune_outlined, selected: Icons.tune, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.94),
            border: Border(
              right: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo lockup
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.accessibility_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        appString(context, 'StandUp'),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Nav items
                ..._destinations.asMap().entries.map((entry) {
                  final i = entry.key;
                  final dest = entry.value;
                  final isSelected = i == currentIndex;

                  return _SidebarNavItem(
                    icon: isSelected ? dest.selected : dest.icon,
                    label: appString(context, dest.label),
                    isSelected: isSelected,
                    accent: accent,
                    isDark: isDark,
                    shortcutLabel: '${i + 1}',
                    onTap: () => onDestinationSelected(i),
                  );
                }),

                const Spacer(),

                // Keyboard hints
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appString(context, 'SHORTCUTS'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ShortcutHint(
                        shortcutKey: 'Space',
                        label: appString(context, 'Stand Up'),
                      ),
                      _ShortcutHint(
                        shortcutKey: 'S',
                        label: appString(context, 'Snooze'),
                      ),
                      _ShortcutHint(
                        shortcutKey: 'Esc',
                        label: appString(context, 'Skip'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accent;
  final bool isDark;
  final String shortcutLabel;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.isDark,
    required this.shortcutLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.11)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? accent
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? accent
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Keyboard shortcut badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  shortcutLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  final String shortcutKey;
  final String label;

  const _ShortcutHint({required this.shortcutKey, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              shortcutKey,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Glass Bottom Nav (Mobile)
// =============================================================================
class _GlassBottomNav extends StatefulWidget {
  final int currentIndex;
  final Color accent;
  final bool isDark;
  final ValueChanged<int> onDestinationSelected;

  const _GlassBottomNav({
    required this.currentIndex,
    required this.accent,
    required this.isDark,
    required this.onDestinationSelected,
  });

  @override
  State<_GlassBottomNav> createState() => _GlassBottomNavState();
}

class _GlassBottomNavState extends State<_GlassBottomNav>
    with SingleTickerProviderStateMixin {
  /// Which tab is currently under the finger, used to stretch the indicator.
  int? _pressedIndex;

  static const _items = [
    (icon: Icons.timer_outlined, selected: Icons.timer, label: 'Timer'),
    (
      icon: Icons.emoji_events_outlined,
      selected: Icons.emoji_events_rounded,
      label: 'Leaderboard',
    ),
    (
      icon: Icons.grid_view_outlined,
      selected: Icons.grid_view_rounded,
      label: 'Analytics',
    ),
    (
      icon: Icons.corporate_fare_outlined,
      selected: Icons.corporate_fare,
      label: 'Org',
    ),
    (icon: Icons.tune_outlined, selected: Icons.tune, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = widget.isDark;
    final accent = widget.accent;
    final currentIndex = widget.currentIndex;
    final onDestinationSelected = widget.onDestinationSelected;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.82);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: isDark ? 0.68 : 0.72),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.09),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: isDark ? 0.045 : 0.42,
                    ),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / _items.length;
                    return Stack(
                      children: [
                        // Telegram-style sliding pill: it travels between tabs
                        // with an eased spring and stretches under the finger
                        // while a tab is being pressed.
                        _SlidingIndicator(
                          itemCount: _items.length,
                          itemWidth: itemWidth,
                          index: currentIndex,
                          pressedIndex: _pressedIndex,
                          color: accent,
                          isDark: isDark,
                        ),
                        Row(
                          children: _items.asMap().entries.map((entry) {
                            final i = entry.key;
                            final item = entry.value;
                            final isSelected = i == currentIndex;
                            final foreground = isSelected
                                ? colors.primary
                                : colors.onSurfaceVariant;

                            return SizedBox(
                              width: itemWidth,
                              child: Semantics(
                                button: true,
                                selected: isSelected,
                                label: appString(context, item.label),
                                child: _TabButton(
                                  icon: isSelected ? item.selected : item.icon,
                                  label: appString(context, item.label),
                                  isSelected: isSelected,
                                  foreground: foreground,
                                  onTap: () => onDestinationSelected(i),
                                  onPressStart: () =>
                                      setState(() => _pressedIndex = i),
                                  onPressEnd: () =>
                                      setState(() => _pressedIndex = null),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Custom Intent for keyboard shortcuts
// =============================================================================
class _AppIntent extends Intent {
  final String action;
  const _AppIntent(this.action);
}

/// The sliding selection pill behind the bottom navigation.
///
/// Telegram's bottom bar moves one continuous pill between tabs rather than
/// fading each tab's background independently. This reproduces that with a
/// single animated offset, and adds a press "stretch" so the pill widens under
/// the finger while a different tab is held.
class _SlidingIndicator extends StatelessWidget {
  final int itemCount;
  final double itemWidth;
  final int index;
  final int? pressedIndex;
  final Color color;
  final bool isDark;

  const _SlidingIndicator({
    required this.itemCount,
    required this.itemWidth,
    required this.index,
    required this.pressedIndex,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Stretch toward a held, non-selected tab so the press feels connected to
    // the pill rather than to the icon.
    final target = pressedIndex ?? index;
    final isStretching = pressedIndex != null && pressedIndex != index;

    return AnimatedAlign(
      alignment: Alignment(
        -1 + (2 * target / (itemCount - 1)).clamp(-1.0, 1.0),
        0,
      ),
      duration: reduceMotion
          ? Duration.zero
          : Duration(milliseconds: isStretching ? 180 : 340),
      curve: isStretching ? Curves.easeOutCubic : Curves.easeOutBack,
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: itemWidth * (isStretching ? 1.18 : 1.0),
        height: 58,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.22 : 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tab in the bottom navigation. Kept as its own widget so press state can
/// be reported to the sliding pill without rebuilding the whole bar.
class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color foreground;
  final VoidCallback onTap;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.foreground,
    required this.onTap,
    required this.onPressStart,
    required this.onPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onPressStart(),
        onTapUp: (_) => onPressEnd(),
        onTapCancel: onPressEnd,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: reduceMotion
                    ? const AlwaysStoppedAnimation(1)
                    : animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                icon,
                key: ValueKey(isSelected),
                color: foreground,
                size: isSelected ? 23 : 21,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 10,
                height: 1.1,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: foreground,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
