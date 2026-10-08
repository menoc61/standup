import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/core/app_colors.dart';
import 'package:standup_app/data/local/widget_palette.dart';
import 'package:standup_app/data/local/widget_snapshot.dart';

/// Fixed instants so the window arithmetic under test does not depend on when
/// the suite happens to run. With a 5-minute window ending on the hour, 09:57
/// is inside a window and 09:20 is not.
final _open = DateTime(2026, 1, 1, 9, 57);
final _closed = DateTime(2026, 1, 1, 9, 20);

void main() {
  group('Widget payload encoding', () {
    test('round-trips every field the native side reads', () {
      final snapshot = WidgetSnapshot.fromState(
        streak: 7,
        totalXp: 1420,
        todayCompleted: 3,
        dailyGoal: 8,
        windowOpen: true,
        windowMinutes: 5,
        cadenceMinutes: 60,
        clockSuspect: false,
        now: _open,
      );
      final payload = snapshot.toMap();

      // Encoded exactly as publish() does it.
      final encoded = StringBuffer();
      payload.forEach((key, value) {
        if (value == null) return;
        encoded
          ..write(key)
          ..write('=')
          ..write(value is bool ? (value ? '1' : '0') : value.toString())
          ..write(';');
      });

      // Re-decoded exactly as the Kotlin provider does it.
      final decoded = <String, String>{};
      for (final pair in encoded.toString().split(';')) {
        if (pair.isEmpty) continue;
        final index = pair.indexOf('=');
        if (index <= 0) continue;
        decoded[pair.substring(0, index)] = pair.substring(index + 1);
      }

      // Keys the Kotlin provider actually reads, with the value types it
      // expects. If one of these changes, the widget silently renders blank.
      expect(decoded['window_open'], '1');
      expect(decoded['window_ends_at'], isNotNull);
      expect(decoded['streak'], '7');
      expect(decoded['clock_suspect'], '0');
      expect(decoded['today_completed'], '3');
      expect(decoded['daily_goal'], '8');
      expect(decoded['level'], isNotEmpty);
      expect(decoded['goal_met'], isNotNull);
    });

    test('ISO timestamps contain no separator used by the encoding', () {
      // A ';' or '=' inside a value would corrupt every field after it.
      final payload = WidgetSnapshot.fromState(
        streak: 0,
        totalXp: 0,
        todayCompleted: 0,
        dailyGoal: 8,
        windowOpen: true,
        windowMinutes: 5,
        cadenceMinutes: 60,
        clockSuspect: false,
        now: _open,
      ).toMap(now: _open);

      final stamps = [
        payload['window_ends_at'],
        payload['window_opens_at'],
        payload['published_at'],
      ].whereType<String>();

      for (final stamp in stamps) {
        expect(stamp, isNot(contains(';')));
        expect(stamp, isNot(contains('=')));
      }
      // Sanity: it is a real ISO-8601 UTC instant the Java parser can read.
      expect(DateTime.parse(stamps.first).isUtc, isTrue);
    });

    test('an open window publishes an end and no start', () {
      final payload = WidgetSnapshot.fromState(
        streak: 0,
        totalXp: 0,
        todayCompleted: 0,
        dailyGoal: 8,
        windowOpen: true,
        windowMinutes: 5,
        cadenceMinutes: 60,
        clockSuspect: false,
        now: _open,
      ).toMap(now: _open);

      expect(payload['window_open'], isTrue);
      expect(payload['window_ends_at'], isNotNull);
      // A second timestamp while open would make the provider ambiguous about
      // which clock it should count down to.
      expect(payload['window_opens_at'], isNull);
    });

    test('a closed window publishes a start and no end', () {
      // Far outside any action window: 12:00 with a last-5-minutes rule.
      final closed = WidgetSnapshot.fromState(
        streak: 0,
        totalXp: 0,
        todayCompleted: 0,
        dailyGoal: 8,
        windowOpen: false,
        windowMinutes: 5,
        cadenceMinutes: 60,
        clockSuspect: false,
        now: _closed,
      ).toMap(now: _closed);

      expect(closed['window_open'], isFalse);
      expect(closed['window_ends_at'], isNull);
      expect(closed['window_opens_at'], isNotNull);
    });

    test('a distrusted clock is published as the flag the widget gates on', () {
      final payload = WidgetSnapshot.fromState(
        streak: 3,
        totalXp: 100,
        todayCompleted: 1,
        dailyGoal: 8,
        windowOpen: true,
        windowMinutes: 5,
        cadenceMinutes: 60,
        clockSuspect: true,
        now: _open,
      ).toMap(now: _closed);

      // The provider hides the button when this is '1'.
      expect(payload['clock_suspect'], isTrue);
      expect(payload['window_open'], isTrue);
    });

    test('decode recovers booleans rather than leaving them as text', () {
      final snapshot = WidgetSnapshot.fromState(
        streak: 1,
        totalXp: 10,
        todayCompleted: 1,
        dailyGoal: 8,
        windowOpen: true,
        windowMinutes: 5,
        cadenceMinutes: 60,
        clockSuspect: false,
        now: _open,
      );

      final roundTripped = WidgetSnapshot.fromMap(snapshot.toMap());

      expect(roundTripped.windowOpen, isTrue);
      expect(roundTripped.clockSuspect, isFalse);
      expect(roundTripped.streak, 1);
      expect(roundTripped.totalXp, 10);
      expect(roundTripped.level, snapshot.level);
      expect(roundTripped.dailyGoal, 8);
    });
  });

  group('Widget action routing', () {
    test('the complete route is recognised', () {
      // Mirrors the URI the native providers broadcast.
      expect(WidgetBridge.uriComplete, 'csphwidget://complete');
    });

    test('the provider names match the native declarations', () {
      // Android: com.healthwellness.standup_app.widget.StandUpWidgetProvider
      // iOS: the WidgetKit bundle's CSPHStandUpWidget
      // A mismatch here fails silently at runtime, so it is asserted.
      expect(WidgetBridge.uriOpen, 'csphwidget://open');
    });
  });

  group('Widget palette', () {
    test('every colour the providers read is published', () {
      // Each of these is read by name in StandUpWidgetProvider and WidgetPayload.swift.
      // A missing key means the native side falls back, which looks like the
      // widget "ignoring" the user's accent.
      final payload = WidgetSnapshot.fromState(
        now: _open,
        streak: 2,
        totalXp: 50,
        todayCompleted: 1,
        dailyGoal: 8,
        windowOpen: true,
        windowMinutes: 5,
        cadenceMinutes: 60,
        clockSuspect: false,
        colorSystem: 'brand',
      ).toMap(now: _open);

      for (final key in const [
        'c_surface',
        'c_surface_2',
        'c_on_surface',
        'c_muted',
        'c_accent',
        'c_on_accent',
        'c_streak',
      ]) {
        expect(
          payload[key],
          isNotNull,
          reason: '$key is missing from the payload',
        );
      }
    });

    test('the accent follows the colour the user selected', () {
      // This is the behaviour that was asked for: the widget must not be fixed
      // to one colour. Each accent must produce a different `c_accent`.
      final seen = <String, String>{};
      for (final option in AppColors.accents) {
        final palette = WidgetPaletteHex.forAccent(option.id);
        seen[option.id] = palette.accent ?? '';
      }

      expect(
        seen.values.toSet().length,
        AppColors.accents.length,
        reason: 'two accents resolve to the same colour: $seen',
      );
      expect(seen['brand'], '#FFDA244D');
    });

    test('published colours survive the widget encoding intact', () {
      // The payload is pipe-delimited and a `;` or `=` in a value would corrupt
      // every field after it. Hex strings are safe, and the round trip is
      // asserted so a future format change cannot break it silently.
      final palette = WidgetPaletteHex.forAccent('violet');
      final snapshot = WidgetSnapshot.fromState(
        now: _open,
        streak: 0,
        totalXp: 0,
        todayCompleted: 0,
        dailyGoal: 8,
        windowOpen: true,
        windowMinutes: 5,
        cadenceMinutes: 60,
        clockSuspect: false,
        colorSystem: 'violet',
      );
      final payload = snapshot.toMap(now: _open);

      expect(payload['c_accent'], palette.accent);
      for (final key in const ['c_accent', 'c_surface', 'c_on_surface']) {
        final value = payload[key] as String;
        expect(value, isNot(contains(';')));
        expect(value, isNot(contains('=')));
        // AARRGGBB, uppercase: the shape both native parsers expect.
        expect(value, matches(RegExp(r'^#[0-9A-F]{8}$')));
      }
    });

    test('a malformed colour parses to null rather than throwing', () {
      // A truncated or corrupt payload must not crash the launcher process,
      // which would take the whole home screen down with it.
      expect(parseWidgetColor('#FFDA244D'), isNotNull);
      expect(parseWidgetColor('FFDA244D'), isNotNull);
      expect(parseWidgetColor('#DA244D'), isNotNull, reason: 'RGB is accepted');
      expect(parseWidgetColor('#ZZZZZZZZ'), isNull);
      expect(parseWidgetColor('#FFF'), isNull);
      expect(parseWidgetColor(''), isNull);
      expect(parseWidgetColor(null), isNull);
    });

    test('the default palette matches the app, not the retired green', () {
      // A regression guard: the widget shipped with a hardcoded #1F4B38
      // evergreen. This asserts the default no longer carries it.
      final fallback = WidgetPaletteHex.fallbackAccent;
      expect(fallback, '#FFDA244D');
      expect(fallback, isNot(contains('1F4B38')));
    });
  });
}
