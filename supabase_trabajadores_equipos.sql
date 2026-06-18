-- ════════════════════════════════════════════════════════════════
-- Mediterraneum · Tablas que faltaban para el módulo "Equipos"
-- Crea las tablas "trabajadores" y "equipos" (si no existen) y deja
-- el acceso abierto a usuarios autenticados, igual que el resto de la app.
-- Es seguro ejecutarlo aunque alguna tabla ya exista (usa IF NOT EXISTS).
-- Pegar y ejecutar en: Supabase → SQL Editor
-- ════════════════════════════════════════════════════════════════

-- Trabajadores
create table if not exists public.trabajadores (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null,
  activo     boolean not null default true,
  created_at timestamptz not null default now()
);

-- Equipos de trabajo
create table if not exists public.equipos (
  id                 uuid primary key default gen_random_uuid(),
  nombre             text not null,
  trabajadores_ids   text,
  trabajadores_names text,
  vehiculo_id        uuid,
  maquinaria_ids     text,
  maquinaria_names   text,
  zona               text,
  activo             boolean not null default true,
  created_at         timestamptz not null default now()
);

-- Seguridad a nivel de fila (igual que el resto de tablas de la app)
alter table public.trabajadores enable row level security;
alter table public.equipos       enable row level security;

drop policy if exists "trabajadores_auth_all" on public.trabajadores;
create policy "trabajadores_auth_all" on public.trabajadores
  for all to authenticated using (true) with check (true);

drop policy if exists "equipos_auth_all" on public.equipos;
create policy "equipos_auth_all" on public.equipos
  for all to authenticated using (true) with check (true);
