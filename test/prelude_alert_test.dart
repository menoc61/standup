import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/ui/widgets/prelude_alert.dart';

/// Widget-level checks for the prelude banner. These run against the pure
/// presentation widget, so they do not need an `AppState`.
void main() {
  final breakAt = DateTime.now().add(const Duration(minutes: 5));

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

  testWidgets('shows a countdown to the break and the heads-up copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PreludeBanner(
          breakAt: breakAt,
          onDismiss: () {},
          reduceMotionOverride: true,
        ),
      ),
    );

    // The exact seconds depend on the wall clock, so the shape is asserted.
    expect(
      find.textContaining(RegExp(r'^Break in \d{2}:\d{2}$')),
      findsOneWidget,
    );
    expect(
      find.text('Wrap up what you are doing and get ready to stand.'),
      findsOneWidget,
    );
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('dismiss invokes the callback', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      wrap(
        PreludeBanner(
          breakAt: breakAt,
          onDismiss: () => dismissed++,
          reduceMotionOverride: true,
        ),
      ),
    );

    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(dismissed, 1);
  });

  testWidgets('renders French copy when the locale is French', (tester) async {
    await tester.pumpWidget(
      wrap(
        PreludeBanner(
          breakAt: breakAt,
          onDismiss: () {},
          reduceMotionOverride: true,
        ),
        locale: const Locale('fr'),
      ),
    );

    expect(
      find.textContaining(RegExp(r'^Pause dans \d{2}:\d{2}$')),
      findsOneWidget,
    );
    expect(find.text('Compris'), findsOneWidget);
  });

  test('the prelude copy has a French entry for every visible string', () {
    for (final literal in [
      'Wrap up what you are doing and get ready to stand.',
      'Got it',
      'Break in {time}',
    ]) {
      expect(
        hasFrenchTranslation(literal),
        isTrue,
        reason: '"$literal" would fall back to English in French mode',
      );
    }
  });
}
