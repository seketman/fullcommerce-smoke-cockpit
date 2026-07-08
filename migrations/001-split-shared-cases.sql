-- ============================================================
-- 001 · Separar los casos compartidos (Corpo + PyME) en uno por shell.
-- Cada caso queda con EXACTAMENTE un grupo (corp | pyme | otros).
-- Correr una sola vez en el SQL Editor de Supabase. Es idempotente:
-- si ya no quedan casos compartidos, no hace nada.
-- ============================================================

begin;

-- 1) Crear la copia PyME de cada caso compartido.
insert into public.cases
  (id, groups, module, impl, title, feature, precond, data, steps, expected, warn, flag, sort, updated_at)
select
  id || '-PYME', array['pyme'], module, impl, title, feature, precond, data, steps, expected, warn, flag, sort + 1000, now()
from public.cases
where groups @> array['corp','pyme'];

-- 2) Mover la evidencia ya cargada de los casos compartidos a la copia Corpo.
--    (opcional pero recomendado: no se pierde lo probado hasta ahora)
update public.case_runs
set case_id = case_id || '-CORP'
where case_id in (select id from public.cases where groups @> array['corp','pyme']);

-- 3) Convertir cada original compartido en su copia Corpo.
update public.cases
set id = id || '-CORP', groups = array['corp'], updated_at = now()
where groups @> array['corp','pyme'];

commit;

-- Resultado: los 7 casos compartidos pasan a 14 (7 -CORP + 7 -PYME),
-- total 38 casos. La evidencia previa queda en las copias -CORP.
