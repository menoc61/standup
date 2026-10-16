export const consentVersion = "guidance-v1";

export type GuidanceKind =
  | "takeShortMovementBreak"
  | "adjustReminderCadence"
  | "celebrate";

export type GuidanceReason =
  | "goalProgress"
  | "repeatedSnoozes"
  | "consistentActivity"
  | "noActivityYet"
  | "feedbackTooFrequent";

export type GuidanceInput = {
  completed_today: number;
  snoozed_today: number;
  skipped_today: number;
  daily_goal: number;
  cadence_minutes: number;
  feedback: "none" | "suggestionsHelpful" | "suggestionsTooFrequent";
};

export type GuidanceResult = { kind: GuidanceKind; reason: GuidanceReason };

const inputKeys = [
  "completed_today",
  "snoozed_today",
  "skipped_today",
  "daily_goal",
  "cadence_minutes",
  "feedback",
] as const;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(value: Record<string, unknown>, expected: readonly string[]) {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  return actual.length === wanted.length && actual.every((key, index) => key === wanted[index]);
}

function boundedInteger(value: unknown, min: number, max: number): value is number {
  return Number.isInteger(value) && (value as number) >= min && (value as number) <= max;
}

export function parseGuidanceInput(value: unknown): GuidanceInput | null {
  if (!isRecord(value) || !hasExactKeys(value, inputKeys)) return null;
  if (!boundedInteger(value.completed_today, 0, 100)) return null;
  if (!boundedInteger(value.snoozed_today, 0, 100)) return null;
  if (!boundedInteger(value.skipped_today, 0, 100)) return null;
  if (!boundedInteger(value.daily_goal, 1, 100)) return null;
  if (![30, 60, 90].includes(value.cadence_minutes as number)) return null;
  if (!["none", "suggestionsHelpful", "suggestionsTooFrequent"].includes(value.feedback as string)) return null;
  return value as GuidanceInput;
}

export function parseGuidanceResult(value: unknown): GuidanceResult | null {
  if (!isRecord(value) || !hasExactKeys(value, ["kind", "reason"])) return null;
  const kind = value.kind;
  const reason = value.reason;
  if (typeof kind !== "string" || typeof reason !== "string") return null;

  const validPair =
    (kind === "takeShortMovementBreak" &&
      ["goalProgress", "repeatedSnoozes", "noActivityYet"].includes(reason)) ||
    (kind === "adjustReminderCadence" &&
      ["repeatedSnoozes", "feedbackTooFrequent"].includes(reason)) ||
    (kind === "celebrate" &&
      ["goalProgress", "consistentActivity"].includes(reason));
  if (!validPair) return null;
  return { kind: kind as GuidanceKind, reason: reason as GuidanceReason };
}

export function parseCompletionResponse(value: unknown): GuidanceResult | null {
  if (!isRecord(value) || !Array.isArray(value.choices)) return null;
  const first = value.choices[0];
  if (!isRecord(first) || !isRecord(first.message)) return null;
  const content = first.message.content;
  if (typeof content !== "string" || content.length > 512) return null;
  try {
    return parseGuidanceResult(JSON.parse(content));
  } catch {
    return null;
  }
}
