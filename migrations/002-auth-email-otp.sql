-- ============================================================
-- 002 · Pasar de acceso anónimo a autenticado (Email OTP) + restricción por dominio.
-- Cierra el write público: solo usuarios logueados con email del dominio permitido
-- pueden leer/escribir. Correr una vez en el SQL Editor de Supabase.
--
-- ⚠️ AJUSTÁ EL DOMINIO: reemplazá 'andreani.com' por el/los dominios reales.
--    Para varios: in ('andreani.com','andreani.com.ar')
--    El MISMO valor va en index.html → window.SMOKE_ALLOWED_DOMAINS.
-- ============================================================

-- ---- cases ----
drop policy if exists cases_anon_all on public.cases;
create policy cases_auth_domain on public.cases
  for all to authenticated
  using      ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') )
  with check ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );

-- ---- case_runs ----
drop policy if exists case_runs_anon_all on public.case_runs;
create policy case_runs_auth_domain on public.case_runs
  for all to authenticated
  using      ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') )
  with check ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );

-- ---- runs ----
drop policy if exists runs_anon_all on public.runs;
create policy runs_auth_domain on public.runs
  for all to authenticated
  using      ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') )
  with check ( lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );

-- ---- storage: bucket evidence ----
drop policy if exists evidence_anon_read  on storage.objects;
drop policy if exists evidence_anon_write on storage.objects;
create policy evidence_auth_read on storage.objects
  for select to authenticated
  using ( bucket_id='evidence' and lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );
create policy evidence_auth_write on storage.objects
  for insert to authenticated
  with check ( bucket_id='evidence' and lower(split_part(auth.jwt()->>'email','@',2)) in ('andreani.com') );

-- ---- grants ----
revoke all on public.cases, public.case_runs, public.runs from anon;
grant  all on public.cases, public.case_runs, public.runs to authenticated;
