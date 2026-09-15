-- Esquema inicial de Endeudados
--
-- Esto NO es un diseño nuevo: es la captura de lo que ya estaba corriendo en el
-- proyecto de Supabase el 14-sep-2026, construido a mano desde el dashboard y
-- sin quedar registrado en ninguna parte.
--
-- Se transcribe tal cual, con defectos incluidos. Las correcciones van en
-- migraciones posteriores, cada una con su ticket. Si arregláramos cosas acá,
-- este archivo dejaria de describir lo que hay en produccion y perderia el
-- unico valor que tiene: ser el punto de partida verificable.
--
-- Defectos conocidos de este esquema, ya con ticket abierto:
--   EN-31  cedula es numeric (deberia ser text) y los creado_en no tienen zona
--   EN-32  no existen politicas de UPDATE ni DELETE
--   EN-25  el perfil se crea desde el cliente, deberia crearlo un trigger

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------

create table if not exists public.usuarios (
  id        uuid        not null default gen_random_uuid(),
  auth_id   uuid        references auth.users (id),
  cedula    numeric     not null,
  nombre    text        not null,
  email     text        not null,
  creado_en timestamp   default now(),
  constraint usuarios_pkey       primary key (id),
  constraint usuarios_cedula_key unique (cedula),
  constraint usuarios_email_key  unique (email)
);

create table if not exists public.ingresos (
  id          bigint    generated always as identity,
  usuario_id  uuid      references public.usuarios (id) on delete cascade,
  descripcion text,
  monto       numeric   not null,
  fecha       date      default current_date,
  creado_en   timestamp default now(),
  constraint ingresos_pkey primary key (id)
);

create table if not exists public.gastos (
  id          bigint    generated always as identity,
  usuario_id  uuid      references public.usuarios (id) on delete cascade,
  descripcion text,
  categoria   text,
  monto       numeric   not null,
  fecha       date      default current_date,
  creado_en   timestamp default now(),
  constraint gastos_pkey primary key (id)
);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
-- Sin esto las tablas quedan abiertas al rol anon, o sea legibles por cualquiera
-- que tenga la anon key, que es publica y viaja al navegador.

alter table public.usuarios enable row level security;
alter table public.ingresos enable row level security;
alter table public.gastos   enable row level security;

-- usuarios ------------------------------------------------------------------

-- Nota: estas dos politicas de INSERT son identicas. Sobra una. Se deja el
-- duplicado porque asi esta en produccion; se limpia en EN-32.
create policy "Permitir registro de usuarios nuevos"
  on public.usuarios for insert to authenticated
  with check (auth_id = auth.uid());

create policy "Usuario puede crear su registro"
  on public.usuarios for insert to authenticated
  with check (auth_id = auth.uid());

create policy "Usuario puede ver sus datos"
  on public.usuarios for select to authenticated
  using (auth_id = auth.uid());

-- ingresos ------------------------------------------------------------------

create policy "Usuario puede registrar ingresos"
  on public.ingresos for insert to authenticated
  with check (
    usuario_id in (select id from public.usuarios where auth_id = auth.uid())
  );

create policy "Usuario puede ver sus ingresos"
  on public.ingresos for select to authenticated
  using (
    usuario_id in (select id from public.usuarios where auth_id = auth.uid())
  );

-- gastos --------------------------------------------------------------------

create policy "Usuario puede registrar gastos"
  on public.gastos for insert to authenticated
  with check (
    usuario_id in (select id from public.usuarios where auth_id = auth.uid())
  );

create policy "Usuario puede ver sus gastos"
  on public.gastos for select to authenticated
  using (
    usuario_id in (select id from public.usuarios where auth_id = auth.uid())
  );
