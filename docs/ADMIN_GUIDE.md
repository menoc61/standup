# Administrator guide

This is the day-to-day guide for the CNPS workspace administrator: how to get
into the admin console, what the numbers mean, and how to control who may join.
The server-side runbook is [SUPABASE_SETUP.md](SUPABASE_SETUP.md); this document
assumes the project is already configured.

## 1. Who can open the admin console

The console is available to an account that satisfies **both** conditions:

1. `profiles.role` is `admin` (or `manager`) for a profile linked to an
   organisation; and
2. the account is signed in to the same Supabase project the app was built
   against.

Everyone else — employees, signed-out users, and admins of a different
workspace — sees the settings row without the **Open** button, and the aggregate
views return nothing even if a client asks directly. The restriction is enforced
by row-level security and by `private.is_org_admin(...)` inside each view, not by
hiding the button.

## 2. First sign-in and joining the workspace

1. Sign up in the app with your **professional address** (`@cnps.cm`).
2. Confirm the email if the project still requires confirmation. (The
   administrator can turn confirmation off under **Authentication → Providers →
   Email** in the Supabase dashboard; the app never stores that setting.)
3. Open **Settings → Organization Workspace** and enter the workspace invite
   code.
4. The app calls `join_organization(code)`, which stores the organisation on your
   profile. From then on your daily aggregates roll up into the workspace.

Signing up does not join a workspace by itself — a new account belongs to no
organisation until it presents the code. That is what keeps an unrelated account
from reading company figures.

### The default administrator

The pilot workspace is **CNPS** (`cnps.cm`). Its designated administrator is
**`mony.aye@cnps.cm`**. Because a profile row can only exist after the account
does, promotion is a one-time step run after that person has signed up and
joined with the invite code:

```sql
-- Promote the designated administrator. Safe to re-run.
do $$
declare
  target uuid;
  org uuid;
begin
  select id into target from auth.users where lower(email) = 'mony.aye@cnps.cm';
  select id into org from public.organizations where lower(domain) = 'cnps.cm';

  if target is null then
    raise notice 'No account for mony.aye@cnps.cm yet: sign up first, then re-run.';
    return;
  end if;
  if org is null then
    raise exception 'The cnps.cm workspace is missing; run supabase_schema.sql first.';
  end if;

  insert into public.profiles (id, name, organization_id, role)
  values (target, 'Mony Aye', org, 'admin')
  on conflict (id) do update
    set organization_id = excluded.organization_id,
        role = 'admin',
        updated_at = now();
end $$;
```

Verify with:

```sql
select u.email, p.role, p.organization_id, o.name
from public.profiles p
join auth.users u on u.id = p.id
left join public.organizations o on o.id = p.organization_id
where lower(u.email) = 'mony.aye@cnps.cm';
```

An account promoted to `admin` must sign out and back in (or pull to refresh
the session) before the app re-reads its role.

## 3. Opening the console

**Settings → Organization Insights → Open.**

The row explains what the screen contains and states that no individual is
named. A member who is not an admin sees the same row without **Open**, with a
sentence explaining that an administrator role is required — a disabled button
with no explanation reads as a bug.

The refresh icon on the console pushes the day's local counters first and then
re-reads the aggregates, so a break taken a minute ago is not reported as
missing.

## 4. What the console shows

Both layouts read the same cohort-protected rows; the difference is how much can
be compared at once.

### Desktop (window width ≥ 980 px)

Two columns:

- **Left** — the workspace header, four benchmark cards, the activity mix, and
  the daily trend strip.
- **Right** — the department table, one row per department, with the active
  headcount, reminders sent, completed, skipped and completion rate.

A table is the right control when the job is comparing six numbers across eight
departments.

### Phone and narrow windows (< 980 px)

One column, in the order an administrator usually checks: header, benchmark
cards, activity mix, trend, then one card per department. Each department card
carries its completion bar, active headcount, completed stands, and the
sent / snoozed / skipped line.

### The figures

| Figure | Meaning |
| --- | --- |
| **Contributing Employees** | Distinct people with a recorded action in the period. Not "enrolled": someone who never opened the app is not counted. |
| **Org Completion Rate** | Completed reminders ÷ reminders sent, as the server computes it. |
| **Stands Logged** | Completed stands and the movement minutes they represent. |
| **Skipped Breaks** | Skipped reminders, with the snoozed count beneath. |
| **Activity mix** | Every reminder sent, split into completed, snoozed, skipped and "no action recorded". Snoozing and skipping are different signals: a team that snoozes is still engaged, a team that skips has stopped responding. |
| **Participating days** | One bar per measured day, oldest to newest. The right-hand label compares the newest day with the earlier average. |
| **Department breakdown** | The same measures per department, plus the active headcount and rate. |

### Why a row or a day can be missing

- **Fewer than five distinct people** in the period. The server omits the row
  rather than let a small group be re-identified; this is the cohort floor, not
  a rendering fault.
- **A row that failed the server's consistency checks.** The aggregate is
  withheld unless the daily totals are internally plausible (completed and
  skipped cannot exceed sent, stand time cannot be negative or absurd). A
  withheld row shows as a gap, not as zero.
- **Nobody has opted in.** Organisation statistics are opt-in per person. If
  every contributor turns **Contribute Statistics** off, the organisation sees
  nothing — which is the correct outcome, not a bug.

## 5. Who may join: the email-domain rule

Each workspace has a domain (`organizations.domain`) and a switch
(`organizations.restrict_email_domain`, default `true`). When the switch is on,
`join_organization` compares the domain of the **account's own address** — read
from `auth.users`, never from the request — with the workspace domain. A leaked
invite code is therefore not enough for an outsider.

The CNPS workspace is seeded as:

| Field | Value |
| --- | --- |
| Name | `CNPS` |
| Domain | `cnps.cm` |
| Invite code | `CNPS-7H2K-9QX4` |
| Domain restriction | on |

**Read the current values** (the code is intentionally not readable through the
client API — only this SQL can see it):

```sql
select name, domain, code, restrict_email_domain
from public.organizations
where domain = 'cnps.cm';
```

**Turn the restriction off** (accept any address with a valid code — not
recommended while the code is shared):

```sql
update public.organizations
set restrict_email_domain = false
where domain = 'cnps.cm';
```

**Rotate the invite code** (do this if the code was posted somewhere it should
not be; everyone already in the workspace stays in):

```sql
update public.organizations
set code = 'CNPS-' || upper(substr(md5(random()::text), 1, 4)) || '-' ||
           upper(substr(md5(random()::text), 1, 4))
where domain = 'cnps.cm'
returning code;
```

### What the rule does and does not do

- **It does**: stop an account whose address is not `@cnps.cm` from joining the
  workspace, and therefore from reading any organisation aggregate, even with a
  valid invite code.
- **It does not**: stop someone from creating a Supabase account with another
  address. Such an account can sign in but has no organisation, so it sees an
  empty dashboard and every aggregate query returns nothing.
- **Blocking account creation itself** requires a Supabase **Auth Hook** (a
  `before user created` hook configured in the dashboard) or disabling public
  sign-ups. That is a project-wide setting, not a per-workspace one, and it is
  documented in [SUPABASE_SETUP.md](SUPABASE_SETUP.md). The domain rule above is
  the per-workspace control the administrator owns.

## 6. Privacy guarantees

- Administrators see **aggregates only**, and only above the five-person cohort
  floor. Individual reminder logs, timestamps, names and feedback never reach
  the console, and the client has no query that could retrieve them.
- The aggregate views are `security_barrier` views filtered by
  `private.is_org_admin(...)`; revoking the API role changes nothing because the
  filter is inside the view.
- Turning **Contribute Statistics** off deletes that person's `analytics_daily`
  rows (a DELETE policy exists for exactly this), so opting out removes their
  contribution from future aggregates rather than only hiding it locally.
- Nothing about individual activity, feedback, or AI requests is uploaded as
  part of organisation statistics.

## 7. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| "Organization insights are unavailable" | Role is not `admin`/`manager`, or the profile has no organisation | Run the promotion SQL, then sign out and back in |
| "That workspace invite code is not valid" | Code typo or rotated | Re-read the code with the SQL above |
| "This workspace only accepts @cnps.cm email addresses" | Signed in with another domain | Sign in with the professional address; the rule is server-side and cannot be bypassed from the app |
| "Confirm your email before joining a workspace" | Email confirmation is required and the address is unconfirmed | Click the confirmation link, or have the administrator disable confirmation for the pilot |
| The console opens but every figure is zero | No contributor has opted in yet, or the day is under the cohort floor | Nothing to fix; the screen is reporting the truth |
| A department is missing | Fewer than five contributors in that department for the day | Expected; the table only lists departments above the floor |
