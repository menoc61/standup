# Connecting CSPH StandUp to Supabase

This is the complete path from an empty Supabase project to a working cloud
connection. Everything here is written for the Supabase SQL editor; no CLI or
migration tool is required.

The app is **local-first and fully functional without Supabase**. Without
credentials, reminders, history and all analytics run against the on-device
Drift database and nothing is uploaded. Supabase adds accounts, workspace
membership and anonymised organisation dashboards.

> **Never put a service-role or secret key in this app.** The client only ever
> receives the project's *publishable* key. The service-role key bypasses all
> row-level security and must never leave the Supabase dashboard or a CI secret
> store.

---

## 1. Create the project

1. Sign in at [supabase.com](https://supabase.com) and create a project.
2. Wait for the database to finish provisioning, then copy the **Project URL**
   and the **publishable key** from **Settings → API**.

You will need these two values later:

```
Project URL        https://<project-ref>.supabase.co
Publishable key    sb_publishable_...   (labelled "publishable" or "anon")
```

---

## 2. Apply the schema

Open **SQL Editor → New query** and run the two files in this order.

### 2.1 `supabase_schema.sql`

Creates the tables, the row-level security policies, the organisation-join
function and the aggregate views. Run it first.

### 2.2 `supabase_validation.sql`

Adds the server-side analytics validator. It must run **after** the schema,
because it adds columns to `public.analytics_daily` and recreates the two
aggregate views so that only trusted rows are counted.

Run each file with **Run** and confirm you see `Success. No rows returned`.

---

## 3. What the schema enforces

Understanding this matters, because it is the difference between a wellness app
and an employee-monitoring tool.

| Table | Who can read | Who can write |
| --- | --- | --- |
| `profiles` | only your own row | only your own row, and only `name`, `designation`, `department` |
| `organizations` | authenticated users, `id`/`name`/`domain` only | nobody |
| `reminder_logs` | only your own rows | only your own rows |
| `analytics_daily` | only your own rows | only via `record_daily_analytics()` |
| `org_analytics_daily` (view) | admins of the org | read-only, aggregated |
| `org_department_analytics` (view) | admins of the org | read-only, aggregated |

Key guarantees:

- **No administrator can see an individual's timestamps.** The views aggregate
  with `GROUP BY organization_id, date, department` and are created with
  `security_barrier = true`.
- **A client cannot promote itself to administrator.** `profiles.role` has no
  INSERT or UPDATE grant; the column is not writable through the API.
- **Organisation membership is never client-supplied.** A trigger copies
  `organization_id` from the private profile on every write, ignoring whatever
  the payload says.
- **Invite codes are only accepted through `join_organization(text)`**, a
  `SECURITY DEFINER` function, and are never readable through the table API.

---

## 4. Configure authentication

**Authentication → Providers → Email**

- Enable **Email**.
- For a proof of concept you can leave *Confirm email* on. Note that a new user
  must confirm before signing in.
- For local testing only, you may temporarily disable *Confirm email*.

**Authentication → URL Configuration**

Set the **Site URL** to where the web build will be served, for example
`https://standup.example.com`, or to `http://localhost:8080` during development.

Add to **Redirect URLs**:

```
standup://login-callback
http://localhost:8080/**
https://<your-deploy-host>/**
```

**OAuth providers** (Google, Apple) are optional. If you enable them, add the
provider credentials in the Supabase dashboard and register the same
`standup://login-callback` callback. On Windows and Linux the app does not
register a native URL scheme, so OAuth sign-in is unavailable there; email and
password still work on every platform.

---

## 5. Provision an organisation

The schema deliberately ships **no sample data**. Organisation rows and invite
codes must be created by someone you trust, using the SQL editor or the service
role in a controlled backend. Never from the client.

```sql
-- 1. Create the organisation
INSERT INTO public.organizations (name, domain)
VALUES ('CSPH Cameroon', 'csph.cm')
RETURNING id;

-- 2. Generate an invite code
SELECT encode(gen_random_bytes(9), 'hex') AS invite_code;
```

Store the generated code and distribute it out of band. Anyone with the code can
call `join_organization(code)`; that is the intended behaviour.

Promote an initial administrator by setting the role directly in the database,
because the API cannot:

```sql
UPDATE public.profiles SET role = 'admin' WHERE id = '<user-uuid>';
```

---

## 6. Pass the credentials to the app

The client reads two compile-time values. Anything missing or non-`https` makes
the app fall back to local-only mode without crashing.

### Development

```bash
flutter run -d <device-id> \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

PowerShell:

```powershell
flutter run -d <device-id> `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

### Release builds

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...

flutter build web --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

In CI, store these as repository **Settings → Secrets** and inject them from the
environment rather than committing them.

### Optional build metadata

Two further defines make crash reports and support requests far easier to act
on. They are not required:

```bash
--dart-define=APP_VERSION=1.0.0 --dart-define=APP_BUILD=42
```

---

## 7. Verify the connection

Work through this list after wiring everything up.

### 7.1 The app reports cloud status

1. Launch the app and open **Settings**.
2. The **Account** row should show *Cloud accounts need Supabase project keys*
   if the defines are missing, or offer a **Connect** button if they are present.
3. Tap **Connect**, create an account, confirm the email, then sign in.

### 7.2 Sync succeeds

1. Turn on **Settings → Cloud Sync & Privacy → Contribute Statistics**.
2. Pull down on Home to sync, or tap **Sync Now**.
3. The badge should read *Supabase Synced*.

### 7.3 The server accepted the data

Run this in the SQL editor:

```sql
SELECT date,
       reminders_sent,
       reminders_completed,
       trusted,
       clock_suspect,
       revision
FROM public.analytics_daily
WHERE user_id = auth.uid()
ORDER BY date DESC
LIMIT 7;
```

Expect your own rows only, with `trusted = true`.

### 7.4 Direct writes are blocked

This **must fail** with a permission error. If it succeeds, the validation
script was not applied:

```sql
INSERT INTO public.analytics_daily (id, user_id, date)
VALUES (gen_random_uuid(), auth.uid(), current_date);
```

### 7.5 The RPC is callable

```sql
SELECT has_function_privilege(
  'public.record_daily_analytics(date,integer,integer,integer,integer,integer,boolean)',
  'authenticated', 'EXECUTE');
```

Expect `t`.

### 7.6 An organisation admin sees aggregates only

Sign in as an admin whose profile has `organization_id` set, then:

```sql
-- Shows one aggregated row per day, never per employee.
SELECT date, active_users, total_completed, adherence_rate
FROM public.org_analytics_daily
ORDER BY date DESC
LIMIT 7;
```

There is no column anywhere in that view that identifies an individual, and no
view exposes individual timestamps.

---

## 8. Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| *Cloud accounts need Supabase project keys* | The defines are absent or the URL is not `https://`. Rebuild with both defines. |
| *Sign-in fails with a redirect error* | Add the exact callback URL to **Redirect URLs**. On native builds use `standup://login-callback`. |
| New account says *Confirm your email* | Enable the confirmation email in **Authentication → Providers**, or confirm from the email first. |
| Sync always reads *Sync Pending* | `record_daily_analytics` rejected the rows. Check `trust_note` in `analytics_daily`. |
| *p_date is in the future* | The device clock is ahead. Fix it in system settings; the server refuses to bank unearned days. |
| Org dashboards stay empty | Fewer than five active contributors in the same cohort, no `organization_id` on the profiles, or every row is untrusted. |
| `permission denied for table analytics_daily` | Expected after `supabase_validation.sql`. The app uses the RPC, not direct writes. |
| OAuth works on Android but not Windows | Windows and Linux register no native URL scheme. Use email and password there. |

---

## 9. What is deliberately not collected

The app records **no IP address, no location, no advertising identifier and no
device fingerprint**. An earlier design request asked for the device IP; it was
declined because pairing it with per-employee timestamps converts a wellness app
into individual employee monitoring, contradicts the aggregation guarantees
above, and is personal data under both the GDPR and Cameroon's data-protection
law. Resolving an IP would additionally require a third-party lookup service,
which would leak every user's address to that service.

What is captured is operational metadata only — device type, operating system
and version, app version, screen size, locale and time zone — read from the
device itself, stored locally, and shown to the user in
**Settings → Device & app**, where they can audit the exact payload before
opting in to anything.

---

## 10. Related files

| File | Purpose |
| --- | --- |
| `supabase_schema.sql` | Tables, RLS policies, join function, aggregate views |
| `supabase_validation.sql` | Server-side analytics validation and trust filtering |
| `lib/data/remote/supabase_service.dart` | Client wiring, including the RPC call |
| `docs/INSTALL_AND_LAUNCH.md` | Release build commands and Android keystore setup |
