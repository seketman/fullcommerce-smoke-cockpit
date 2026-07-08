-- ============================================================
-- 003 · Log de auditoría (append-only): quién hizo cada cambio.
-- Correr una vez en el SQL Editor. Ajustá el dominio si corresponde.
-- ============================================================

create table if not exists public.activity_log (
  id      bigint generated always as identity primary key,
  at      timestamptz not null default now(),
  actor   text,            -- email del usuario
  action  text not null,   -- status | evidence | evidence_del | case | case_del | new_run
  run_id  text,
  target  text,            -- case_id o run id afectado
  detail  text             -- descripción legible
);

create index if not exists activity_log_at_idx on public.activity_log (at desc);

alter table public.activity_log enable row level security;

-- Append-only: solo lectura e inserción (sin update/delete → RLS los bloquea).
drop policy if exists activity_read   on public.activity_log;
drop policy if exists activity_insert on public.activity_log;
create policy activity_read on public.activity_log
  for select to authenticated
  using ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );
create policy activity_insert on public.activity_log
  for insert to authenticated
  with check ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );

grant select, insert on public.activity_log to authenticated;

do $$ begin alter publication supabase_realtime add table public.activity_log; exception when duplicate_object then null; end $$;
