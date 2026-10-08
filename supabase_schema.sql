-- ==============================================================================
-- Supabase Database Schema & Row-Level Security (RLS)
-- Cross-Platform Employee Health & Wellness Reminder App (StandUp)
-- ==============================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Organizations Table
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    domain TEXT NOT NULL UNIQUE,
    code TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Profiles Table (Extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    designation TEXT,
    department TEXT,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    role TEXT NOT NULL DEFAULT 'employee' CHECK (role IN ('employee', 'admin', 'manager')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Reminder Logs Table (Private to user)
CREATE TABLE IF NOT EXISTS public.reminder_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    scheduled_time TIMESTAMPTZ NOT NULL,
    action_taken TEXT NOT NULL CHECK (action_taken IN ('completed', 'snoozed', 'skipped')),
    snooze_duration INTEGER DEFAULT 0, -- in minutes
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Daily Analytics Table (Per employee daily summary)
CREATE TABLE IF NOT EXISTS public.analytics_daily (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    reminders_sent INTEGER DEFAULT 0,
    reminders_completed INTEGER DEFAULT 0,
    reminders_snoozed INTEGER DEFAULT 0,
    reminders_skipped INTEGER DEFAULT 0,
    total_stand_time INTEGER DEFAULT 0, -- in minutes (5 min per completed reminder)
    organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_user_daily_analytics UNIQUE (user_id, date)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_reminder_logs_user_time ON public.reminder_logs(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_daily_user_date ON public.analytics_daily(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_daily_org_date ON public.analytics_daily(organization_id, date DESC);

-- ==============================================================================
-- 6. Helper Security Functions
-- ==============================================================================

-- Keep authorization helpers outside exposed API schemas.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

-- Check if current user is an admin of an organization
CREATE OR REPLACE FUNCTION private.is_org_admin(org_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
      AND profiles.organization_id = org_id
  );
$$;

REVOKE ALL ON FUNCTION private.is_org_admin(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_org_admin(UUID) TO authenticated;

-- ==============================================================================
-- 7. Row Level Security (RLS) Configuration
-- ==============================================================================

-- Enable RLS on all tables
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminder_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_daily ENABLE ROW LEVEL SECURITY;

-- ORGANIZATIONS POLICIES
CREATE POLICY "Organizations are viewable by authenticated users"
    ON public.organizations FOR SELECT
    TO authenticated
    USING (true);
REVOKE ALL ON public.organizations FROM anon, authenticated;
GRANT SELECT (id, name, domain) ON public.organizations TO authenticated;

-- PROFILES POLICIES
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- A client must never grant itself an administrator role or move itself into
-- an arbitrary organization. Membership changes belong in a trusted invite flow.
REVOKE INSERT, UPDATE ON public.profiles FROM authenticated;
GRANT SELECT ON public.profiles TO authenticated;
GRANT INSERT (id, name, designation, department)
    ON public.profiles TO authenticated;
GRANT UPDATE (name, designation, department, updated_at)
    ON public.profiles TO authenticated;

-- REMINDER LOGS POLICIES (Strict individual privacy)
CREATE POLICY "Users can view own reminder logs"
    ON public.reminder_logs FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own reminder logs"
    ON public.reminder_logs FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);
GRANT SELECT, INSERT ON public.reminder_logs TO authenticated;

-- ANALYTICS DAILY POLICIES
CREATE POLICY "Users can view own daily analytics"
    ON public.analytics_daily FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert/update own daily analytics"
    ON public.analytics_daily FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.analytics_daily TO authenticated;

-- Enable private per-user daily totals for Supabase Realtime clients. Row-level
-- security remains in force for every event delivered to an authenticated user.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'analytics_daily'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.analytics_daily;
  END IF;
END;
$$;

-- Organization membership is sourced from the private profile row, never from
-- a client-supplied analytics payload.
CREATE OR REPLACE FUNCTION public.set_analytics_organization()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  SELECT p.organization_id INTO NEW.organization_id
  FROM public.profiles AS p
  WHERE p.id = NEW.user_id;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.set_analytics_organization() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS analytics_organization_from_profile ON public.analytics_daily;
CREATE TRIGGER analytics_organization_from_profile
BEFORE INSERT OR UPDATE ON public.analytics_daily
FOR EACH ROW EXECUTE FUNCTION public.set_analytics_organization();

-- Invite codes are accepted only through this authenticated, narrowly scoped
-- function. They are never selectable through the organizations table API.
CREATE OR REPLACE FUNCTION public.join_organization(invite_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  current_user_id UUID := (SELECT auth.uid());
  matched_org_id UUID;
  matched_org_name TEXT;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Sign in before joining a workspace';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM auth.users AS u
     WHERE u.id = current_user_id
       AND u.email_confirmed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Confirm your email before joining a workspace';
  END IF;

  SELECT o.id, o.name
    INTO matched_org_id, matched_org_name
    FROM public.organizations AS o
   WHERE upper(trim(o.code)) = upper(trim(invite_code));

  IF matched_org_id IS NULL THEN
    RAISE EXCEPTION 'That workspace invite code is not valid';
  END IF;

  INSERT INTO public.profiles (id, name)
  VALUES (current_user_id, 'Employee')
  ON CONFLICT (id) DO NOTHING;

  UPDATE public.profiles
     SET organization_id = matched_org_id,
         updated_at = now()
   WHERE id = current_user_id;

  RETURN jsonb_build_object('id', matched_org_id, 'name', matched_org_name);
END;
$$;

REVOKE ALL ON FUNCTION public.join_organization(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_organization(TEXT) TO authenticated;

-- Keep per-employee summaries private. Organization access is only through
-- aggregate views below, with a minimum cohort size to reduce re-identification.

-- ==============================================================================
-- 8. Organization Aggregate Views
-- ==============================================================================

CREATE OR REPLACE VIEW public.org_analytics_daily WITH (security_barrier = true) AS
SELECT
    organization_id,
    date,
    COUNT(DISTINCT user_id) AS active_users,
    SUM(reminders_sent) AS total_sent,
    SUM(reminders_completed) AS total_completed,
    SUM(reminders_snoozed) AS total_snoozed,
    SUM(reminders_skipped) AS total_skipped,
    SUM(total_stand_time) AS total_stand_minutes,
    CASE
        WHEN SUM(reminders_sent) > 0 THEN
            ROUND((SUM(reminders_completed)::NUMERIC / SUM(reminders_sent)::NUMERIC) * 100, 1)
        ELSE 0
    END AS adherence_rate
FROM public.analytics_daily
WHERE organization_id IS NOT NULL
  AND private.is_org_admin(organization_id)
GROUP BY organization_id, date
HAVING COUNT(DISTINCT user_id) >= 5;

-- Department-level aggregate view
CREATE OR REPLACE VIEW public.org_department_analytics WITH (security_barrier = true) AS
SELECT
    p.organization_id,
    p.department,
    ad.date,
    COUNT(DISTINCT ad.user_id) AS active_users,
    SUM(ad.reminders_completed) AS total_completed,
    SUM(ad.reminders_skipped) AS total_skipped,
    ROUND((SUM(ad.reminders_completed)::NUMERIC / NULLIF(SUM(ad.reminders_sent), 0)) * 100, 1) AS adherence_rate
FROM public.analytics_daily ad
JOIN public.profiles p ON ad.user_id = p.id
WHERE p.organization_id IS NOT NULL
  AND p.department IS NOT NULL
  AND private.is_org_admin(p.organization_id)
GROUP BY p.organization_id, p.department, ad.date
HAVING COUNT(DISTINCT ad.user_id) >= 5;

-- Do not expose underlying row data or aggregate views to unauthenticated users.
REVOKE ALL ON public.org_analytics_daily, public.org_department_analytics FROM PUBLIC, anon;
GRANT SELECT ON public.org_analytics_daily, public.org_department_analytics TO authenticated;

-- ==============================================================================
-- 9. Organization provisioning
-- ============================================================================== 
-- Add real organizations and high-entropy invite codes through a trusted
-- administrative channel. Never ship sample companies or invite secrets.
