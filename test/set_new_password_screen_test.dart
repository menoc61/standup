import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/ui/screens/auth/set_new_password_screen.dart';

void main() {
  Widget host({
    Future<void> Function(String password)? onSubmit,
    Future<void> Function()? onCancel,
  }) {
    return MaterialApp(
      home: SetNewPasswordScreen(
        onSubmit: onSubmit ?? (_) async {},
        onCancel: onCancel ?? () async {},
      ),
    );
  }

  Finder primaryButton() =>
      find.widgetWithText(FilledButton, 'Update password');

  group('SetNewPasswordScreen', () {
    testWidgets('renders both password fields and the cancel action', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      expect(find.text('Set a new password'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('rejects a short password before calling the server', (
      tester,
    ) async {
      var submissions = 0;
      await tester.pumpWidget(
        host(
          onSubmit: (_) async {
            submissions++;
          },
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'short');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.tap(primaryButton());
      await tester.pump();

      expect(submissions, 0);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
    });

    testWidgets('rejects a mismatched confirmation', (tester) async {
      var submissions = 0;
      await tester.pumpWidget(
        host(
          onSubmit: (_) async {
            submissions++;
          },
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'secret-pass');
      await tester.enterText(find.byType(TextField).at(1), 'secret-past');
      await tester.tap(primaryButton());
      await tester.pump();

      expect(submissions, 0);
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('submits a matching password once', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        host(
          onSubmit: (value) async {
            submitted = value;
          },
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'secret-pass');
      await tester.enterText(find.byType(TextField).at(1), 'secret-pass');
      await tester.tap(primaryButton());
      await tester.pumpAndSettle();

      expect(submitted, 'secret-pass');
    });

    testWidgets('keeps the form open with an explanation when saving fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(onSubmit: (_) async => throw Exception('Some provider detail')),
      );

      await tester.enterText(find.byType(TextField).at(0), 'secret-pass');
      await tester.enterText(find.byType(TextField).at(1), 'secret-pass');
      await tester.tap(primaryButton());
      await tester.pumpAndSettle();

      expect(find.text('Some provider detail'), findsOneWidget);
      expect(find.text('Set a new password'), findsOneWidget);
    });

    testWidgets('cancels the recovery session', (tester) async {
      var cancels = 0;
      await tester.pumpWidget(host(onCancel: () async => cancels++));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cancels, 1);
    });

    testWidgets('does not overflow a 320 px phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Set a new password'), findsOneWidget);
    });
  });
}
