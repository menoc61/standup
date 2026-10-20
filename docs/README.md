# StandUp documentation

The documents in this folder are split by **who needs them and when**, not by
topic. Start with the row that matches what you are trying to do; each document
links to the next one you need.

## I want to…

| Goal | Read | Then |
| --- | --- | --- |
| Try the app on my own machine | [INSTALL_AND_LAUNCH.md](INSTALL_AND_LAUNCH.md) | — |
| Sign in, join CNPS, and use the admin console | [ADMIN_GUIDE.md](ADMIN_GUIDE.md) | [SUPABASE_SETUP.md](SUPABASE_SETUP.md) |
| Stand up the Supabase project from scratch | [SUPABASE_SETUP.md](SUPABASE_SETUP.md) | [ADMIN_GUIDE.md](ADMIN_GUIDE.md) |
| Understand how the code is layered | [ARCHITECTURE.md](ARCHITECTURE.md) | — |
| Deploy to Windows, macOS, Linux, Android, iOS or PWA | [PLATFORM_SETUP.md](PLATFORM_SETUP.md) | [INSTALL_AND_LAUNCH.md](INSTALL_AND_LAUNCH.md) |
| Change the company AI guidance endpoint | [AI_INTEGRATION.md](AI_INTEGRATION.md) | — |
| Compare StandUp with Workrave | [WORKRAVE_ANALYSIS.md](WORKRAVE_ANALYSIS.md) | — |
| See what is deliberately unfinished | [DEFECT_BACKLOG.md](DEFECT_BACKLOG.md) | — |

## The three operational documents

**Getting started** — [INSTALL_AND_LAUNCH.md](INSTALL_AND_LAUNCH.md) is the
shortest path from a clone to a running window. It lists the toolchain versions
the repository is verified against and the commands for each platform.

**Cloud setup** — [SUPABASE_SETUP.md](SUPABASE_SETUP.md) is the runbook for
everything server-side: environment variables, applying
`supabase_schema.sql` and `supabase_validation.sql` (in that order), the
expected advisor findings, and how to re-apply safely. The two SQL files at the
repository root are canonical; the copies under `supabase/` are what the CLI
deploys and must stay byte-identical.

**Day-to-day administration** — [ADMIN_GUIDE.md](ADMIN_GUIDE.md) explains how an
administrator reaches the console, what each figure means, why some rows are
missing, and how the email-domain rule and invite code are managed.

## The reference documents

[ARCHITECTURE.md](ARCHITECTURE.md) documents the dependency direction (UI →
`AppState` → services and repositories), the reminder state machine, the
cadence and action-window rules, and the testing strategy. Change that document
when a boundary moves.

[PLATFORM_SETUP.md](PLATFORM_SETUP.md) carries the per-platform caveats that
cannot be inferred from the code: notification limits, the iOS widget target,
window chrome, autostart. A platform that has not been built and tested is
listed as unverified rather than implied to work.

[AI_INTEGRATION.md](AI_INTEGRATION.md) states the privacy boundary for the
optional company guidance and the cheapest configuration that satisfies it. The
local deterministic guidance is the baseline and never depends on this
document's endpoint being configured.

[WORKRAVE_ANALYSIS.md](WORKRAVE_ANALYSIS.md) and
[DEFECT_BACKLOG.md](DEFECT_BACKLOG.md) are decision records: what was borrowed
from Workrave, what was deliberately rejected, and which gaps are known and
still open. [CODEX_AUDIT.md](CODEX_AUDIT.md) is the audit that produced several
of the fixes now in the schema and the reminder loop.

## Conventions

- Every user-visible string goes through `lib/core/app_strings.dart` with both
  English and French copy; `test/bilingual_parity_test.dart` fails otherwise.
- Never put a service-role key in Dart, assets, build arguments or logs. Only the
  project URL and the publishable key belong in the client.
- Report a platform as working only after a build on that platform. An unrun
  build is not a passing build.
