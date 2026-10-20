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

## Cheapest workable setup

The function is deliberately provider-agnostic: it speaks the OpenAI
chat-completions shape, so switching providers is **three secrets and no code
change**. That is the cheap path — there is no provider SDK, no client key, and
no new dependency to keep current.

Any of these satisfies the contract. Prices move; check the provider's current
page before budgeting, and treat the free tiers as rate-limited rather than
unlimited.

| Provider | Endpoint | Model | Order of magnitude |
| --- | --- | --- | --- |
| Groq | `https://api.groq.com/openai/v1/chat/completions` | `llama-3.1-8b-instant` | Free tier with rate limits; paid tokens are fractions of a cent per thousand |
| Google Gemini (OpenAI-compatible) | `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` | `gemini-2.0-flash` | Free tier; paid input around $0.10 per million tokens |
| OpenRouter | `https://openrouter.ai/api/v1/chat/completions` | any `:free` model | $0 within the free-model rate limits |
| OpenAI | `https://api.openai.com/v1/chat/completions` | `gpt-4o-mini` | Roughly $0.15 input / $0.60 output per million tokens |

### What a pilot actually costs

The request is tiny by design: today's three counts, a goal, a cadence, one
feedback enum, a fixed consent string, and a prompt that asks for two short
enum values. Budget roughly 500–1,000 tokens per request.

- 50 employees × one manual request per working day × 800 tokens ≈
  40,000 tokens/day ≈ **1.2 million tokens/month**;
- at `gpt-4o-mini` prices that is well under **$1/month**;
- on the Groq or Gemini free tiers it is **$0**, provided the rate limits are
  respected (they are per minute, not per month).

The feature is deliberately behind a manual button, default-off, with no
startup, scheduled or retry calls, so this is the realistic upper bound rather
than an average.

### Configure it

```bash
supabase secrets set \
  AI_GUIDANCE_COMPLETIONS_URL="https://api.groq.com/openai/v1/chat/completions" \
  AI_GUIDANCE_API_KEY="<provider key>" \
  AI_GUIDANCE_MODEL="llama-3.1-8b-instant"

supabase functions deploy ai-guidance
```

Then confirm in the app: **Settings → Cloud Sync & Privacy → Company AI
guidance** stays off until the employee turns it on, and **Ask company AI**
appears only when signed in. Remove the secrets to return to the local
deterministic guidance; the function fails closed and the client falls back.

### Two cheap improvements, in order

1. **A per-user daily cap.** The function has no quota today (recorded in
   `docs/DEFECT_BACKLOG.md`). A small table keyed by `auth.uid()` and the local
   date, incremented inside the function, turns "the gateway's rate limit" into
   a company-owned budget. It is the difference between a free tier that lasts
   and one that is exhausted by a single curious account.
2. **Cache the answer for the day.** The inputs change only when the employee
   completes, snoozes or skips a reminder, so a request repeated with identical
   inputs should return the stored result. That cuts usage without changing
   behaviour or the privacy boundary.

Neither is required for the pilot; both are cheap and neither adds a provider
dependency.

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

The client and proxy scaffold are complete, and the Supabase project
(`tcgtvokcndfiizdoidhv`) is configured for auth and organisation analytics. The
`ai-guidance` function is **not deployed** and no model endpoint or key is set,
so the proxy is fail-closed and the local deterministic guidance is the only
active path. Configure the three server-side values above and deploy the
function to enable the optional company guidance; no client change is needed.
