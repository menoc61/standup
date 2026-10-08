import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/core/platform_motion.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/haptics_service.dart';
import 'package:standup_app/ui/screens/onboarding/slide_widgets.dart';
import 'package:standup_app/ui/widgets/spring_button.dart';

class OnboardingScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onFinish;

  const OnboardingScreen({
    super.key,
    required this.appState,
    required this.onFinish,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 10;

  // Form State
  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _emailController;

  String _department = 'Engineering';
  final String _detectedOrgName = '';
  int _frequency = 60;
  String _themeMode = 'system';
  String _colorSystem = AppColors.defaultAccentId;
  bool _soundEnabled = true;
  bool _optIn = false;
  bool _permissionsGranted = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.appState.userProfile;
    final prefs = widget.appState.preferences;

    _nameController = TextEditingController(
      text: profile?.name == 'Employee' ? '' : profile?.name ?? '',
    );
    _designationController = TextEditingController(
      text: profile?.designation ?? '',
    );
    _emailController = TextEditingController(text: profile?.email ?? '');

    _department = profile?.department ?? 'Engineering';
    _frequency = prefs.notificationFrequency;
    _themeMode = prefs.themeMode;
    _colorSystem = prefs.colorSystem;
    _soundEnabled = prefs.soundEnabled;
    _optIn = prefs.statisticsOptIn;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _designationController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Asks before abandoning onboarding, which would otherwise be silent because
  /// the app cannot be popped from this screen.
  Future<void> _confirmExit(BuildContext context) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appString(context, 'Leave setup?')),
        content: Text(
          appString(context, 'Your progress in this walkthrough will be lost.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(appString(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(appString(context, 'Leave')),
          ),
        ],
      ),
    );
    if (shouldLeave == true) SystemNavigator.pop();
  }

  /// Jumps directly to a step, used by the progress dots.
  void _goToPage(int index) {
    if (index == _currentPage || index < 0 || index >= _totalPages) return;
    unawaited(HapticsService.selection());
    _pageController.animateToPage(
      index,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : PlatformMotion.pageDuration,
      curve: PlatformMotion.pageForward(Theme.of(context).platform),
    );
  }

  /// Asks before abandoning onboarding, which would otherwise be silent because
  /// the app cannot be popped from this screen.
  void _goToNextPage() {
    unawaited(widget.appState.audioService.playClick());
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : PlatformMotion.pageDuration,
        curve: PlatformMotion.pageForward(Theme.of(context).platform),
      );
    } else {
      _completeOnboarding();
    }
  }

  void _goToPreviousPage() {
    unawaited(widget.appState.audioService.playClick());
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : PlatformMotion.pageDuration,
        curve: PlatformMotion.pageBackward(Theme.of(context).platform),
      );
    }
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    widget.appState.audioService.playSuccess();
    try {
      await widget.appState.updateProfile(
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Employee',
        designation: _designationController.text.trim(),
        department: _department,
        email: _emailController.text.trim(),
      );

      await widget.appState.updatePreferences(
        themeMode: _themeMode,
        colorSystem: _colorSystem,
        notificationFrequency: _frequency,
        soundEnabled: _soundEnabled,
        statisticsOptIn: _optIn,
        onboardingCompleted: true,
      );

      widget.onFinish();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isCompleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appStringArgs(
              context,
              'Could not save your setup. Please try again. ({reason})',
              {'reason': '$error'},
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.getAccentColor(_colorSystem);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final stepLabels = [
      'Welcome',
      'Why movement matters',
      'A simple solution',
      'How it works',
      'Your profile',
      'Workspace',
      'Preferences',
      'Notifications',
      'Privacy',
      'Ready',
    ];

    return PopScope(
      // Onboarding is the app's root route, so an unhandled system back would
      // exit the process and throw away every slide of progress including typed
      // profile data. Back is mapped onto the in-app navigation instead: steps
      // backwards on pages 2..10, and asks for confirmation on the first page.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentPage > 0) {
          _goToPreviousPage();
        } else {
          _confirmExit(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _currentPage > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goToPreviousPage,
                )
              : null,
          title: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / _totalPages,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 4,
            ),
          ),
          actions: [
            if (_currentPage < _totalPages - 1)
              TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  appString(context, 'Skip'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, .12),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          stepLabels[_currentPage],
                          key: ValueKey(_currentPage),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    Text(
                      '${_currentPage + 1} / $_totalPages',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth > 920 ? 820 : 720,
                      ),
                      child: PageView(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (idx) =>
                            setState(() => _currentPage = idx),
                        children:
                            [
                              WelcomeSlide(accentColor: accent),
                              TheProblemSlide(accentColor: accent),
                              TheSolutionSlide(accentColor: accent),
                              HowItWorksSlide(accentColor: accent),
                              ProfileSetupSlide(
                                nameController: _nameController,
                                designationController: _designationController,
                                emailController: _emailController,
                                selectedDepartment: _department,
                                onDepartmentChanged: (v) => setState(
                                  () => _department = v ?? _department,
                                ),
                                accentColor: accent,
                              ),
                              OrganizationLinkSlide(
                                detectedOrgName: _detectedOrgName,
                                accentColor: accent,
                              ),
                              PreferencesSlide(
                                selectedFrequency: _frequency,
                                onFrequencyChanged: (v) =>
                                    setState(() => _frequency = v),
                                selectedTheme: _themeMode,
                                onThemeChanged: (v) =>
                                    setState(() => _themeMode = v),
                                selectedColor: _colorSystem,
                                onColorChanged: (v) =>
                                    setState(() => _colorSystem = v),
                                soundEnabled: _soundEnabled,
                                onSoundChanged: (v) =>
                                    setState(() => _soundEnabled = v),
                                onTestSound: () =>
                                    widget.appState.audioService.playChime(),
                              ),
                              PermissionsSlide(
                                granted: _permissionsGranted,
                                onRequest: () async {
                                  final ok = await widget
                                      .appState
                                      .notificationService
                                      .requestPermissions();
                                  if (!mounted) return;
                                  setState(() => _permissionsGranted = ok);
                                  if (ok) {
                                    await widget.appState
                                        .refreshReminderQueue();
                                  }
                                  widget.appState.audioService.playClick();
                                },
                                accentColor: accent,
                              ),
                              PrivacySlide(
                                optIn: _optIn,
                                onOptInChanged: (v) =>
                                    setState(() => _optIn = v),
                                accentColor: accent,
                              ),
                              ReadyToGoSlide(
                                onComplete: _completeOnboarding,
                                accentColor: accent,
                              ),
                            ].asMap().entries.map((entry) {
                              final index = entry.key;
                              final slide = entry.value;
                              final isActive = index == _currentPage;
                              return AnimatedScale(
                                key: ValueKey('onboarding-slide-$index'),
                                scale: isActive ? 1 : .985,
                                duration: reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                child: AnimatedOpacity(
                                  opacity: isActive ? 1 : .76,
                                  duration: reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 220),
                                  child: LayoutBuilder(
                                    builder: (context, slideConstraints) =>
                                        SingleChildScrollView(
                                          physics:
                                              const BouncingScrollPhysics(),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          // This view supplies the scrolling, so
                                          // slides must not nest a second scroll
                                          // view on the same axis: the inner one
                                          // would win the gesture arena and the
                                          // page would silently stop responding.
                                          // IntrinsicHeight is also avoided here
                                          // because it misbehaves around
                                          // scrollables and costs a full extra
                                          // layout pass per slide.
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minHeight:
                                                  (slideConstraints.maxHeight -
                                                          24)
                                                      .clamp(
                                                        0.0,
                                                        double.infinity,
                                                      )
                                                      .toDouble(),
                                            ),
                                            child: slide
                                                .animate(
                                                  key: ValueKey(
                                                    'onboarding-entry-$index',
                                                  ),
                                                )
                                                .fadeIn(
                                                  duration: reduceMotion
                                                      ? Duration.zero
                                                      : 320.ms,
                                                )
                                                .slideY(
                                                  begin: .025,
                                                  duration: reduceMotion
                                                      ? Duration.zero
                                                      : 320.ms,
                                                  curve: Curves.easeOutCubic,
                                                ),
                                          ),
                                        ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom Controls
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dot indicators
                    Row(
                      children: List.generate(_totalPages, (i) {
                        final isSel = i == _currentPage;
                        final compact = MediaQuery.sizeOf(context).width < 440;
                        if (compact) {
                          final firstVisible = (_currentPage - 2)
                              .clamp(0, _totalPages - 5)
                              .toInt();
                          if (i < firstVisible || i >= firstVisible + 5) {
                            return const SizedBox.shrink();
                          }
                        }
                        // Each dot is a jump target. Previously they were
                        // purely decorative, so returning to an earlier step
                        // meant swiping backwards through every intermediate
                        // slide. The hit area is padded out to 44x44 even
                        // though the visual dot is only 5-18px wide.
                        return Semantics(
                          button: true,
                          selected: isSel,
                          label: appString(context, 'Go to step'),
                          value: '${i + 1}',
                          excludeSemantics: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _goToPage(i),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 14,
                              ),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 250),
                                  margin: EdgeInsets.only(
                                    right: compact ? 4 : 5,
                                  ),
                                  width: isSel
                                      ? (compact ? 15 : 18)
                                      : (compact ? 5 : 6),
                                  height: compact ? 5 : 6,
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? accent
                                        : Colors.grey.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    // Next / Continue button
                    if (_currentPage < _totalPages - 1)
                      SpringButton(
                        onTap: _isCompleting ? null : _goToNextPage,
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Text(
                              appString(context, 'Continue'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
