-- El perfil de usuario lo crea la base de datos, no el navegador (EN-24, EN-25).
--
-- Problema que resuelve
-- ---------------------
-- Antes, LoginRegistro/auth.js hacía dos pasos separados:
--   1. client.auth.signUp()          crea el usuario en auth.users
--   2. insert en public.usuarios     guarda cédula y nombre
--
-- Como la confirmación por correo es obligatoria, signUp() no devuelve sesión.
-- Sin sesión no hay JWT, el insert del paso 2 sale como rol anon, y la política
-- de INSERT exige authenticated. RLS lo rechazaba siempre: el registro estaba
-- roto en producción. Y si el paso 2 fallaba, el usuario quedaba en auth.users
-- sin perfil y con el correo quemado.
--
-- Arreglarlo en auth.js obligaba a abrirle el INSERT al rol anon, o sea a
-- cualquiera con la anon key. Por eso se mueve a la base.
--
-- Cómo funciona
-- -------------
-- El formulario manda nombre y cédula dentro del signUp:
--
--   client.auth.signUp({ email, password, options: { data: { nombre, cedula } } })
--
-- Supabase guarda eso en auth.users.raw_user_meta_data. Este trigger se dispara
-- cuando se inserta la fila en auth.users y crea el perfil con esos datos.
--
-- Por qué es atómico: el trigger corre dentro de la misma transacción que el
-- insert en auth.users. Si el perfil no se puede crear (cédula repetida, falta
-- el nombre, cédula que no es número), la excepción deshace todo y el usuario
-- tampoco queda creado. Ya no hay usuarios huérfanos.
--
-- Efecto secundario a saber
-- -------------------------
-- Crear un usuario desde el dashboard de Supabase sin nombre ni cédula en los
-- metadatos ahora falla. Es a propósito: en esta app no puede existir un usuario
-- sin perfil.

create or replace function public.crear_perfil_usuario()
returns trigger
language plpgsql
-- Corre con los permisos del dueño de la función, no de quien hizo la petición.
-- Por eso puede insertar en usuarios sin JWT y sin política de RLS para anon.
security definer
-- search_path vacío: toda tabla se escribe con su schema (public.usuarios).
-- Sin esto, alguien podría poner otra tabla "usuarios" antes en el path y hacer
-- que esta función, que tiene permisos elevados, escriba donde no debe.
set search_path = ''
as $$
declare
  v_nombre text := nullif(trim(new.raw_user_meta_data ->> 'nombre'), '');
  v_cedula text := nullif(regexp_replace(coalesce(new.raw_user_meta_data ->> 'cedula', ''), '[^0-9]', '', 'g'), '');
begin
  -- Toda razón de rechazo devuelve EXACTAMENTE el mismo mensaje y código.
  --
  -- Supabase Auth le reenvía al navegador el error de Postgres tal cual. Si la
  -- cédula repetida respondiera "duplicate key ... usuarios_cedula_key" y la
  -- cédula vacía otra cosa, cualquiera podría llamar a /auth/v1/signup con curl
  -- y averiguar qué cédulas están registradas. Esconderlo solo en el mensaje de
  -- auth.js no sirve: la respuesta cruda de la API se lee sin pasar por la
  -- pantalla. Verificado el 16-sep: antes de este bloque la API devolvía el
  -- código y el mensaje originales de Postgres.
  if v_nombre is null or v_cedula is null or length(v_cedula) not between 6 and 10 then
    raise exception 'registro rechazado' using errcode = 'check_violation';
  end if;

  begin
    -- cedula sigue siendo numeric en la tabla. Cambiarla a text es EN-31 y va
    -- en su propia migración. Mientras tanto se limpian puntos y espacios antes
    -- de convertir, para que "1.020.304.050" no reviente el registro.
    insert into public.usuarios (auth_id, nombre, cedula, email)
    values (new.id, v_nombre, v_cedula::numeric, new.email);
  exception
    when others then
      raise exception 'registro rechazado' using errcode = 'check_violation';
  end;

  return new;
end;
$$;

-- La función solo la debe ejecutar el trigger, nunca alguien por la API.
revoke all on function public.crear_perfil_usuario() from public, anon, authenticated;

drop trigger if exists al_crear_usuario on auth.users;

create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil_usuario();
