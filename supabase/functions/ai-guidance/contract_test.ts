import {
  parseCompletionResponse,
  parseGuidanceInput,
  parseGuidanceResult,
} from "./contract.ts";

Deno.test("accepts only the coarse guidance input allowlist", () => {
  const accepted = parseGuidanceInput({
    completed_today: 3,
    snoozed_today: 1,
    skipped_today: 0,
    daily_goal: 8,
    cadence_minutes: 60,
    feedback: "suggestionsHelpful",
  });
  if (accepted === null) throw new Error("valid guidance input was rejected");

  const withIdentity = parseGuidanceInput({
    completed_today: 3,
    snoozed_today: 1,
    skipped_today: 0,
    daily_goal: 8,
    cadence_minutes: 60,
    feedback: "suggestionsHelpful",
    email: "employee@example.com",
  });
  if (withIdentity !== null) throw new Error("identity field was accepted");
});

Deno.test("rejects out-of-range data and unrecognized model output", () => {
  if (parseGuidanceInput({
    completed_today: -1,
    snoozed_today: 0,
    skipped_today: 0,
    daily_goal: 8,
    cadence_minutes: 60,
    feedback: "none",
  }) !== null) throw new Error("negative count was accepted");

  if (parseGuidanceResult({ kind: "executeAction", reason: "goalProgress" }) !== null) {
    throw new Error("unknown model action was accepted");
  }
  if (parseGuidanceResult({ kind: "celebrate", reason: "repeatedSnoozes" }) !== null) {
    throw new Error("invalid kind/reason pair was accepted");
  }

  // The pair that answers "these suggestions come too often" has to survive the
  // contract, or the one user complaint the app can act on is unanswerable.
  const tooFrequent = parseGuidanceResult({
    kind: "adjustReminderCadence",
    reason: "feedbackTooFrequent",
  });
  if (tooFrequent?.reason !== "feedbackTooFrequent") {
    throw new Error("the too-frequent answer was rejected");
  }
  const fresh = parseGuidanceResult({
    kind: "takeShortMovementBreak",
    reason: "noActivityYet",
  });
  if (fresh?.reason !== "noActivityYet") {
    throw new Error("the fresh-day answer was rejected");
  }
});

Deno.test("parses only bounded JSON from a chat completion", () => {
  const result = parseCompletionResponse({
    choices: [{ message: { content: '{"kind":"celebrate","reason":"goalProgress"}' } }],
  });
  if (result?.kind !== "celebrate" || result.reason !== "goalProgress") {
    throw new Error("valid completion was not parsed");
  }
  if (parseCompletionResponse({ choices: [{ message: { content: "take a walk" } }] }) !== null) {
    throw new Error("free-form output was accepted");
  }
});
