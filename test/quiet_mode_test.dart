import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/ui/widgets/quiet_mode_banner.dart';

/// Quiet mode suppresses reminders, which makes it indistinguishable from a
/// broken app unless it says so. These tests pin that it does say so, in both
/// languages, and that the way back is one tap.
void main() {
  Widget wrap(Widget child, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );
  }

  testWidgets('explains the state and offers the way back', (tester) async {
    await tester.pumpWidget(wrap(QuietModeBanner(onResume: () {})));

    expect(find.text('Quiet mode'), findsOneWidget);
    expect(
      find.text(
        'Reminders and the forced break are paused until you resume or restart StandUp.',
      ),
      findsOneWidget,
    );
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('resuming invokes the callback exactly once', (tester) async {
    var resumes = 0;
    await tester.pumpWidget(wrap(QuietModeBanner(onResume: () => resumes++)));

    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(resumes, 1);
  });

  testWidgets('renders French copy when the locale is French', (tester) async {
    await tester.pumpWidget(
      wrap(QuietModeBanner(onResume: () {}), locale: const Locale('fr')),
    );

    expect(find.text('Mode silencieux'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
  });

  test('every visible string has a French entry', () {
    for (final literal in [
      'Quiet mode',
      'Reminders and the forced break are paused until you resume or restart StandUp.',
      'Resume',
      'Pause reminders',
      'Resume reminders',
    ]) {
      expect(
        hasFrenchTranslation(literal),
        isTrue,
        reason: '"$literal" would fall back to English in French mode',
      );
    }
  });
}
