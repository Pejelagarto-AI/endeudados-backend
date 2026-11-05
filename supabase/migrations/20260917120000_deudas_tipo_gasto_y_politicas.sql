-- Captura de los cambios que se hicieron desde el dashboard el 17-sep (EN-54).
--
-- Contexto: la tabla `deudas`, la columna `gastos.tipo` y tres politicas nuevas
-- se crearon haciendo clic en el dashboard de Supabase, no como migracion. El
-- repo quedo desactualizado el mismo dia que se creo, que es exactamente el
-- problema que este repo existe para evitar.
--
-- Esta migracion NO diseña nada nuevo: transcribe lo que ya esta corriendo en
-- produccion, verificado contra el catalogo de Postgres el 21-sep. Es
-- idempotente a proposito, porque los objetos ya existen alla: aplicarla en
-- produccion no debe cambiar nada, y aplicarla en una base limpia debe dejarla
-- igual a produccion.
--
-- Lo que queda pendiente y NO se corrige aqui:
--   EN-55  falta el indice en deudas.usuario_id
--   EN-56  gastos e ingresos quedaron con politicas duplicadas (las viejas de
--          SELECT e INSERT mas las nuevas de tipo ALL), y las nuevas aplican al
--          rol `public` en vez de `authenticated`
-- Corregirlas aqui haria que esta migracion dejara de describir produccion.

-- ---------------------------------------------------------------------------
-- Tabla deudas
-- ---------------------------------------------------------------------------
-- Una deuda del usuario. El orden de pago se calcula con tasa_ea (metodo
-- avalancha: primero la de mayor tasa efectiva anual).

create table if not exists public.deudas (
  id          bigint    generated always as identity,
  usuario_id  uuid      not null references public.usuarios (id) on delete cascade,
  nombre      text      not null,
  saldo       numeric   not null,
  tasa_ea     numeric   not null default 0,
  pago_minimo numeric   not null default 0,
  fecha       date      not null default current_date,
  creado_en   timestamp not null default now(),
  constraint deudas_pkey primary key (id)
);

-- ---------------------------------------------------------------------------
-- gastos.tipo
-- ---------------------------------------------------------------------------
-- Separa el gasto esencial (arriendo, comida, transporte) del gasto hormiga
-- (cafe, domicilios, suscripciones olvidadas), que es el que la landing usa
-- como gancho. Por defecto 'esencial' para no romper las filas que ya existian.

alter table public.gastos
  add column if not exists tipo text not null default 'esencial';

alter table public.gastos
  drop constraint if exists gastos_tipo_check;

alter table public.gastos
  add constraint gastos_tipo_check check (tipo in ('esencial', 'hormiga'));

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.deudas enable row level security;

-- Politicas de tipo ALL: cubren select, insert, update y delete de una vez.
-- Con estas, el usuario ya puede corregir y borrar sus ingresos, gastos y
-- deudas, que antes era imposible porque solo existian SELECT e INSERT.
--
-- Nota: quedaron sin rol explicito, o sea aplican a `public`, que incluye a
-- `anon`. No exponen datos igual: sin sesion `auth.uid()` es nulo, la subconsulta
-- no devuelve ninguna fila y la condicion nunca se cumple. Aun asi conviene
-- restringirlas a `authenticated` (EN-56).

drop policy if exists deudas_propietario on public.deudas;
create policy deudas_propietario on public.deudas
  for all
  using      (usuario_id = (select id from public.usuarios where auth_id = auth.uid()))
  with check (usuario_id = (select id from public.usuarios where auth_id = auth.uid()));

drop policy if exists gastos_propietario on public.gastos;
create policy gastos_propietario on public.gastos
  for all
  using      (usuario_id = (select id from public.usuarios where auth_id = auth.uid()))
  with check (usuario_id = (select id from public.usuarios where auth_id = auth.uid()));

drop policy if exists ingresos_propietario on public.ingresos;
create policy ingresos_propietario on public.ingresos
  for all
  using      (usuario_id = (select id from public.usuarios where auth_id = auth.uid()))
  with check (usuario_id = (select id from public.usuarios where auth_id = auth.uid()));
