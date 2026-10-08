import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/ui/layout/adaptive.dart';

void main() {
  group('Window classification', () {
    test('a phone-sized allocation is compact', () {
      expect(windowClassForWidth(360), WindowClass.compact);
      expect(windowClassForWidth(414), WindowClass.compact);
    });

    test('a breakpoint boundary belongs to the wider class', () {
      // Off-by-one here is what produces a layout that flickers when a desktop
      // window is dragged across the breakpoint.
      expect(windowClassForWidth(kMediumMinWidth - 1), WindowClass.compact);
      expect(windowClassForWidth(kMediumMinWidth), WindowClass.medium);
      expect(windowClassForWidth(kExpandedMinWidth - 1), WindowClass.medium);
      expect(windowClassForWidth(kExpandedMinWidth), WindowClass.expanded);
    });

    test('a very wide window stays expanded rather than falling through', () {
      expect(windowClassForWidth(3840), WindowClass.expanded);
    });

    test('zero width does not collapse the layout', () {
      expect(windowClassForWidth(0), WindowClass.compact);
    });

    test('classification reads the allocation, not the window', () {
      // A narrow column inside a wide window must classify as compact. This is
      // the case MediaQuery.sizeOf gets wrong.
      final nested = const BoxConstraints(maxWidth: 400);
      final root = const BoxConstraints(maxWidth: 1600);

      expect(windowClassOf(nested), WindowClass.compact);
      expect(windowClassOf(root), WindowClass.expanded);
    });
  });

  group('Sidebar navigation', () {
    test('only the expanded class gets a sidebar', () {
      expect(
        useSidebarNavigation(const BoxConstraints(maxWidth: 719)),
        isFalse,
      );
      expect(useSidebarNavigation(const BoxConstraints(maxWidth: 720)), isTrue);
    });

    test('a resized desktop window swaps navigation live', () {
      expect(
        useSidebarNavigation(const BoxConstraints(maxWidth: 1400)),
        isTrue,
      );
      expect(
        useSidebarNavigation(const BoxConstraints(maxWidth: 600)),
        isFalse,
      );
    });
  });

  group('Grid columns', () {
    test('never returns zero, so a grid is never a zero-height sliver', () {
      for (final width in <double>[0, 100, 599, 600, 719, 720, 2000]) {
        expect(
          gridColumnCount(BoxConstraints(maxWidth: width)),
          greaterThan(0),
          reason: 'width $width produced no columns',
        );
      }
    });

    test('a single column is used on a phone and two on anything wider', () {
      expect(gridColumnCount(const BoxConstraints(maxWidth: 390)), 1);
      expect(gridColumnCount(const BoxConstraints(maxWidth: 700)), 2);
      expect(gridColumnCount(const BoxConstraints(maxWidth: 1600)), 2);
    });
  });

  group('Content width cap', () {
    testWidgets('an over-wide child is clamped to the cap and centred', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(2000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Asking for 3000px inside a 2000px window proves the clamp is what
      // bounds it, rather than the window simply being narrow enough.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: constrainContent(const SizedBox(width: 3000, height: 40)),
          ),
        ),
      );

      final box = tester.getRect(find.byType(SizedBox).first);
      expect(box.width, kContentMaxWidth);
      // Centred means the leftover space is split evenly on both sides.
      expect(box.left, closeTo((2000 - kContentMaxWidth) / 2, 0.5));
    });

    testWidgets('a child narrower than the cap keeps its own width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(2000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: constrainContent(const SizedBox(width: 320, height: 40)),
          ),
        ),
      );

      final box = tester.getRect(find.byType(SizedBox).first);
      expect(box.width, 320);
    });

    testWidgets('a narrow window is not constrained at all', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: constrainContent(const SizedBox(height: 40)),
          ),
        ),
      );

      final box = tester.getRect(find.byType(SizedBox).first);
      expect(box.width, lessThanOrEqualTo(390));
    });
  });
}
