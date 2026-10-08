import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/ui/widgets/segmented_choice.dart';

/// The theme and accent pickers are the two controls a user reaches for to make
/// the app feel like theirs, and both are now this widget. The tests here pin the
/// behaviour that a plain row of `InkWell`s got wrong: no announced selected
/// state, and no keyboard operation.
void main() {
  Widget host({
    required String selected,
    required ValueChanged<String> onChanged,
    List<SegmentedOption<String>>? options,
    FocusNode? focusNode,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SegmentedChoice<String>(
            semanticLabel: 'App Theme Mode',
            focusNode: focusNode,
            selected: selected,
            onChanged: onChanged,
            options:
                options ??
                const [
                  SegmentedOption(
                    value: 'system',
                    label: 'System',
                    icon: Icons.brightness_auto_outlined,
                  ),
                  SegmentedOption(
                    value: 'light',
                    label: 'Light',
                    icon: Icons.light_mode_outlined,
                  ),
                  SegmentedOption(
                    value: 'dark',
                    label: 'Dark',
                    icon: Icons.dark_mode_outlined,
                  ),
                ],
          ),
        ),
      ),
    );
  }

  group('Selection', () {
    testWidgets('tapping an option reports its value', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(host(selected: 'system', onChanged: picked.add));

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(picked, ['dark']);
    });

    testWidgets('tapping the already-selected option reports nothing', (
      tester,
    ) async {
      final picked = <String>[];
      await tester.pumpWidget(host(selected: 'dark', onChanged: picked.add));

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      // Re-announcing an unchanged value would make a screen reader chatter and
      // would also re-run whatever the caller does on change.
      expect(picked, isEmpty);
    });
  });

  group('Semantics', () {
    testWidgets('the group is announced as a named container', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(selected: 'light', onChanged: (_) {}));

      final group = tester.getSemantics(
        find.bySemanticsLabel('App Theme Mode'),
      );
      expect(group.label, 'App Theme Mode');
      handle.dispose();
    });

    testWidgets('exactly one option is announced as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(selected: 'light', onChanged: (_) {}));

      final selected = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where(
            (node) =>
                node.properties.selected == true &&
                node.properties.inMutuallyExclusiveGroup == true,
          )
          .toList();

      expect(selected, hasLength(1));
      expect(selected.single.properties.label, 'Light');
      handle.dispose();
    });

    testWidgets('options are announced once, not twice', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(selected: 'light', onChanged: (_) {}));

      // Each option combines an explicit Semantics label with an ExcludeSemantics
      // around the visible text. Without the exclusion a screen reader would
      // say "Light, radio button, Light".
      final labels = tester
          .getSemantics(find.text('Light'))
          .label
          .toLowerCase();
      expect(labels, isNot(contains('light light')));
      handle.dispose();
    });

    testWidgets('the selected option changes as the selection does', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var selected = 'system';
      await tester.pumpWidget(
        host(selected: selected, onChanged: (value) => selected = value),
      );

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(selected: selected, onChanged: (_) {}));

      final selectedNodes = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((node) => node.properties.selected == true)
          .toList();
      expect(selectedNodes, hasLength(1));
      expect(selectedNodes.single.properties.label, 'Dark');
      handle.dispose();
    });
  });

  group('Keyboard', () {
    testWidgets('arrow keys move the selection', (tester) async {
      // The control is controlled: it reports a new value and waits for the
      // parent to feed it back. The harness rebuilds with whatever was reported,
      // which is what a real parent does.
      var current = 'system';
      final focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        host(
          selected: current,
          focusNode: focus,
          onChanged: (value) {
            current = value;
            tester.pumpWidget(
              host(
                selected: current,
                onChanged: (next) => current = next,
                focusNode: focus,
              ),
            );
          },
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(current, 'light');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(current, 'dark');
    });

    testWidgets('the selection does not wrap past the ends', (tester) async {
      final picked = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);

      Future<void> pump(String selected) => tester.pumpWidget(
        host(
          selected: selected,
          focusNode: focus,
          onChanged: (value) {
            picked.add(value);
            pump(value);
          },
        ),
      );

      await pump('system');
      focus.requestFocus();
      await tester.pumpAndSettle();

      // A radio group clamps rather than wrapping: wrapping makes it impossible
      // to tell whether you moved forwards or backwards.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(picked, isEmpty);

      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(picked, ['light', 'dark']);
      // The third press is a no-op: it must not re-report 'dark'.
      expect(picked.where((v) => v == 'dark'), hasLength(1));
    });

    testWidgets('End and Home jump to the extremes', (tester) async {
      final picked = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);

      Future<void> pump(String selected) => tester.pumpWidget(
        host(
          selected: selected,
          focusNode: focus,
          onChanged: (value) {
            picked.add(value);
            pump(value);
          },
        ),
      );

      await pump('light');
      focus.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(picked.last, 'dark');

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(picked.last, 'system');
    });

    testWidgets('arrow keys do nothing while the control is unfocused', (
      tester,
    ) async {
      // Guards against the shortcuts firing globally, which would make the
      // arrow keys hijack the rest of the screen.
      final picked = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        host(selected: 'system', onChanged: picked.add, focusNode: focus),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
    });
  });

  group('Layout', () {
    testWidgets('long labels wrap instead of being clipped', (tester) async {
      // A single row with six accent names would truncate every one of them at
      // a large text size. Wrapping is the reason singleRow defaults to false.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: SegmentedChoice<String>(
                semanticLabel: 'Color Accent',
                selected: 'brand',
                onChanged: (_) {},
                options: const [
                  SegmentedOption(value: 'a', label: 'Crimson'),
                  SegmentedOption(value: 'b', label: 'Monochrome'),
                  SegmentedOption(value: 'c', label: 'Blue'),
                  SegmentedOption(value: 'd', label: 'Teal'),
                  SegmentedOption(value: 'e', label: 'Violet'),
                  SegmentedOption(value: 'f', label: 'Amber'),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      for (final label in ['Crimson', 'Monochrome', 'Amber']) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '$label should be laid out, not dropped',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });
}
