import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glass_bottom_navigation/glass_bottom_navigation.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/core/app_theme.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/ui/layout/adaptive.dart';
import 'package:standup_app/ui/screens/analytics_screen.dart';
import 'package:standup_app/ui/screens/home_screen.dart';
import 'package:standup_app/ui/screens/leaderboard_screen.dart';
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

  /// Drives the between-tab transition. Held in state so the page tree is not
  /// rebuilt on every navigation, which is what previously discarded each
  /// screen's scroll position.
  PageController? _pageController;

  // Keyboard shortcut intents
  static const _kComplete = 'standup_complete';
  static const _kSnooze = 'standup_snooze';
  static const _kSkip = 'standup_skip';
  static const _kNav1 = 'nav_timer';
  static const _kNav2 = 'nav_leaderboard';
  static const _kNav3 = 'nav_analytics';

  void _navigate(int idx) {
    if (idx == _currentIndex) return;
    if (idx < 0 || idx >= _pageCount) return;

    HapticsService.selection();
    widget.appState.audioService.playClick();

    // The PageView animates to the page; `onPageChanged` updates the index, so
    // setting it here as well would run the transition twice.
    final controller = _pageController;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (controller != null && controller.hasClients) {
      if (reduceMotion) {
        controller.jumpToPage(idx);
        setState(() => _currentIndex = idx);
      } else {
        controller.animateToPage(
          idx,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    // No controller yet (first frame, or after a resize): fall back to an
    // immediate change rather than dropping the navigation.
    setState(() => _currentIndex = idx);
  }

  /// Number of destinations currently in the tree.
  ///
  /// Read from the state rather than hardcoded, so adding or removing a screen
  /// cannot leave a shortcut pointing past the end of the list.
  int get _pageCount => _screenCount;
  int _screenCount = 3;

  @override
  void dispose() {
    // A PageController holds listeners onto its pages; without this the whole
    // page tree stays reachable after the shell is gone.
    _pageController?.dispose();
    _pageController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

    // Main tabs: Timer, Leaderboard, Analytics. Org is inside Settings now.
    final screens = <Widget>[
      HomeScreen(
        appState: widget.appState,
        onRerunOnboarding: widget.onRerunOnboarding,
      ),
      LeaderboardScreen(appState: widget.appState),
      AnalyticsScreen(appState: widget.appState),
    ];

    // Kept in state so the shortcut bounds check below stays in step with the
    // real page count rather than a hardcoded constant.
    _screenCount = screens.length;

    // The bar asserts 2..4 destinations, so this is a programming error rather
    // than a runtime condition worth handling gracefully.
    assert(
      screens.length >= 2 && screens.length <= 4,
      'The bottom bar supports 2 to 4 destinations; got ${screens.length}.',
    );

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
    };

    final actions = <Type, Action<Intent>>{
      _AppIntent: CallbackAction<_AppIntent>(
        onInvoke: (intent) async {
          switch (intent.action) {
            case _kComplete:
              await widget.appState.completeReminder();
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
          // The breakpoint is decided from the width this widget is actually
          // given, not from the window size. A desktop app in a narrow window,
          // a phone in split-screen, and a picture-in-picture window all get the
          // compact layout, which `MediaQuery.sizeOf` would get wrong in each
          // case because it reports the window rather than the allocation.
          child: LayoutBuilder(
            builder: (context, constraints) => useSidebarNavigation(constraints)
                ? _buildDesktop(context, theme, isDark, accent, screens)
                : _buildMobile(context, accent, screens),
          ),
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
    final navigator = Navigator.of(context);

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

          // Content column. The detail nav sits above the page rather than
          // being positioned over it, so it can never overlap the sidebar and
          // the page keeps the full remaining height.
          Expanded(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildDetailNav(
                    context,
                    canGoBack: navigator.canPop(),
                    canGoForward: navigator.canPop(),
                  ),
                ),
                Expanded(child: _buildAnimatedScreenStack(context, screens)),
              ],
            ),
          ),
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
      bottomNavigationBar: GlassBottomBar(
        items: const [
          GlassBarItem(
            icon: Icons.timer_outlined,
            label: 'Timer',
            nativeSymbolName: 'timer',
          ),
          GlassBarItem(
            icon: Icons.emoji_events_outlined,
            label: 'Leaderboard',
            nativeSymbolName: 'trophy.fill',
          ),
          GlassBarItem(
            icon: Icons.grid_view_outlined,
            label: 'Analytics',
            nativeSymbolName: 'chart.bar.fill',
          ),
        ],
        currentIndex: _currentIndex,
        onTap: _navigate,
        style: GlassBottomNavStyle(
          accent: accent,
          actionButtonMode: isDark
              ? GlassActionButtonMode.flutter
              : GlassActionButtonMode.nativeLiquidGlassOnIOS26,
        ),
      ),
    );
  }

  /// Keeps each tab alive and slides between them.
  ///
  /// ## Why not a `Stack` with cross-fading children
  ///
  /// That was the previous implementation and it produced a visible artefact on
  /// every navigation: two opaque full-screen widgets were laid out on top of
  /// each other and animated their opacity simultaneously, so mid-transition the
  /// user saw both screens ghosted through one another. It also rebuilt every
  /// screen widget on each transition because the list was constructed inline
  /// in `build`.
  ///
  /// A `PageView` fixes both. Exactly one page is composited at full opacity at
  /// a time, the transition is a real slide rather than a dissolve, and each
  /// page keeps its own `ScrollController`, so returning to a tab restores its
  /// position instead of starting at the top.
  ///
  /// Gesture scrolling is disabled so a horizontal swipe cannot change tabs;
  /// the bar is the single affordance, which matches how the desktop sidebar
  /// behaves.
  Widget _buildAnimatedScreenStack(BuildContext context, List<Widget> screens) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Created lazily and then kept, rather than rebuilt whenever the viewport
    // has no clients. Disposing a controller from inside `build` is a side
    // effect, and it threw away the page offset mid-transition, which is what
    // produced the visible jump between tabs.
    final controller = _pageController ??= PageController(
      initialPage: _currentIndex,
      viewportFraction: 1,
    );

    return PageView.builder(
      controller: controller,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: screens.length,
      onPageChanged: (index) {
        // Fires for swipe gestures too, though physics makes those impossible;
        // kept so the index stays correct if physics is relaxed later.
        if (index != _currentIndex) {
          setState(() => _currentIndex = index);
        }
      },
      itemBuilder: (context, index) {
        return TickerMode(
          // Off-screen tickers must be disabled or hidden animations keep
          // repainting behind the visible page.
          enabled: index == _currentIndex,
          child: ExcludeSemantics(
            // A screen reader should only walk the visible page, otherwise it
            // announces every tab's content on every switch.
            excluding: index != _currentIndex,
            // Centre and cap the page width. Without this the dashboard cards
            // stretch to the full width of a desktop monitor, and the timer
            // ends up marooned in the middle of a very wide row.
            child: constrainContent(
              reduceMotion
                  ? screens[index]
                  : AnimatedSlide(
                      // Directional entrance: the page settles in from the
                      // side it came from rather than always from the right.
                      offset: Offset(_slideDirectionFor(index) * 0.03, 0),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: screens[index],
                    ),
            ),
          ),
        );
      },
    );
  }

  /// -1 when the target page is to the left of the current one, 1 when right.
  double _slideDirectionFor(int targetIndex) {
    if (targetIndex < _currentIndex) return -1;
    return 1;
  }

  /// A glass back/forward pair for drilled-into detail sections.
  ///
  /// Detail sections open as pushed routes, so the shell's tab index has no
  /// memory of them. Without an explicit control there is only the system back
  /// gesture, which does not exist on desktop and is easy to miss on Android.
  ///
  /// The buttons are disabled rather than hidden when there is nothing to go
  /// back to: a control that appears and disappears moves the layout around
  /// under the user's finger, which is worse than a dimmed button.
  Widget _buildDetailNav(
    BuildContext context, {
    required bool canGoBack,
    required bool canGoForward,
  }) {
    final accent = AccentTheme.of(context).accent;
    final navigator = Navigator.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: appString(context, 'Back'),
            child: Semantics(
              button: true,
              enabled: canGoBack,
              label: appString(context, 'Back'),
              excludeSemantics: true,
              child: Opacity(
                opacity: canGoBack ? 1 : 0.35,
                child: _GlassCircleButton(
                  icon: Icons.arrow_back_rounded,
                  accent: accent,
                  onPressed: canGoBack ? () => navigator.maybePop() : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: appString(context, 'Forward'),
            child: Semantics(
              button: true,
              enabled: canGoForward,
              label: appString(context, 'Forward'),
              excludeSemantics: true,
              child: Opacity(
                opacity: canGoForward ? 1 : 0.35,
                child: _GlassCircleButton(
                  icon: Icons.arrow_forward_rounded,
                  accent: accent,
                  onPressed: canGoForward ? () => _forward(context) : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns to the tab that was showing before a detail section was pushed.
  ///
  /// A pushed route does not change the tab index, so popping back to the shell
  /// is the whole action. Guarded because it is only enabled when a route above
  /// the shell actually exists.
  void _forward(BuildContext context) {
    Navigator.of(context).maybePop();
  }
}

/// The circular glass button used by the detail nav.
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback? onPressed;

  const _GlassCircleButton({
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surface.withValues(alpha: 0.82),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.3 : 0.07,
                ),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
        ),
      ),
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
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? accent
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Keyboard shortcut badge, excluded from the button's own label
                // so it does not read as trailing content ("Timer 1").
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
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
                ),
              ],
            ),
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

/// Carries a shell action through the `Shortcuts`/`Actions` pair.
///
/// The action is a stable string rather than a class per action so the shortcut
/// map and the switch below stay in one readable list.
class _AppIntent extends Intent {
  final String action;
  const _AppIntent(this.action);
}
