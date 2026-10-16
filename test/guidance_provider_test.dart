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
    test('offers a first suggestion on a day with nothing recorded yet', () {
      // This used to answer with nothing at all, which is why the app was
      // silent on the mornings it could have been most useful. The reason is a
      // fact the employee can check against their own day.
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
        const GuidanceResult(
          kind: GuidanceKind.takeShortMovementBreak,
          reason: GuidanceReason.noActivityYet,
        ),
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

    test('answers explicit feedback that suggestions are too frequent', () {
      // The complaint used to produce silence, because the output space had no
      // way to phrase it. Silence is the one answer that cannot help a user who
      // has just said the app talks too much.
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
        const GuidanceResult(
          kind: GuidanceKind.adjustReminderCadence,
          reason: GuidanceReason.feedbackTooFrequent,
        ),
      );
    });

    test('helpful feedback opts the employee into a gentle nudge', () {
      expect(
        provider.evaluate(
          const GuidanceInput(
            completedToday: 1,
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

    test('every answer a model may give is one the local rule can phrase', () {
      // The honesty claim in `LocalGuidanceProvider`'s doc: the model's ceiling
      // is *choice*, not vocabulary, because every answer has to render as the
      // app's own bilingual copy. If a reason is ever accepted from the model
      // that the local rule cannot produce, this fails — and the honest fix is
      // to teach the local rule the case, not to widen what the model may say.
      final produced = <GuidanceResult>{};
      for (final input in const [
        GuidanceInput(
          completedToday: 0,
          snoozedToday: 0,
          skippedToday: 0,
          dailyGoal: 8,
          cadenceMinutes: 60,
        ),
        GuidanceInput(
          completedToday: 1,
          snoozedToday: 0,
          skippedToday: 0,
          dailyGoal: 8,
          cadenceMinutes: 60,
        ),
        GuidanceInput(
          completedToday: 2,
          snoozedToday: 0,
          skippedToday: 0,
          dailyGoal: 8,
          cadenceMinutes: 60,
        ),
        GuidanceInput(
          completedToday: 8,
          snoozedToday: 0,
          skippedToday: 0,
          dailyGoal: 8,
          cadenceMinutes: 60,
        ),
        GuidanceInput(
          completedToday: 1,
          snoozedToday: 1,
          skippedToday: 1,
          dailyGoal: 8,
          cadenceMinutes: 60,
        ),
        GuidanceInput(
          completedToday: 1,
          snoozedToday: 2,
          skippedToday: 0,
          dailyGoal: 8,
          cadenceMinutes: 90,
        ),
        GuidanceInput(
          completedToday: 1,
          snoozedToday: 0,
          skippedToday: 0,
          dailyGoal: 8,
          cadenceMinutes: 60,
          feedback: GuidanceFeedback.suggestionsTooFrequent,
        ),
        GuidanceInput(
          completedToday: 1,
          snoozedToday: 0,
          skippedToday: 0,
          dailyGoal: 8,
          cadenceMinutes: 60,
          feedback: GuidanceFeedback.suggestionsHelpful,
        ),
      ]) {
        final result = provider.evaluate(input);
        if (result != null) produced.add(result);
      }

      final acceptable = <GuidanceResult>{
        for (final kind in GuidanceKind.values)
          for (final reason in GuidanceReason.values)
            ?GuidanceResult.fromModelPayload({
              'kind': kind.name,
              'reason': reason.name,
            }),
      };

      expect(acceptable, isNotEmpty);
      expect(
        acceptable.difference(produced),
        isEmpty,
        reason: 'the model may answer with a pair the local rule cannot',
      );
    });
  });
}
