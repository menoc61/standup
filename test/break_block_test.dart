import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_strings.dart';
import 'package:standup_app/core/break_block.dart';
import 'package:standup_app/ui/widgets/break_block.dart';

/// The forced-break rule is four independent vetoes. Each one is a real failure
/// the app must avoid, so each is pinned here rather than trusted.
void main() {
  group('shouldBlockBreak', () {
    // Mirrors the pure rule's parameter list with the "everything is fine"
    // defaults, so each test states exactly the one condition it is about.
    bool block({
      bool blockingEnabled = true,
      bool userAway = false,
      bool windowOpen = true,
      bool alreadyCompleted = false,
      bool breakInProgress = false,
      bool quiet = false,
    }) => shouldBlockBreak(
      blockingEnabled: blockingEnabled,
      userAway: userAway,
      windowOpen: windowOpen,
      alreadyCompleted: alreadyCompleted,
      breakInProgress: breakInProgress,
      quiet: quiet,
    );

    test('blocks only when every condition is met', () {
      expect(block(), isTrue);
    });

    test('a user who never opted in is never blocked', () {
      expect(block(blockingEnabled: false), isFalse);
    });

    test('an absent user is never blocked', () {
      // Seizing the screen of somebody in a meeting is worse than a missed
      // break.
      expect(block(userAway: true), isFalse);
    });

    test('outside the break window nothing is blocked', () {
      expect(block(windowOpen: false), isFalse);
    });

    test('a logged break lifts the block immediately', () {
      expect(block(alreadyCompleted: true), isFalse);
    });

    test('the guided stretch is not covered over', () {
      // The stretch screen already owns the UI; a cover on top of it would
      // fight the flow the block exists to encourage.
      expect(block(breakInProgress: true), isFalse);
    });

    test('quiet mode outranks every other reason to take the screen', () {
      // A demo, a call, a presentation: the moment a takeover would be most
      // damaging is the moment the user asked for quiet.
      expect(block(quiet: true), isFalse);
    });
  });

  group('BreakBlockScreen', () {
    final endsAt = DateTime.now().add(const Duration(minutes: 5));

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

    testWidgets('states the rule and counts down to the unlock', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(BreakBlockScreen(endsAt: endsAt, onStoodUp: () {})),
      );

      expect(find.text('Time to stand up'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^Unlocks in \d{2}:\d{2}$')),
        findsOneWidget,
      );
      expect(find.text('I stood up'), findsOneWidget);
    });

    testWidgets('logging the break invokes the callback', (tester) async {
      var logged = 0;
      await tester.pumpWidget(
        wrap(BreakBlockScreen(endsAt: endsAt, onStoodUp: () => logged++)),
      );

      await tester.tap(find.text('I stood up'));
      await tester.pump();
      expect(logged, 1);
    });

    testWidgets('a completion in flight cannot be double-tapped', (
      tester,
    ) async {
      var logged = 0;
      await tester.pumpWidget(
        wrap(
          BreakBlockScreen(
            endsAt: endsAt,
            standing: true,
            onStoodUp: () => logged++,
          ),
        ),
      );

      await tester.tap(find.text('I stood up'));
      await tester.pump();
      expect(logged, 0);
    });

    testWidgets('a window that already closed never shows negative time', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BreakBlockScreen(
            endsAt: DateTime.now().subtract(const Duration(minutes: 1)),
            onStoodUp: () {},
          ),
        ),
      );

      expect(find.text('Unlocks in 00:00'), findsOneWidget);
    });

    testWidgets('renders French copy when the locale is French', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BreakBlockScreen(endsAt: endsAt, onStoodUp: () {}),
          locale: const Locale('fr'),
        ),
      );

      expect(find.text('Debout !'), findsOneWidget);
      expect(find.text('Je me suis levé·e'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^Déblocage dans \d{2}:\d{2}$')),
        findsOneWidget,
      );
    });

    test('every visible string has a French entry', () {
      for (final literal in [
        'Time to stand up',
        'Stand, stretch and breathe. This screen lifts when the break ends or when you log it.',
        'Unlocks in {time}',
        'I stood up',
      ]) {
        expect(
          hasFrenchTranslation(literal),
          isTrue,
          reason: '"$literal" would fall back to English in French mode',
        );
      }
    });
  });
}
