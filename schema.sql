-- ============================================================
-- FullCommerce Smoke Cockpit — Supabase schema
-- Run this once in the Supabase SQL Editor of a new project.
-- ============================================================

-- ---- Tables --------------------------------------------------

create table if not exists public.runs (
  id          text primary key,
  name        text,
  started_at  timestamptz not null default now(),
  is_active   boolean     not null default true
);

create table if not exists public.case_runs (
  run_id      text        not null references public.runs(id) on delete cascade,
  case_id     text        not null,
  status      text        not null default 'pending',
  evidence    jsonb       not null default '[]'::jsonb,
  updated_at  timestamptz not null default now(),
  updated_by  text,
  primary key (run_id, case_id)
);

create index if not exists case_runs_run_idx on public.case_runs (run_id);

-- ---- Row Level Security -------------------------------------
-- Auth por Email OTP: solo usuarios logueados con email del dominio permitido
-- pueden leer/escribir. ⚠️ AJUSTÁ el dominio ('andreani.com') al real; el mismo
-- valor va en index.html → window.SMOKE_ALLOWED_DOMAINS.

alter table public.runs      enable row level security;
alter table public.case_runs enable row level security;

drop policy if exists runs_auth_domain on public.runs;
create policy runs_auth_domain on public.runs
  for all to authenticated
  using      ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') )
  with check ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );

drop policy if exists case_runs_auth_domain on public.case_runs;
create policy case_runs_auth_domain on public.case_runs
  for all to authenticated
  using      ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') )
  with check ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );

grant all on public.runs      to authenticated;
grant all on public.case_runs to authenticated;

-- ---- Test-case catalog (editable from the app) -------------
-- The 31 smoke-test cases live here so the team can Add / Update / Remove
-- them from the UI. The app seeds this table from its built-in defaults on
-- first load if it is empty.

create table if not exists public.cases (
  id         text primary key,
  groups     text[]      not null default '{}',   -- corp | pyme | otros
  module     text,                                 -- MF | API | Worker | MF+Worker
  impl       text        not null default 'impl',  -- impl | mock | stub | nofront
  title      text        not null,
  feature    text,
  precond    text,
  data       text,
  steps      jsonb       not null default '[]'::jsonb,
  expected   jsonb       not null default '[]'::jsonb,
  warn       text,
  flag       boolean     not null default false,
  sort       int         not null default 0,
  updated_at timestamptz not null default now(),
  updated_by text
);

alter table public.cases enable row level security;
drop policy if exists cases_auth_domain on public.cases;
create policy cases_auth_domain on public.cases
  for all to authenticated
  using      ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') )
  with check ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );
grant all on public.cases to authenticated;

-- ---- Realtime -----------------------------------------------
-- Push live changes to every open cockpit. Wrapped so the file is re-runnable.
do $$ begin alter publication supabase_realtime add table public.runs;      exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.case_runs;  exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.cases;      exception when duplicate_object then null; end $$;

-- ---- Storage bucket for screenshots -------------------------
insert into storage.buckets (id, name, public)
values ('evidence', 'evidence', true)
on conflict (id) do nothing;

drop policy if exists evidence_auth_read on storage.objects;
create policy evidence_auth_read on storage.objects
  for select to authenticated
  using ( bucket_id = 'evidence' and lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );

drop policy if exists evidence_auth_write on storage.objects;
create policy evidence_auth_write on storage.objects
  for insert to authenticated
  with check ( bucket_id = 'evidence' and lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );
