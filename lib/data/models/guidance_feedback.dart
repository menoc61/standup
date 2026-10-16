/// What the employee said about the guidance they were shown.
///
/// ## Why this lives with the data models
///
/// It is *stored*, so it is a persisted value type rather than a service
/// detail: the whole point of the signal is to change what the app suggests
/// next, and a value that died with the process could only ever have steered
/// the next few minutes of a single run. `services/guidance_provider.dart`
/// re-exports it, so the provider and the store share one definition instead of
/// two that can drift.
enum GuidanceFeedback {
  none,
  suggestionsHelpful,
  suggestionsTooFrequent;

  /// Reads a stored name, falling back to [none].
  ///
  /// The column is text rather than an indexed enum so a later version can add
  /// a category without a table rewrite. That freedom is only safe if an
  /// unrecognised value reads as "no feedback" instead of throwing: a
  /// downgraded build must still be able to open its own database.
  static GuidanceFeedback parse(String? stored) {
    for (final value in GuidanceFeedback.values) {
      if (value.name == stored) return value;
    }
    return GuidanceFeedback.none;
  }
}
