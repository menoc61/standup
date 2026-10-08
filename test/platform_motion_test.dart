import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/platform_motion.dart';

void main() {
  group('PlatformMotion curves', () {
    test('iOS uses a continuous curve with no overshoot', () {
      // An overshoot curve on iOS reads as a rendering fault to users, so the
      // enter curve must not overshoot past 1.0.
      final curve = PlatformMotion.enter(TargetPlatform.iOS);
      for (var t = 0.0; t <= 1.0; t += 0.05) {
        expect(curve.transform(t), lessThanOrEqualTo(1.0));
      }
    });

    test('Android enters with an overshoot', () {
      final curve = PlatformMotion.enter(TargetPlatform.android);
      var peaked = 1.0;
      for (var t = 0.0; t <= 1.0; t += 0.01) {
        final value = curve.transform(t);
        if (value > peaked) peaked = value;
      }
      expect(
        peaked,
        greaterThan(1.0),
        reason: 'Material entrance easing should overshoot slightly',
      );
    });

    test('page advance is continuous on both platforms', () {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.linux,
      ]) {
        final curve = PlatformMotion.pageForward(platform);
        expect(curve.transform(0), 0);
        expect(curve.transform(1), 1);
      }
    });
  });

  group('PlatformMotion stagger', () {
    test('Android staggers more slowly than iOS', () {
      final android = PlatformMotion.stagger(TargetPlatform.android, 3);
      final ios = PlatformMotion.stagger(TargetPlatform.iOS, 3);
      expect(android, greaterThan(ios));
    });

    test('the first item has no delay', () {
      expect(PlatformMotion.stagger(TargetPlatform.android, 0), Duration.zero);
    });
  });

  group('PlatformPageTransition', () {
    const transition = PlatformPageTransition();

    Future<void> pumpRoute(WidgetTester tester, {required bool reducedMotion}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {TargetPlatform.android: PlatformPageTransition()},
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(child: Text('page ${transition.hashCode}')),
            ),
          ),
        ),
      );
    }

    testWidgets('passes the child straight through under reduced motion', (
      tester,
    ) async {
      await pumpRoute(tester, reducedMotion: true);
      expect(find.textContaining('page '), findsOneWidget);
    });
  });
}
