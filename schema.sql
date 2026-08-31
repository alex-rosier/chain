-- Chain — one table, one row per day.
-- Paste into Supabase → SQL Editor → Run.

create table if not exists public.days (
  d    date        primary key,          -- local calendar day, "YYYY-MM-DD"
  w    boolean     not null default false, -- workout
  c    boolean     not null default false, -- content
  r    boolean     not null default false, -- rest day (bridges the chain)
  m    smallint,                           -- mood 1-5, null = not logged
  n    text        not null default '',    -- one-line note
  u    bigint      not null default 0,     -- client updated-at (ms) — last write wins
  constraint mood_range check (m is null or (m between 1 and 5))
);

-- Fast "what changed since I last synced"
create index if not exists days_u_idx on public.days (u);

alter table public.days enable row level security;

-- Single-user app: the publishable key is the credential, and it only ever
-- reaches Alex's own devices. Scoped to this one table and nothing else.
drop policy if exists "chain read"   on public.days;
drop policy if exists "chain write"  on public.days;
drop policy if exists "chain update" on public.days;

create policy "chain read"   on public.days for select to anon using (true);
create policy "chain write"  on public.days for insert to anon with check (true);
create policy "chain update" on public.days for update to anon using (true) with check (true);
-- deliberately no delete policy: days are edited, never destroyed.

-- Read-only helper the widget and the 5pm nudge call, so they don't have to
-- know the streak rules. Returns exactly one row.
create or replace function public.chain_status()
returns table (today date, w boolean, c boolean, r boolean, m smallint, streak int)
language plpgsql
security definer
set search_path = public
as $$
declare
  t date := (now() at time zone 'America/New_York')::date;
  s int := 0;
  cur date;
  rec public.days%rowtype;
begin
  select * into rec from public.days where d = t;

  -- Walk back from today. A blank today is grace (the day isn't over);
  -- rest days bridge without adding. A missing row ends the walk.
  cur := t;
  if not (coalesce(rec.w,false) and coalesce(rec.c,false)) then
    cur := t - 1;
  end if;

  while cur > t - 3650 loop
    select * into rec from public.days where d = cur;
    if coalesce(rec.w,false) and coalesce(rec.c,false) then
      s := s + 1;
    elsif coalesce(rec.r,false) then
      null; -- bridge, no increment
    else
      exit;
    end if;
    cur := cur - 1;
  end loop;

  select * into rec from public.days where d = t;
  return query select t,
    coalesce(rec.w,false), coalesce(rec.c,false), coalesce(rec.r,false),
    rec.m, s;
end;
$$;

grant execute on function public.chain_status() to anon;

-- One-line nudge text, or empty string when there's nothing to nag about.
-- Keeping the logic here means the iPhone Shortcut and the Mac job are both
-- four dumb steps: fetch, check empty, notify.
create or replace function public.chain_nudge()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  st record;
  left_txt text;
begin
  select * into st from public.chain_status();

  if st.r or (st.w and st.c) then
    return '';
  end if;

  left_txt := case
    when not st.w and not st.c then 'Workout and content still open'
    when not st.w then 'Workout still open'
    else 'Content still open'
  end;

  if st.streak > 0 then
    return left_txt || ' — ' || st.streak || '-day chain on the line.';
  end if;
  return left_txt || ' — start a new chain today.';
end;
$$;

grant execute on function public.chain_nudge() to anon;
