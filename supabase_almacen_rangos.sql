-- ════════════════════════════════════════════════════════════════
-- Mediterraneum · ALMACÉN + RANGOS DE USUARIO
--
-- QUÉ HACE:
--   · Crea la tabla "almacen" (artículos con cantidad y metros,
--     p. ej. cuántos metros de tepe quedan).
--   · Añade los rangos nuevos: "oficina" y "tecnico" (además de
--     admin y empleado). Actualiza las funciones de seguridad para
--     que estos rangos cuenten como usuarios activos y respeten
--     los permisos por módulo igual que los empleados.
--
-- CÓMO EJECUTARLO: pegar TODO este archivo y pulsar Run en
-- https://supabase.com/dashboard/project/cenjzfuywziffieawosj/sql/new
-- Es seguro ejecutarlo varias veces.
-- Requiere haber ejecutado antes supabase_seguridad.sql.
-- ════════════════════════════════════════════════════════════════

-- ── Rangos nuevos: oficina y tecnico cuentan como usuarios activos ──

create or replace function public.es_activo() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from perfiles where id = auth.uid() and rol in ('admin','empleado','oficina','tecnico'));
$$;

create or replace function public.tiene_permiso(mod text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from perfiles
    where id = auth.uid()
      and (rol = 'admin' or (rol in ('empleado','oficina','tecnico') and coalesce(permisos->>mod,'false') = 'true'))
  );
$$;

-- ── Tabla ALMACÉN ──

create table if not exists public.almacen (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null,
  cantidad   numeric not null default 0,
  metros     numeric,
  activo     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table public.almacen enable row level security;

-- Leer: cualquier usuario activo. Escribir: admin o permiso de maquinaria.
drop policy if exists "almacen_leer" on public.almacen;
create policy "almacen_leer" on public.almacen for select to authenticated
  using (public.es_activo());
drop policy if exists "almacen_crear" on public.almacen;
create policy "almacen_crear" on public.almacen for insert to authenticated
  with check (public.tiene_permiso('maquinaria'));
drop policy if exists "almacen_modificar" on public.almacen;
create policy "almacen_modificar" on public.almacen for update to authenticated
  using (public.tiene_permiso('maquinaria')) with check (public.tiene_permiso('maquinaria'));
drop policy if exists "almacen_borrar" on public.almacen;
create policy "almacen_borrar" on public.almacen for delete to authenticated
  using (public.tiene_permiso('maquinaria'));
