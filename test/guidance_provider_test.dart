import 'package:flutter_test/flutter_test.dart';
import 'package:standup_app/services/guidance_provider.dart';

void main() {
  const provider = LocalGuidanceProvider();

  test('model input is a coarse, identity-free allowlist', () {
    const input = GuidanceInput(
      completedToday: 3,
      snoozedToday: 1,
      skippedToday: 0,
      dailyGoal: 8,
      cadenceMinutes: 60,
      feedback: GuidanceFeedback.suggestionsHelpful,
    );

    expect(input.toModelInput(), {
      'completed_today': 3,
      'snoozed_today': 1,
      'skipped_today': 0,
      'daily_goal': 8,
      'cadence_minutes': 60,
      'feedback': 'suggestionsHelpful',
    });
  });

  group('company AI response contract', () {
    test('accepts only known typed guidance results', () {
      expect(
        GuidanceResult.fromModelPayload({
          'kind': 'celebrate',
          'reason': 'goalProgress',
        }),
        const GuidanceResult(
          kind: GuidanceKind.celebrate,
          reason: GuidanceReason.goalProgress,
        ),
      );
    });

    test(
      'rejects arbitrary text, unknown values, and invalid kind/reason pairs',
      () {
        expect(GuidanceResult.fromModelPayload('take a walk'), isNull);
        expect(
          GuidanceResult.fromModelPayload({
            'kind': 'callTool',
            'reason': 'goalProgress',
          }),
          isNull,
        );
        expect(
          GuidanceResult.fromModelPayload({
            'kind': 'adjustReminderCadence',
            'reason': 'consistentActivity',
          }),
          isNull,
        );
      },
    );
  });

  group('local guidance rules', () {
    test('does not invent a recommendation before there is activity', () {
      expect(
        provider.evaluate(
          const GuidanceInput(
            completedToday: 0,
            snoozedToday: 0,
            skippedToday: 0,
            dailyGoal: 8,
            cadenceMinutes: 60,
          ),
        ),
        isNull,
      );
    });

    test('celebrates reaching the employee goal', () {
      expect(
        provider.evaluate(
          const GuidanceInput(
            completedToday: 8,
            snoozedToday: 1,
            skippedToday: 1,
            dailyGoal: 8,
            cadenceMinutes: 60,
          ),
        ),
        const GuidanceResult(
          kind: GuidanceKind.celebrate,
          reason: GuidanceReason.goalProgress,
        ),
      );
    });

    test('suggests a less frequent cadence after repeated interruptions', () {
      expect(
        provider.evaluate(
          const GuidanceInput(
            completedToday: 1,
            snoozedToday: 1,
            skippedToday: 1,
            dailyGoal: 8,
            cadenceMinutes: 60,
          ),
        ),
        const GuidanceResult(
          kind: GuidanceKind.adjustReminderCadence,
          reason: GuidanceReason.repeatedSnoozes,
        ),
      );
    });

    test(
      'uses a movement suggestion when cadence is already at its maximum',
      () {
        expect(
          provider.evaluate(
            const GuidanceInput(
              completedToday: 0,
              snoozedToday: 2,
              skippedToday: 0,
              dailyGoal: 8,
              cadenceMinutes: 90,
            ),
          ),
          const GuidanceResult(
            kind: GuidanceKind.takeShortMovementBreak,
            reason: GuidanceReason.repeatedSnoozes,
          ),
        );
      },
    );

    test('honors explicit feedback that suggestions are too frequent', () {
      expect(
        provider.evaluate(
          const GuidanceInput(
            completedToday: 1,
            snoozedToday: 0,
            skippedToday: 0,
            dailyGoal: 8,
            cadenceMinutes: 60,
            feedback: GuidanceFeedback.suggestionsTooFrequent,
          ),
        ),
        isNull,
      );
    });

    test('helpful feedback opts the employee into a gentle nudge', () {
      expect(
        provider.evaluate(
          const GuidanceInput(
            completedToday: 0,
            snoozedToday: 0,
            skippedToday: 0,
            dailyGoal: 8,
            cadenceMinutes: 60,
            feedback: GuidanceFeedback.suggestionsHelpful,
          ),
        ),
        const GuidanceResult(
          kind: GuidanceKind.takeShortMovementBreak,
          reason: GuidanceReason.goalProgress,
        ),
      );
    });
  });
}
