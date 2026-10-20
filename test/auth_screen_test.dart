import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/ui/screens/auth/auth_screen.dart';

void main() {
  Widget host({
    Future<void> Function(String email, String password)? onSignIn,
    Future<bool> Function(String email, String password)? onCreateAccount,
    Future<void> Function(String email)? onSendReset,
    Future<void> Function()? onContinueOffline,
  }) {
    return MaterialApp(
      home: AuthScreen(
        onSignIn: onSignIn ?? (_, _) async {},
        onCreateAccount: onCreateAccount ?? (_, _) async => false,
        onSendReset: onSendReset ?? (_) async {},
        onContinueOffline: onContinueOffline ?? () async {},
      ),
    );
  }

  Finder primaryButton(String label) =>
      find.widgetWithText(FilledButton, label);

  group('AuthScreen', () {
    testWidgets('starts on sign in and offers the offline escape hatch', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      expect(find.text('Sign in to StandUp'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Use this device only'), findsOneWidget);
    });

    testWidgets('blocks submission with empty fields and explains why', (
      tester,
    ) async {
      var signInCalls = 0;
      await tester.pumpWidget(host(onSignIn: (_, _) async => signInCalls++));

      await tester.tap(primaryButton('Sign in'));
      await tester.pump();

      expect(signInCalls, 0);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('creates an account with a short password rejected inline', (
      tester,
    ) async {
      var createCalls = 0;
      await tester.pumpWidget(
        host(
          onCreateAccount: (_, _) async {
            createCalls++;
            return false;
          },
        ),
      );

      await tester.tap(find.text('Create account').last);
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'mony.aye@cnps.cm');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.tap(primaryButton('Create account'));
      await tester.pump();

      expect(createCalls, 0);
      expect(find.text('Use at least 8 characters.'), findsWidgets);
    });

    testWidgets('signs in with the trimmed address and the typed password', (
      tester,
    ) async {
      String? email;
      String? password;
      await tester.pumpWidget(
        host(
          onSignIn: (value, secret) async {
            email = value;
            password = secret;
          },
        ),
      );

      await tester.enterText(
        find.byType(TextField).at(0),
        '  mony.aye@cnps.cm ',
      );
      await tester.enterText(find.byType(TextField).at(1), 'secret-pass');
      await tester.tap(primaryButton('Sign in'));
      await tester.pumpAndSettle();

      expect(email, 'mony.aye@cnps.cm');
      expect(password, 'secret-pass');
    });

    testWidgets('shows a friendly sentence when sign in fails', (tester) async {
      await tester.pumpWidget(
        host(
          onSignIn: (_, _) async =>
              throw Exception('Invalid login credentials'),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'mony.aye@cnps.cm');
      await tester.enterText(find.byType(TextField).at(1), 'wrong-pass');
      await tester.tap(primaryButton('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Email or password is incorrect.'), findsOneWidget);
    });

    testWidgets('explains that a confirmation email is on its way', (
      tester,
    ) async {
      await tester.pumpWidget(host(onCreateAccount: (_, _) async => false));

      await tester.tap(find.text('Create account').last);
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), 'mony.aye@cnps.cm');
      await tester.enterText(find.byType(TextField).at(1), 'secret-pass');
      await tester.tap(primaryButton('Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Check your email to confirm your account, then sign in here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sign in to StandUp'), findsOneWidget);
    });

    testWidgets('sends a reset link and says to check the inbox', (
      tester,
    ) async {
      String? emailed;
      await tester.pumpWidget(
        host(onSendReset: (value) async => emailed = value),
      );

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'mony.aye@cnps.cm');
      await tester.tap(primaryButton('Send reset link'));
      await tester.pumpAndSettle();

      expect(emailed, 'mony.aye@cnps.cm');
      expect(find.text('Check your email for a reset link.'), findsOneWidget);
    });

    testWidgets('can return from the reset mode to sign in', (tester) async {
      await tester.pumpWidget(host());

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();
      await tester.tap(find.text('Back to sign in'));
      await tester.pump();

      expect(find.text('Sign in to StandUp'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets(
      'calls the offline pathway when the device-only path is taken',
      (tester) async {
        var offlineCalls = 0;
        await tester.pumpWidget(
          host(onContinueOffline: () async => offlineCalls++),
        );

        final offline = find.text('Use this device only');
        await tester.ensureVisible(offline);
        await tester.pumpAndSettle();
        await tester.tap(offline);
        await tester.pumpAndSettle();

        expect(offlineCalls, 1);
      },
    );

    testWidgets('does not overflow a 320 px phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Sign in to StandUp'), findsOneWidget);
    });
  });
}
