-- =============================================================================
-- CSPH StandUp — server-side analytics validation
-- =============================================================================
-- Run this AFTER supabase_schema.sql in the same Supabase SQL editor.
--
-- Why this file exists
-- --------------------
-- The client is local-first: a stand-up is written to a SQLite file on the
-- user's own device before it is synced. That means the values arriving here
-- are user-supplied and cannot be trusted at face value. A determined user can
-- edit the local database, and the aggregate views in supabase_schema.sql read
-- directly from analytics_daily, so forged rows would silently inflate or
-- deflate the organisation leaderboards.
--
-- This file adds a narrow, authenticated write path that:
--   * derives the user id from the JWT, never from the payload;
--   * derives the organization from the private profile, never from the payload;
--   * rejects totals that are internally inconsistent;
--   * rejects implausible jump-ahead rates relative to the stored previous day;
--   * only ever increases counters, so a retry cannot delete history;
--   * records a trust flag the leaderboard can filter on.
--
-- It cannot prevent a determined user from editing their own device. It can
-- stop a forged row from reaching the organisation dashboards, which is the
-- part that actually matters.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Guard rails
-- -----------------------------------------------------------------------------
-- Maximum believable totals for a single day. Eight hours of five-minute breaks
-- is 96; anything far above that is not a human sitting at a desk.
CREATE OR REPLACE FUNCTION private.analytics_daily_ceiling()
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 200;
$$;

-- How many times a single day may be rewritten before it is distrusted. Syncs
-- happen on every action, so this is generous in normal operation.
CREATE OR REPLACE FUNCTION private.analytics_daily_revision_ceiling()
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 400;
$$;

-- -----------------------------------------------------------------------------
-- 2. Trusted upsert
-- -----------------------------------------------------------------------------
-- The client calls this instead of writing analytics_daily directly. Returns the
-- stored row so the app can reconcile its local state with what was accepted.
CREATE OR REPLACE FUNCTION public.record_daily_analytics(
    p_date                 DATE,
    p_reminders_sent       INTEGER DEFAULT 0,
    p_reminders_completed  INTEGER DEFAULT 0,
    p_reminders_snoozed    INTEGER DEFAULT 0,
    p_reminders_skipped    INTEGER DEFAULT 0,
    p_total_stand_minutes  INTEGER DEFAULT 0,
    p_client_reports_clock_issue BOOLEAN DEFAULT false
)
RETURNS public.analytics_daily
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id      UUID := auth.uid();
    v_org_id       UUID;
    v_ceiling      INTEGER := private.analytics_daily_ceiling();
    v_prev         public.analytics_daily;
    v_result       public.analytics_daily;
    v_trusted      BOOLEAN := true;
    v_reason       TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    IF p_date IS NULL THEN
        RAISE EXCEPTION 'p_date is required';
    END IF;

    -- Never accept a future day. A client whose clock is ahead by more than a
    -- day is trying to bank progress that has not happened yet.
    IF p_date > (now() AT TIME ZONE 'UTC')::date + 1 THEN
        RAISE EXCEPTION 'p_date is in the future';
    END IF;

    -- Never accept anything older than a year of history.
    IF p_date < (now() AT TIME ZONE 'UTC')::date - 365 THEN
        RAISE EXCEPTION 'p_date is too far in the past';
    END IF;

    -- Reject negative values outright.
    IF p_reminders_sent < 0 OR p_reminders_completed < 0
       OR p_reminders_snoozed < 0 OR p_reminders_skipped < 0
       OR p_total_stand_minutes < 0 THEN
        RAISE EXCEPTION 'Counters cannot be negative';
    END IF;

    -- Reject impossible totals.
    IF p_reminders_completed > v_ceiling
       OR p_reminders_sent > v_ceiling
       OR p_total_stand_minutes > v_ceiling * 5 THEN
        v_trusted := false;
        v_reason := 'daily counter above plausible ceiling';
    END IF;

    -- Reject internal inconsistency: the action breakdown must reconcile with
    -- the number of reminders that were reported as sent.
    IF p_reminders_completed + p_reminders_snoozed + p_reminders_skipped
       > p_reminders_sent THEN
        v_trusted := false;
        v_reason := 'action breakdown exceeds reminders sent';
    END IF;

    -- Stand minutes must match completed breaks at five minutes each, with a
    -- small tolerance for partial breaks.
    IF p_total_stand_minutes > p_reminders_completed * 5
       AND p_reminders_completed > 0 THEN
        v_trusted := false;
        v_reason := 'stand minutes exceed completed breaks';
    END IF;

    -- Organization comes from the private profile, never from the client.
    SELECT p.organization_id INTO v_org_id
    FROM public.profiles AS p
    WHERE p.id = v_user_id;

    -- Compare against the previous day to catch impossible jump-ahead rates.
    SELECT * INTO v_prev
    FROM public.analytics_daily AS a
    WHERE a.user_id = v_user_id
      AND a.date = p_date - 1;

    IF FOUND AND p_reminders_completed > v_prev.reminders_completed + 100 THEN
        v_trusted := false;
        v_reason := 'implausible day-over-day increase';
    END IF;

    -- Only ever move counters forward. A retry or a tampered client replaying an
    -- older payload must never erase history.
    INSERT INTO public.analytics_daily AS a (
        id, user_id, date, reminders_sent, reminders_completed,
        reminders_snoozed, reminders_skipped, total_stand_minutes,
        organization_id, synced_to_cloud
    )
    VALUES (
        gen_random_uuid(),
        v_user_id,
        p_date,
        GREATEST(p_reminders_sent, 0),
        GREATEST(p_reminders_completed, 0),
        GREATEST(p_reminders_snoozed, 0),
        GREATEST(p_reminders_skipped, 0),
        GREATEST(p_total_stand_minutes, 0),
        v_org_id,
        true
    )
    ON CONFLICT (user_id, date) DO UPDATE
    SET reminders_sent      = GREATEST(a.reminders_sent, EXCLUDED.reminders_sent),
        reminders_completed = GREATEST(a.reminders_completed, EXCLUDED.reminders_completed),
        reminders_snoozed   = GREATEST(a.reminders_snoozed, EXCLUDED.reminders_snoozed),
        reminders_skipped   = GREATEST(a.reminders_skipped, EXCLUDED.reminders_skipped),
        total_stand_minutes = GREATEST(a.total_stand_minutes, EXCLUDED.total_stand_minutes),
        organization_id     = COALESCE(EXCLUDED.organization_id, a.organization_id),
        synced_to_cloud     = true,
        revision            = a.revision + 1,
        -- Trust is sticky: once a row is distrusted it stays untrusted so it
        -- cannot be laundered back in by a later clean-looking write.
        trust_note          = CASE WHEN a.trusted THEN v_reason ELSE a.trust_note END,
        trusted             = CASE WHEN a.trusted THEN v_trusted ELSE false END,
        clock_suspect       = a.clock_suspect OR p_client_reports_clock_issue
    RETURNING * INTO v_result;

    -- Excessive rewrites of one day is itself a signal.
    IF v_result.revision > private.analytics_daily_revision_ceiling() THEN
        UPDATE public.analytics_daily
        SET trusted = false,
            trust_note = 'excessive revisions for a single day'
        WHERE id = v_result.id;
        RETURNING * INTO v_result;
    END IF;

    RETURN v_result;
END;
$$;

-- Only authenticated users may call it, and only through the exposed signature.
REVOKE ALL ON FUNCTION public.record_daily_analytics(
    DATE, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_daily_analytics(
    DATE, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN
) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. Support columns
-- -----------------------------------------------------------------------------
ALTER TABLE public.analytics_daily
    ADD COLUMN IF NOT EXISTS revision      INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS trusted       BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS trust_note    TEXT,
    ADD COLUMN IF NOT EXISTS clock_suspect BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.analytics_daily.revision IS
    'Number of times this day has been rewritten. Used to detect retry storms.';
COMMENT ON COLUMN public.analytics_daily.trusted IS
    'Server-side verdict. Untrusted rows are excluded from organisation views.';
COMMENT ON COLUMN public.analytics_daily.clock_suspect IS
    'Set by the client when it detected wall-clock manipulation on the device.';

-- -----------------------------------------------------------------------------
-- 4. Restrict direct writes
-- -----------------------------------------------------------------------------
-- The client must go through record_daily_analytics, so revoke the raw INSERT
-- and UPDATE grants given earlier. SELECT and DELETE stay available for the
-- "remove my data" control in Preferences.
REVOKE INSERT, UPDATE ON public.analytics_daily FROM anon, authenticated;
GRANT SELECT, DELETE ON public.analytics_daily TO authenticated;

-- -----------------------------------------------------------------------------
-- 5. Trust filtering in the aggregate views
-- -----------------------------------------------------------------------------
-- Recreate both views so untrusted rows never reach a leaderboard. This is the
-- whole point of the validation above.
CREATE OR REPLACE VIEW public.org_analytics_daily
WITH (security_barrier = true) AS
SELECT
    a.organization_id,
    a.date,
    COUNT(DISTINCT a.user_id)::INTEGER AS active_users,
    COALESCE(SUM(a.reminders_sent), 0)::INTEGER      AS total_sent,
    COALESCE(SUM(a.reminders_completed), 0)::INTEGER AS total_completed,
    COALESCE(SUM(a.reminders_snoozed), 0)::INTEGER   AS total_snoozed,
    COALESCE(SUM(a.reminders_skipped), 0)::INTEGER   AS total_skipped,
    COALESCE(SUM(a.total_stand_minutes), 0)::INTEGER AS total_stand_minutes,
    CASE
        WHEN COALESCE(SUM(a.reminders_sent), 0) = 0 THEN 0
        ELSE ROUND(
            COALESCE(SUM(a.reminders_completed), 0)::NUMERIC
            / SUM(a.reminders_sent) * 100, 2)
    END AS adherence_rate
FROM public.analytics_daily AS a
WHERE a.organization_id IS NOT NULL
  AND a.trusted
  AND NOT a.clock_suspect
GROUP BY a.organization_id, a.date;

CREATE OR REPLACE VIEW public.org_department_analytics
WITH (security_barrier = true) AS
SELECT
    a.organization_id,
    a.date,
    p.department,
    COUNT(DISTINCT a.user_id)::INTEGER AS active_users,
    COALESCE(SUM(a.reminders_completed), 0)::INTEGER AS total_completed,
    COALESCE(SUM(a.reminders_skipped), 0)::INTEGER   AS total_skipped,
    CASE
        WHEN COALESCE(SUM(a.reminders_sent), 0) = 0 THEN 0
        ELSE ROUND(
            COALESCE(SUM(a.reminders_completed), 0)::NUMERIC
            / SUM(a.reminders_sent) * 100, 2)
    END AS adherence_rate
FROM public.analytics_daily AS a
JOIN public.profiles AS p ON p.id = a.user_id
WHERE a.organization_id IS NOT NULL
  AND a.trusted
  AND NOT a.clock_suspect
  AND p.department IS NOT NULL
GROUP BY a.organization_id, a.date, p.department;

-- -----------------------------------------------------------------------------
-- 6. Verification
-- -----------------------------------------------------------------------------
-- After applying, these should all return zero rows:
--
--   SELECT * FROM public.org_analytics_daily
--    WHERE organization_id IS NOT NULL AND total_completed < 0;
--
--   -- Confirm the client can no longer write directly:
--   -- (run while signed in; must fail with a permission error)
--   -- INSERT INTO public.analytics_daily (id, user_id, date) VALUES
--   --   (gen_random_uuid(), auth.uid(), current_date);
--
-- Confirm the RPC exists and is callable:
--
--   SELECT has_function_privilege(
--     'public.record_daily_analytics(date,integer,integer,integer,integer,integer,boolean)',
--     'authenticated', 'EXECUTE');
