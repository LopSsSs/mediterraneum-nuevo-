-- ════════════════════════════════════════════════════════════════
-- Mediterraneum · DATOS PERSONALES DEL PERFIL
--
-- QUÉ HACE:
--   · Añade a la tabla "perfiles" los campos: apellidos, país y
--     fecha de nacimiento.
--   · Permite que cada usuario edite SU PROPIO perfil desde la app
--     (apartado Configuración · Mi Perfil).
--   · Un trigger impide que un usuario no-admin se cambie a sí mismo
--     el rol o los permisos (la protección clave de RLS se mantiene).
--
-- CÓMO EJECUTARLO: pegar TODO este archivo y pulsar Run en
-- https://supabase.com/dashboard/project/cenjzfuywziffieawosj/sql/new
-- Es seguro ejecutarlo varias veces.
-- Requiere haber ejecutado antes supabase_seguridad.sql.
-- ════════════════════════════════════════════════════════════════

-- ── Nuevas columnas en perfiles ──

alter table public.perfiles add column if not exists apellidos text;
alter table public.perfiles add column if not exists pais text;
alter table public.perfiles add column if not exists fecha_nacimiento date;

-- ── Cada usuario puede modificar su propia fila ──

drop policy if exists "perfiles_modificar_propio" on public.perfiles;
create policy "perfiles_modificar_propio" on public.perfiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- ── Trigger: un no-admin no puede cambiarse el rol ni los permisos ──

create or replace function public.proteger_rol_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.es_admin() then
    new.rol := old.rol;
    new.permisos := old.permisos;
  end if;
  return new;
end $$;

drop trigger if exists trg_proteger_rol on public.perfiles;
create trigger trg_proteger_rol before update on public.perfiles
  for each row execute function public.proteger_rol_perfil();
