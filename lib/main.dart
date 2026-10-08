import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:standup_app/core/app_theme.dart';
import 'package:standup_app/data/local/app_database.dart';
import 'package:standup_app/data/local/local_repository.dart';
import 'package:standup_app/data/local/widget_action_dispatcher.dart';
import 'package:standup_app/data/remote/supabase_service.dart';
import 'package:standup_app/providers/app_state.dart';
import 'package:standup_app/services/audio_service.dart';
import 'package:standup_app/services/notification_service.dart';
import 'package:standup_app/ui/screens/main_shell.dart';
import 'package:standup_app/ui/screens/onboarding/onboarding_screen.dart';
import 'package:standup_app/ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');

  // 1. Initialize Drift Local Database
  final db = AppDatabase();
  final localRepo = LocalDatabaseRepository(db);

  // 2. Initialize Supabase Service
  final supabaseService = SupabaseService();
  await supabaseService.initialize();

  // 3. Initialize Audio & Notification Services
  final audioService = AudioService();
  final notificationService = NotificationService();
  final storedLanguage = (await SharedPreferences.getInstance()).getString(
    'language_code',
  );
  await notificationService.initialize(
    languageCode: storedLanguage == 'en' ? 'en' : 'fr',
  );

  // 4. Initialize Core App State
  final appState = AppState(
    localRepo: localRepo,
    supabaseService: supabaseService,
    notificationService: notificationService,
    audioService: audioService,
  );
  notificationService.onActionReceived = appState.handleNotificationAction;
  await appState.init();
  await notificationService.dispatchLaunchAction();

  // 5. Register the headless handler for home-screen widget actions, so a
  // stand-up can be logged from the launcher while the app is closed. This is
  // registered outside the isolate above on purpose: the plugin stores the
  // callback handle and re-invokes it in a background engine later.
  await registerWidgetBackgroundAction();

  runApp(StandUpApp(appState: appState));
}

class StandUpApp extends StatefulWidget {
  final AppState appState;

  const StandUpApp({super.key, required this.appState});

  @override
  State<StandUpApp> createState() => _StandUpAppState();
}

class _StandUpAppState extends State<StandUpApp> with WidgetsBindingObserver {
  bool _splashCompleted = false;
  bool _forceOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.appState.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.appState.onAppResumed());
    }
  }

  ThemeMode _resolveThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final prefs = widget.appState.preferences;
        final colorSystem = prefs.colorSystem;

        final lightTheme = AppTheme.buildTheme(
          brightness: Brightness.light,
          colorSystem: colorSystem,
        );
        final darkTheme = AppTheme.buildTheme(
          brightness: Brightness.dark,
          colorSystem: colorSystem,
        );

        Widget currentScreen;
        String currentScreenKey;
        if (!_splashCompleted) {
          currentScreenKey = 'splash';
          currentScreen = SplashScreen(
            appState: widget.appState,
            onSplashFinished: () {
              setState(() => _splashCompleted = true);
            },
          );
        } else if (!prefs.onboardingCompleted || _forceOnboarding) {
          currentScreenKey = _forceOnboarding
              ? 'onboarding-replay'
              : 'onboarding';
          currentScreen = OnboardingScreen(
            appState: widget.appState,
            onFinish: () {
              setState(() => _forceOnboarding = false);
            },
          );
        } else {
          currentScreenKey = 'home';
          currentScreen = MainShell(
            appState: widget.appState,
            onRerunOnboarding: () {
              setState(() => _forceOnboarding = true);
            },
          );
        }

        return MaterialApp(
          title: widget.appState.languageCode == 'fr'
              ? 'CSPH • Bien-être au travail'
              : 'CSPH • StandUp Wellness',
          locale: Locale(widget.appState.languageCode),
          supportedLocales: const [Locale('fr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          themeMode: _resolveThemeMode(prefs.themeMode),
          theme: lightTheme,
          darkTheme: darkTheme,
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, .018),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(currentScreenKey),
              child: currentScreen,
            ),
          ),
        );
      },
    );
  }
}
