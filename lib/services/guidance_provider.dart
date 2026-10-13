/// Privacy-bounded seam for future personalized guidance providers.
///
/// The request intentionally contains only coarse daily counters, a goal, a
/// cadence, and explicit feedback. It has no identity, organization, event
/// timestamps, or free-form personal notes. A future model adapter must be
/// opt-in and must preserve this data boundary.
abstract interface class GuidanceProvider {
  Future<GuidanceResult?> suggest(GuidanceInput input);
}

/// Deterministic, offline personalization. It uses today's aggregate counts,
/// the employee's goal and cadence, and only explicit in-session feedback.
///
/// This remains the default provider even after an AI adapter is added: model
/// access must be a separate, consented choice and should never be required for
/// reminders or core wellness guidance.
class LocalGuidanceProvider implements GuidanceProvider {
  const LocalGuidanceProvider();

  GuidanceResult? evaluate(GuidanceInput input) {
    if (input.feedback == GuidanceFeedback.suggestionsTooFrequent ||
        input.completedToday < 0 ||
        input.snoozedToday < 0 ||
        input.skippedToday < 0 ||
        input.dailyGoal <= 0 ||
        input.cadenceMinutes <= 0) {
      return null;
    }

    if (input.completedToday >= input.dailyGoal) {
      return const GuidanceResult(
        kind: GuidanceKind.celebrate,
        reason: GuidanceReason.goalProgress,
      );
    }

    if (input.snoozedToday + input.skippedToday >= 2) {
      return GuidanceResult(
        kind: input.cadenceMinutes >= 90
            ? GuidanceKind.takeShortMovementBreak
            : GuidanceKind.adjustReminderCadence,
        reason: GuidanceReason.repeatedSnoozes,
      );
    }

    if (input.completedToday >= 2) {
      return const GuidanceResult(
        kind: GuidanceKind.celebrate,
        reason: GuidanceReason.consistentActivity,
      );
    }

    if (input.completedToday > 0 ||
        input.snoozedToday + input.skippedToday > 0 ||
        input.feedback == GuidanceFeedback.suggestionsHelpful) {
      return const GuidanceResult(
        kind: GuidanceKind.takeShortMovementBreak,
        reason: GuidanceReason.goalProgress,
      );
    }

    return null;
  }

  @override
  Future<GuidanceResult?> suggest(GuidanceInput input) async => evaluate(input);
}

/// Small local summary that can be supplied to a deterministic rule engine or
/// an explicitly enabled AI adapter without exposing an employee identity.
class GuidanceInput {
  const GuidanceInput({
    required this.completedToday,
    required this.snoozedToday,
    required this.skippedToday,
    required this.dailyGoal,
    required this.cadenceMinutes,
    this.feedback = GuidanceFeedback.none,
  });

  final int completedToday;
  final int snoozedToday;
  final int skippedToday;
  final int dailyGoal;
  final int cadenceMinutes;
  final GuidanceFeedback feedback;

  /// The only payload a future adapter may serialize by default.
  Map<String, Object> toModelInput() => {
    'completed_today': completedToday,
    'snoozed_today': snoozedToday,
    'skipped_today': skippedToday,
    'daily_goal': dailyGoal,
    'cadence_minutes': cadenceMinutes,
    'feedback': feedback.name,
  };

  @override
  bool operator ==(Object other) =>
      other is GuidanceInput &&
      other.completedToday == completedToday &&
      other.snoozedToday == snoozedToday &&
      other.skippedToday == skippedToday &&
      other.dailyGoal == dailyGoal &&
      other.cadenceMinutes == cadenceMinutes &&
      other.feedback == feedback;

  @override
  int get hashCode => Object.hash(
    completedToday,
    snoozedToday,
    skippedToday,
    dailyGoal,
    cadenceMinutes,
    feedback,
  );
}

/// Explicit feedback categories keep preference signals structured and local.
enum GuidanceFeedback { none, suggestionsHelpful, suggestionsTooFrequent }

/// Typed result instead of arbitrary model-generated UI copy.
///
/// Widgets resolve [kind] and [reason] through the app's bilingual strings.
/// Unknown values from a remote adapter must be rejected before constructing
/// this result.
class GuidanceResult {
  const GuidanceResult({required this.kind, required this.reason});

  final GuidanceKind kind;
  final GuidanceReason reason;

  /// Decodes the allowlisted server result; unknown model output is rejected.
  static GuidanceResult? fromModelPayload(Object? payload) {
    if (payload is! Map) return null;
    if (payload.length != 2 ||
        !payload.containsKey('kind') ||
        !payload.containsKey('reason')) {
      return null;
    }
    final kindName = payload['kind'];
    final reasonName = payload['reason'];
    if (kindName is! String || reasonName is! String) return null;
    GuidanceKind? kind;
    for (final candidate in GuidanceKind.values) {
      if (candidate.name == kindName) kind = candidate;
    }
    GuidanceReason? reason;
    for (final candidate in GuidanceReason.values) {
      if (candidate.name == reasonName) reason = candidate;
    }
    if (kind == null || reason == null) return null;
    final validPair = switch (kind) {
      GuidanceKind.takeShortMovementBreak =>
        reason == GuidanceReason.goalProgress ||
            reason == GuidanceReason.repeatedSnoozes,
      GuidanceKind.adjustReminderCadence =>
        reason == GuidanceReason.repeatedSnoozes,
      GuidanceKind.celebrate =>
        reason == GuidanceReason.goalProgress ||
            reason == GuidanceReason.consistentActivity,
    };
    if (!validPair) return null;
    return GuidanceResult(kind: kind, reason: reason);
  }

  @override
  bool operator ==(Object other) =>
      other is GuidanceResult && other.kind == kind && other.reason == reason;

  @override
  int get hashCode => Object.hash(kind, reason);
}

enum GuidanceKind { takeShortMovementBreak, adjustReminderCadence, celebrate }

enum GuidanceReason { goalProgress, repeatedSnoozes, consistentActivity }
