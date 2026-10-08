-- Copyright (c) 2026 Fortex Solutions. All rights reserved.
-- Run with psql -X -v ON_ERROR_STOP=1 against the confirmed affected database.
-- Deploy the ID-aware listener and save the original function definition first.
-- Beginner guide: docs/job-notification-repair.md.
-- A database stores jobs. A trigger automatically runs when a job is inserted.
-- This file changes the function called by the existing trigger, not job data.
-- Run it once with psql; afterward the existing trigger runs automatically.
-- BEGIN groups the repair into one transaction so it cannot be partly saved.
BEGIN;
-- Stop instead of waiting indefinitely for other database work to finish.
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- Reject unexpected database objects rather than silently creating a new trigger.
-- Parameters: None; inspects the selected database's catalogs.
-- Returns: No value; permits replacement only for the supported trigger contract.
-- Errors: Raises an exception if the function or attached trigger is incompatible.
-- Notes: Functions with privileged execution or custom settings need manual review.
DO $guard$
BEGIN
  -- PostgreSQL's catalogs describe the functions and triggers in this database.
  -- Require the known public.jobs trigger before changing its function.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc AS p
    JOIN pg_namespace AS n ON n.oid = p.pronamespace
    JOIN pg_language AS l ON l.oid = p.prolang
    JOIN pg_trigger AS t ON t.tgfoid = p.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'notify_job_insert'
      AND p.pronargs = 0
      AND p.prorettype = 'trigger'::regtype
      AND l.lanname = 'plpgsql'
      AND NOT p.prosecdef
      AND p.proconfig IS NULL
      AND t.tgrelid = to_regclass('public.jobs')
      AND NOT t.tgisinternal
      AND t.tgenabled IN ('O', 'A')
      AND (t.tgtype & 1) = 1
      AND (t.tgtype & 2) = 0
      AND (t.tgtype & 4) = 4
      AND (t.tgtype & 64) = 0
  ) THEN
    RAISE EXCEPTION 'Expected enabled AFTER INSERT row trigger on public.jobs using public.notify_job_insert(); inspect database objects before repair';
  END IF;
END;
$guard$;

-- Signal a persisted job using a small JSON record key instead of the full row.
-- Parameters: None explicitly; PostgreSQL supplies NEW for the triggering job.
-- Returns: NEW, preserving the trigger return contract.
-- Errors: PostgreSQL notification errors propagate and roll back the triggering write.
-- Notes: Listener must fetch public.jobs by id; notifications arrive after commit.
CREATE OR REPLACE FUNCTION public.notify_job_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  -- NEW is the job being inserted. Send its ID; the listener fetches full data.
  PERFORM pg_notify('jobs_channel', json_build_object('id', NEW.id)::text);
  RETURN NEW;
END;
$function$;

-- Save the repair only after all checks and the function replacement succeed.
COMMIT;
