-- Limpieza de politicas de RLS (EN-56).
--
-- Situacion antes de esta migracion:
--
--   gastos    ALL     {public}         gastos_propietario
--   gastos    INSERT  {authenticated}  Usuario puede registrar gastos
--   gastos    SELECT  {authenticated}  Usuario puede ver sus gastos
--   ingresos  (lo mismo, tres politicas)
--   usuarios  INSERT  {authenticated}  Usuario puede crear su registro
--   usuarios  INSERT  {authenticated}  Permitir registro de usuarios nuevos   <- identica
--
-- Tres problemas:
--
-- 1. Politicas duplicadas. Las de tipo ALL ya cubren select, insert, update y
--    delete, asi que las viejas de SELECT e INSERT sobran. No hacen daño (las
--    politicas del mismo comando se evaluan con OR), pero ensucian: al leer el
--    esquema no se sabe cual manda.
-- 2. Las de tipo ALL quedaron sin rol, o sea aplican a `public`, que incluye a
--    `anon`. Hoy no exponen nada porque sin sesion `auth.uid()` es nulo y la
--    subconsulta no devuelve filas, pero la proteccion queda dependiendo de ese
--    detalle en vez de decirlo explicito. Se restringen a `authenticated`.
-- 3. `usuarios` tiene dos politicas de INSERT identicas. Se deja una.
--
-- Tambien se envuelve `auth.uid()` en su propia subconsulta. Postgres la evalua
-- entonces una sola vez por consulta en vez de una vez por fila. Es la forma que
-- recomienda Supabase y no cambia el significado de la politica.
--
-- Nota sobre las politicas de INSERT de `usuarios`: desde que el perfil lo crea
-- el trigger `al_crear_usuario`, el cliente ya no inserta ahi. Probablemente
-- sobren las dos, pero quitarlas es un cambio de comportamiento y no de
-- limpieza, asi que se deja una y se decide aparte.

-- ---------------------------------------------------------------------------
-- 1. Fuera las duplicadas
-- ---------------------------------------------------------------------------

drop policy if exists "Usuario puede ver sus gastos"        on public.gastos;
drop policy if exists "Usuario puede registrar gastos"      on public.gastos;
drop policy if exists "Usuario puede ver sus ingresos"      on public.ingresos;
drop policy if exists "Usuario puede registrar ingresos"    on public.ingresos;
drop policy if exists "Permitir registro de usuarios nuevos" on public.usuarios;

-- ---------------------------------------------------------------------------
-- 2. Las de propietario, ahora explicitas para `authenticated`
-- ---------------------------------------------------------------------------

drop policy if exists gastos_propietario on public.gastos;
create policy gastos_propietario on public.gastos
  for all to authenticated
  using      (usuario_id = (select id from public.usuarios where auth_id = (select auth.uid())))
  with check (usuario_id = (select id from public.usuarios where auth_id = (select auth.uid())));

drop policy if exists ingresos_propietario on public.ingresos;
create policy ingresos_propietario on public.ingresos
  for all to authenticated
  using      (usuario_id = (select id from public.usuarios where auth_id = (select auth.uid())))
  with check (usuario_id = (select id from public.usuarios where auth_id = (select auth.uid())));

drop policy if exists deudas_propietario on public.deudas;
create policy deudas_propietario on public.deudas
  for all to authenticated
  using      (usuario_id = (select id from public.usuarios where auth_id = (select auth.uid())))
  with check (usuario_id = (select id from public.usuarios where auth_id = (select auth.uid())));
