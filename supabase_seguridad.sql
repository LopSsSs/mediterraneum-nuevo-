-- ════════════════════════════════════════════════════════════════
-- Mediterraneum · SEGURIDAD DE LA BASE DE DATOS (RLS)
--
-- PROBLEMA QUE ARREGLA: hasta ahora cualquier usuario registrado
-- (incluso los "pendientes de aprobación") podía leer y modificar
-- TODA la base de datos hablando directamente con Supabase, e
-- incluso cambiarse a sí mismo el rol a "admin".
--
-- QUÉ HACE:
--   · Usuarios "pendientes": no pueden ver ni tocar nada.
--   · Empleados: pueden LEER los datos de la empresa (necesario para
--     el Asistente IA), pero solo ESCRIBIR en los módulos para los
--     que el admin les ha dado permiso.
--   · Solo un admin puede cambiar roles y permisos de usuarios.
--
-- CÓMO EJECUTARLO: pegar TODO este archivo y pulsar Run en
-- https://supabase.com/dashboard/project/cenjzfuywziffieawosj/sql/new
-- Es seguro ejecutarlo varias veces.
-- ════════════════════════════════════════════════════════════════

-- ── Funciones auxiliares (security definer: evitan bucles de RLS) ──

create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from perfiles where id = auth.uid() and rol = 'admin');
$$;

create or replace function public.es_activo() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from perfiles where id = auth.uid() and rol in ('admin','empleado'));
$$;

create or replace function public.tiene_permiso(mod text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from perfiles
    where id = auth.uid()
      and (rol = 'admin' or (rol = 'empleado' and coalesce(permisos->>mod,'false') = 'true'))
  );
$$;

-- ── Activa RLS y elimina las políticas antiguas (demasiado permisivas) ──

do $$
declare t text; p record;
begin
  foreach t in array array['perfiles','clientes','presupuestos','maquinaria','rutas','equipos','trabajadores','empleados'] loop
    if to_regclass('public.'||t) is not null then
      execute format('alter table public.%I enable row level security', t);
      for p in select policyname from pg_policies where schemaname='public' and tablename=t loop
        execute format('drop policy %I on public.%I', p.policyname, t);
      end loop;
    end if;
  end loop;
end $$;

-- ── PERFILES: cada uno ve el suyo; solo el admin gestiona los demás ──

create policy "perfiles_leer" on public.perfiles for select to authenticated
  using (id = auth.uid() or public.es_admin());
-- Primer acceso (p. ej. con Google): el usuario crea su propio perfil, siempre como "pendiente"
create policy "perfiles_crear" on public.perfiles for insert to authenticated
  with check (id = auth.uid() and rol = 'pendiente');
create policy "perfiles_modificar" on public.perfiles for update to authenticated
  using (public.es_admin()) with check (public.es_admin());
create policy "perfiles_borrar" on public.perfiles for delete to authenticated
  using (public.es_admin());

-- ── CLIENTES: leer cualquier usuario activo; escribir con permiso CRM ──

create policy "clientes_leer" on public.clientes for select to authenticated
  using (public.es_activo());
create policy "clientes_crear" on public.clientes for insert to authenticated
  with check (public.tiene_permiso('crm'));
create policy "clientes_modificar" on public.clientes for update to authenticated
  using (public.tiene_permiso('crm')) with check (public.tiene_permiso('crm'));
create policy "clientes_borrar" on public.clientes for delete to authenticated
  using (public.tiene_permiso('crm'));

-- ── PRESUPUESTOS: leer activos; escribir con permiso de presupuestos ──

create policy "presupuestos_leer" on public.presupuestos for select to authenticated
  using (public.es_activo());
create policy "presupuestos_crear" on public.presupuestos for insert to authenticated
  with check (public.tiene_permiso('presupuestos'));
create policy "presupuestos_modificar" on public.presupuestos for update to authenticated
  using (public.tiene_permiso('presupuestos')) with check (public.tiene_permiso('presupuestos'));
create policy "presupuestos_borrar" on public.presupuestos for delete to authenticated
  using (public.tiene_permiso('presupuestos'));

-- ── MAQUINARIA: leer activos; escribir solo admin (así es en la app) ──

create policy "maquinaria_leer" on public.maquinaria for select to authenticated
  using (public.es_activo());
create policy "maquinaria_escribir" on public.maquinaria for insert to authenticated
  with check (public.es_admin());
create policy "maquinaria_modificar" on public.maquinaria for update to authenticated
  using (public.es_admin()) with check (public.es_admin());
create policy "maquinaria_borrar" on public.maquinaria for delete to authenticated
  using (public.es_admin());

-- ── RUTAS: los empleados leen su ruta del día; solo el admin planifica ──

create policy "rutas_leer" on public.rutas for select to authenticated
  using (public.es_activo());
create policy "rutas_crear" on public.rutas for insert to authenticated
  with check (public.es_admin());
create policy "rutas_modificar" on public.rutas for update to authenticated
  using (public.es_admin()) with check (public.es_admin());
create policy "rutas_borrar" on public.rutas for delete to authenticated
  using (public.es_admin());

-- ── EQUIPOS Y TRABAJADORES: leer activos; escribir con permiso de equipos ──

create policy "equipos_leer" on public.equipos for select to authenticated
  using (public.es_activo());
create policy "equipos_crear" on public.equipos for insert to authenticated
  with check (public.tiene_permiso('equipos'));
create policy "equipos_modificar" on public.equipos for update to authenticated
  using (public.tiene_permiso('equipos')) with check (public.tiene_permiso('equipos'));
create policy "equipos_borrar" on public.equipos for delete to authenticated
  using (public.tiene_permiso('equipos'));

create policy "trabajadores_leer" on public.trabajadores for select to authenticated
  using (public.es_activo());
create policy "trabajadores_crear" on public.trabajadores for insert to authenticated
  with check (public.tiene_permiso('equipos'));
create policy "trabajadores_modificar" on public.trabajadores for update to authenticated
  using (public.tiene_permiso('equipos')) with check (public.tiene_permiso('equipos'));
create policy "trabajadores_borrar" on public.trabajadores for delete to authenticated
  using (public.tiene_permiso('equipos'));

-- ── EMPLEADOS (si la tabla existe): solo lectura para activos, escritura admin ──

do $$
begin
  if to_regclass('public.empleados') is not null then
    execute 'create policy "empleados_leer" on public.empleados for select to authenticated using (public.es_activo())';
    execute 'create policy "empleados_escribir" on public.empleados for all to authenticated using (public.es_admin()) with check (public.es_admin())';
  end if;
end $$;
