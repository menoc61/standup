import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/providers/app_state.dart';

class SplashScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onSplashFinished;

  const SplashScreen({
    super.key,
    required this.appState,
    required this.onSplashFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Advances to the next screen. Held in a field so [dispose] can cancel it.
  ///
  /// An unheld `Timer` outlives its `State` and keeps the closure — and
  /// everything it captures — reachable until it fires.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Play subtle entry sound
    widget.appState.audioService.playChime();

    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      widget.onSplashFinished();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.getAccentColor(
      widget.appState.preferences.colorSystem,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The supplied CSPH StandUp mark is also the installed app icon.
            Container(
                  width: 184,
                  height: 164,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: accent.withValues(alpha: 0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.13),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset(
                      'assets/branding/csph_standup_logo.png',
                      fit: BoxFit.contain,
                      semanticLabel: 'CSPH StandUp',
                    ),
                  ),
                )
                .animate()
                .scale(duration: 800.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 600.ms),
            const SizedBox(height: 32),

            // Title
            Text(
                  appString(context, 'StandUp'),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),

            const SizedBox(height: 8),

            // Tagline
            Text(
              appString(context, 'EMPLOYEE HEALTH & WELLNESS CADENCE'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: accent,
              ),
            ).animate().fadeIn(delay: 500.ms, duration: 600.ms),

            const SizedBox(height: 48),

            // Loading dots indicator
            SizedBox(
              width: 48,
              child: LinearProgressIndicator(
                backgroundColor: accent.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
