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
      bool escalationDue = false,
    }) => shouldBlockBreak(
      blockingEnabled: blockingEnabled,
      userAway: userAway,
      windowOpen: windowOpen,
      alreadyCompleted: alreadyCompleted,
      breakInProgress: breakInProgress,
      quiet: quiet,
      escalationDue: escalationDue,
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

    group('escalation', () {
      test('a streak of ignored breaks raises the cover on its own', () {
        // The employee armed this one; it is a second opt-in, not an exception
        // to the first.
        expect(block(blockingEnabled: false, escalationDue: true), isTrue);
      });

      test('two opt-ins that are both off still never cover', () {
        expect(block(blockingEnabled: false, escalationDue: false), isFalse);
      });

      test(
        'an empty desk vetoes an escalation exactly as it vetoes a block',
        () {
          // This is the case the whole presence subsystem exists for: a streak
          // must never seize the screen of somebody who is not there.
          expect(
            block(blockingEnabled: false, escalationDue: true, userAway: true),
            isFalse,
          );
        },
      );

      test('quiet mode silences an escalation too', () {
        expect(
          block(blockingEnabled: false, escalationDue: true, quiet: true),
          isFalse,
        );
      });

      test('an escalation outside a window cannot cover anything', () {
        expect(
          block(blockingEnabled: false, escalationDue: true, windowOpen: false),
          isFalse,
        );
      });

      test('a logged break lifts an escalated cover immediately', () {
        expect(
          block(
            blockingEnabled: false,
            escalationDue: true,
            alreadyCompleted: true,
          ),
          isFalse,
        );
      });
    });
  });

  group('breakBlockView', () {
    BreakBlockView view({
      bool active = true,
      bool windowOpen = true,
      bool coverEligible = true,
      bool coverRequestedStretch = false,
      bool breakInProgress = false,
    }) => breakBlockView(
      active: active,
      windowOpen: windowOpen,
      coverEligible: coverEligible,
      coverRequestedStretch: coverRequestedStretch,
      breakInProgress: breakInProgress,
    );

    test('the cover shows when it is eligible and no routine is running', () {
      expect(view(), BreakBlockView.cover);
    });

    test('nothing shows outside a window, on splash, or once logged', () {
      expect(view(windowOpen: false), BreakBlockView.none);
      expect(view(active: false), BreakBlockView.none);
      expect(view(coverEligible: false), BreakBlockView.none);
    });

    test('a routine started from the cover keeps the routine on screen', () {
      // `shouldBlockBreak` vetoes the cover while a break is in progress, so
      // without this the routine would vanish on the very tap that started it.
      expect(
        view(
          coverEligible: false,
          coverRequestedStretch: true,
          breakInProgress: true,
        ),
        BreakBlockView.guidedStretch,
      );
    });

    test('a routine started from the dashboard never summons the cover', () {
      // It is already visible in its own sheet; taking over the whole window
      // would render the same routine twice, over the dashboard that asked.
      expect(
        view(coverEligible: false, breakInProgress: true),
        BreakBlockView.none,
      );
    });

    test('a routine that has already ended leaves the window alone', () {
      expect(
        view(coverEligible: false, coverRequestedStretch: true),
        BreakBlockView.none,
      );
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

    testWidgets('offers the guided routine only when a caller provides one', (
      tester,
    ) async {
      // Without a callback the cover keeps its single authoritative action, so
      // every existing rendering of it is unchanged.
      await tester.pumpWidget(
        wrap(BreakBlockScreen(endsAt: endsAt, onStoodUp: () {})),
      );
      expect(find.text('Guided 5-minute stretch'), findsNothing);

      var stretches = 0;
      await tester.pumpWidget(
        wrap(
          BreakBlockScreen(
            endsAt: endsAt,
            onStoodUp: () {},
            onStartStretch: () => stretches++,
          ),
        ),
      );
      expect(find.text('Guided 5-minute stretch'), findsOneWidget);
      await tester.tap(find.text('Guided 5-minute stretch'));
      await tester.pump();
      expect(stretches, 1);
      // Standing up is still the primary action and still works.
      expect(find.text('I stood up'), findsOneWidget);
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

    testWidgets(
      'anti-cheat delay disables "I stood up" until minWaitSeconds passes',
      (tester) async {
        var logged = 0;
        await tester.pumpWidget(
          wrap(
            BreakBlockScreen(
              endsAt: endsAt,
              minWaitSeconds: 30,
              onStoodUp: () => logged++,
            ),
          ),
        );

        // Initially locked with warning message
        expect(
          find.text('Please step away from your desk (30s)'),
          findsOneWidget,
        );
        await tester.tap(find.text('I stood up'));
        await tester.pump();
        expect(logged, 0);

        // Advance 30 seconds
        await tester.pump(const Duration(seconds: 30));
        await tester.pump();
        expect(
          find.text('Please step away from your desk (30s)'),
          findsNothing,
        );

        // Now unlocked and tap succeeds
        await tester.tap(find.text('I stood up'));
        await tester.pump();
        expect(logged, 1);
      },
    );

    testWidgets('a late arrival never waits past the closing window', (
      tester,
    ) async {
      // The cover lifts when the window closes, so a wait longer than the
      // window would leave the countdown pointing at a button that disappears
      // before it unlocks.
      var logged = 0;
      await tester.pumpWidget(
        wrap(
          BreakBlockScreen(
            endsAt: DateTime.now().add(const Duration(seconds: 20)),
            minWaitSeconds: 30,
            onStoodUp: () => logged++,
          ),
        ),
      );

      expect(find.text('Please step away from your desk (30s)'), findsNothing);
      expect(
        find.textContaining('Please step away from your desk ('),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 40));
      await tester.pump();
      await tester.tap(find.text('I stood up'));
      await tester.pump();
      expect(logged, 1);
    });

    testWidgets('a window that has already closed skips the delay', (
      tester,
    ) async {
      var logged = 0;
      await tester.pumpWidget(
        wrap(
          BreakBlockScreen(
            endsAt: DateTime.now().subtract(const Duration(minutes: 1)),
            minWaitSeconds: 30,
            onStoodUp: () => logged++,
          ),
        ),
      );

      expect(find.textContaining('Please step away'), findsNothing);
      await tester.tap(find.text('I stood up'));
      await tester.pump();
      expect(logged, 1);
    });

    test('every visible string has a French entry', () {
      for (final literal in [
        'Time to stand up',
        'Stand, stretch and breathe. This screen lifts when the break ends or when you log it.',
        'Unlocks in {time}',
        'Please step away from your desk ({seconds}s)',
        'I stood up',
        'Guided 5-minute stretch',
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
