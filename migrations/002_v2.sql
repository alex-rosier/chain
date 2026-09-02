-- Chain v2 — optional habits, and a reserved slot for biometrics.
-- Safe to run more than once. Paste into Supabase → SQL Editor → Run.
--
-- Note for future migrations: schema.sql uses `create table if not exists`,
-- which is a no-op against an existing table and will NOT add columns. New
-- columns always need their own `alter table ... add column if not exists`,
-- in a file like this one.

-- Optional habits: {"meditate": true, "water": true}. Booleans today; the
-- shape takes {"water": {"n": 5}} or {"bed": {"at": "23:15"}} later without
-- another migration. Never read by chain_status() — these must not touch
-- the chain.
alter table public.days
  add column if not exists x jsonb not null default '{}'::jsonb;

-- Reserved for Oura (sleep, readiness, HRV). Created now so the ingestion
-- job can land without a schema change; deliberately unwired in the client.
-- When it does get wired, note that a day carrying only biometrics is not a
-- day you *logged* — firstDay() must keep ignoring it, or the chain's start
-- date jumps back to whenever the watch was first worn.
alter table public.days
  add column if not exists bio jsonb;

-- chain_status() and chain_nudge() are deliberately untouched. Their return
-- types are fixed, so changing them would force a `drop function ... cascade`
-- and a re-grant; the widget and the 5pm nudge only ever needed the chain.

-- Verify:
--   select column_name, data_type from information_schema.columns
--    where table_name = 'days' order by ordinal_position;
--   select * from chain_status();
