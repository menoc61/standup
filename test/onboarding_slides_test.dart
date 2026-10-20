import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/ui/screens/onboarding/slide_widgets.dart';

void main() {
  /// The shell wraps every slide in a scroll view; these tests do the same so
  /// the 320 px case matches what a small phone actually renders.
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('ProfileSetupSlide', () {
    testWidgets('renders inline errors without overflowing a 320 px phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final name = TextEditingController();
      final designation = TextEditingController();
      final email = TextEditingController();
      addTearDown(name.dispose);
      addTearDown(designation.dispose);
      addTearDown(email.dispose);

      await tester.pumpWidget(
        host(
          ProfileSetupSlide(
            nameController: name,
            designationController: designation,
            emailController: email,
            selectedDepartment: 'Engineering',
            onDepartmentChanged: (_) {},
            accentColor: AppColors.getAccentColor(AppColors.defaultAccentId),
            nameError: 'Enter your full name.',
            designationError: 'Enter your role or designation.',
            emailError: 'Enter a valid work email address.',
          ),
        ),
      );

      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(find.text('Enter your role or designation.'), findsOneWidget);
      expect(find.text('Enter a valid work email address.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The error text is part of the field, not a separate banner: scrolling
      // the phone must still reach the last field.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -240),
      );
      await tester.pump();
      expect(find.text('Work Email (Optional)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports keystrokes so the parent can clear stale errors', (
      tester,
    ) async {
      final name = TextEditingController();
      final designation = TextEditingController();
      final email = TextEditingController();
      addTearDown(name.dispose);
      addTearDown(designation.dispose);
      addTearDown(email.dispose);

      final edits = <String>[];
      await tester.pumpWidget(
        host(
          ProfileSetupSlide(
            nameController: name,
            designationController: designation,
            emailController: email,
            selectedDepartment: 'Engineering',
            onDepartmentChanged: (_) {},
            accentColor: AppColors.getAccentColor(AppColors.defaultAccentId),
            onChanged: edits.add,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Mony Aye');
      expect(edits, isNotEmpty);
      expect(name.text, 'Mony Aye');
    });
  });

  group('OrganizationLinkSlide', () {
    testWidgets('asks for an invite code when signed in', (tester) async {
      await tester.pumpWidget(
        host(
          OrganizationLinkSlide(
            joinedOrganizationName: '',
            signedIn: true,
            onJoin: (_) async => 'CNPS',
            accentColor: AppColors.getAccentColor(AppColors.defaultAccentId),
          ),
        ),
      );

      expect(find.text('Invite code'), findsOneWidget);
      await tester.tap(find.text('Join workspace'));
      await tester.pump();

      expect(
        find.text('Enter the invite code from your administrator.'),
        findsOneWidget,
      );
    });

    testWidgets('joins with the typed code and shows the workspace', (
      tester,
    ) async {
      String? usedCode;
      await tester.pumpWidget(
        host(
          OrganizationLinkSlide(
            joinedOrganizationName: '',
            signedIn: true,
            onJoin: (code) async {
              usedCode = code;
              return 'CNPS';
            },
            accentColor: AppColors.getAccentColor(AppColors.defaultAccentId),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'CNPS-7H2K-9QX4');
      await tester.tap(find.text('Join workspace'));
      await tester.pumpAndSettle();

      expect(usedCode, 'CNPS-7H2K-9QX4');
      expect(find.text('CNPS'), findsOneWidget);
      expect(find.text('Detected Workspace:'), findsOneWidget);
    });

    testWidgets('surfaces the server refusal verbatim', (tester) async {
      await tester.pumpWidget(
        host(
          OrganizationLinkSlide(
            joinedOrganizationName: '',
            signedIn: true,
            onJoin: (_) async => throw Exception('Workspace not found.'),
            accentColor: AppColors.getAccentColor(AppColors.defaultAccentId),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'WRONG-CODE');
      await tester.tap(find.text('Join workspace'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Workspace not found.'), findsOneWidget);
    });

    testWidgets('explains how to join when there is no account yet', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          OrganizationLinkSlide(
            joinedOrganizationName: '',
            signedIn: false,
            onJoin: (_) async => '',
            accentColor: AppColors.getAccentColor(AppColors.defaultAccentId),
          ),
        ),
      );

      expect(find.byType(TextField), findsNothing);
      expect(
        find.textContaining('Connect your account in Settings'),
        findsOneWidget,
      );
    });
  });
}
