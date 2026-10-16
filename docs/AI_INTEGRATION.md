# Company-hosted guidance AI

StandUp keeps its deterministic Dart guidance available locally and can make a
manual, opt-in request to a company-hosted OpenAI-compatible chat-completions
endpoint through the authenticated Supabase Edge Function `ai-guidance`. The
Flutter client never contains the model endpoint credential.

## What is sent

Only when **Settings → Cloud Sync & Privacy → Company AI guidance** is enabled
and the employee taps **Ask company AI**, the client sends:

- today's completed, snoozed, and skipped counts;
- the selected daily goal and reminder cadence;
- one structured feedback choice; and
- the fixed consent-contract version `guidance-v1`.

The model request excludes employee name, email, user or organization ID,
individual event timestamps, device details, and free-form notes. The Edge
Function authenticates the Supabase user but does not forward identity or the
session token to the model endpoint. Function/model operators should avoid
logging request and response bodies and should set an appropriate retention
policy. The user's AI consent is separate from the organization-statistics
consent, is stored locally, defaults off, and can be withdrawn in Settings.

## Runtime behavior

- The app never calls the model at startup or while scheduling reminders.
- Every model request is a deliberate button tap and has a 20-second client
  timeout; the Edge Function caps the upstream request at 15 seconds.
- The function validates the exact request keys, count ranges, feedback enum,
  cadence values, consent version, and authenticated caller.
- The prompt requests only the fixed `GuidanceKind`/`GuidanceReason` JSON result.
  The server and client reject unknown values, invalid pairs, extra response
  keys, and free-form generated copy. App-owned French/English text is rendered.
- **What a model can actually add here is judgement, not vocabulary.** Every
  answer has to render as the app's own bilingual copy, so the accepted
  `kind`/`reason` pairs are exactly the ones the local rule can also phrase —
  `test/guidance_provider_test.dart` asserts that and fails if a reason is ever
  accepted from a model that the local rule cannot produce. The local rule is a
  priority-ordered if-chain that answers with the first branch that matches, so
  it celebrates a day whose goal is met even when five snoozes sit behind it; a
  model weighs the same facts together and may disagree. That disagreement, and
  nothing wider, is the improvement being bought.
- The employee's **feedback choice is persisted** locally
  (`UserPreferences.guidanceFeedback`), so "these come too often" keeps steering
  later sessions and survives a restart. It never leaves the device except as
  the single structured field in an explicitly requested call.
- If auth, connectivity, server configuration, or model output fails, the local
  deterministic rule result remains visible. No retry loop is used for a
  user-triggered suggestion.
- **The Edge Function has no per-user request quota.** It is reachable by any
  authenticated project user, and nothing in the function counts or rate-limits
  calls, so an authenticated caller can spend the company endpoint's budget. The
  upstream gateway's own quota is the only control today; a server-side cap
  needs a table (none exists — there is no `audit_ai_requests` anywhere in the
  SQL) plus a live project to verify it against, which this repository does not
  have. Recorded as an open item in `docs/DEFECT_BACKLOG.md` rather than guessed
  at.
- Requests require a signed-in Supabase account and configured project
  credentials. Local guidance continues to work without an account or network.

## Company endpoint configuration

The proxy expects an HTTPS, OpenAI-compatible `/v1/chat/completions` endpoint
reachable from the Supabase Edge Function runtime. Configure these secrets in
the Supabase project (or in `supabase/functions/.env` for local development):

| Secret | Purpose |
| --- | --- |
| `AI_GUIDANCE_COMPLETIONS_URL` | Full HTTPS URL to the company's chat-completions route |
| `AI_GUIDANCE_API_KEY` | Server-side credential for the company model gateway |
| `AI_GUIDANCE_MODEL` | Model deployment name accepted by that endpoint |

See [`supabase/functions/.env.example`](../supabase/functions/.env.example) for
the shape. Never commit actual values or put them in Dart defines, assets, or
mobile/web builds. The endpoint must accept the OpenAI-compatible request shape
used by `supabase/functions/ai-guidance/index.ts`, return
`choices[0].message.content` containing exactly `{"kind":"…","reason":"…"}`,
and enforce its own request quotas. Use a server endpoint accessible over TLS;
an on-premises host must be reachable from the deployed Edge Function network.

## Local verification and deployment

1. Install the current Supabase CLI and Deno supported by the project.
2. Copy `supabase/functions/.env.example` to `supabase/functions/.env`, set a
   development endpoint/model key, and keep that file out of Git.
3. Run `deno test supabase/functions/ai-guidance/contract_test.ts` and
   `supabase functions serve ai-guidance` against a local Supabase stack.
4. Test valid, malformed, unauthenticated, timeout, unavailable-model, and
   invalid-model-output cases. Confirm the company endpoint logs no prompt body.
5. Set production function secrets through the Supabase Dashboard or CLI, then
   deploy `ai-guidance`. Keep `verify_jwt = true`.

This repository contains the client and proxy scaffold, but has no configured
company model endpoint or Supabase project credentials. The proxy is therefore
fail-closed until the three server-side values are configured and the function
is deployed. Its offline fallback remains active meanwhile.
