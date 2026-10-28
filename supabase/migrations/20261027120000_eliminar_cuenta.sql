-- Eliminar la cuenta y todos sus datos (EN-44).
--
-- La landing promete, citando el art. 9 de la Ley 1581, que el titular puede
-- eliminar su cuenta y sus datos en cualquier momento. Esto lo cumple.
--
-- Por que una funcion en la base y no una Edge Function con service role (que
-- es lo que proponia el ticket): el cliente no puede borrar de `auth.users`,
-- pero una funcion `security definer` corre con los permisos de su dueño
-- (postgres), que si puede. Se obtiene lo mismo sin desplegar nada aparte, sin
-- que la service role key exista fuera de Supabase, y todo pasa en una sola
-- transaccion: o se borra todo, o no se borra nada.
--
-- Lo que la hace segura: no recibe parametros. Borra a `auth.uid()`, el usuario
-- de la sesion, y a nadie mas. No hay forma de pasarle el id de otro.

-- ---------------------------------------------------------------------------
-- 1. Que borrar el usuario de auth arrastre su perfil
-- ---------------------------------------------------------------------------
--
-- Hoy usuarios.auth_id apunta a auth.users sin ON DELETE: borrar el usuario de
-- auth fallaria porque el perfil lo sigue referenciando. Con cascade, la cadena
-- queda completa: auth.users -> usuarios -> ingresos, gastos, deudas, abonos.
-- Sirve tambien si alguien borra un usuario desde el panel de Authentication.

alter table public.usuarios
  drop constraint if exists usuarios_auth_id_fkey,
  add  constraint usuarios_auth_id_fkey
       foreign key (auth_id) references auth.users (id) on delete cascade;

-- ---------------------------------------------------------------------------
-- 2. La funcion
-- ---------------------------------------------------------------------------

create or replace function public.eliminar_cuenta()
returns void
language plpgsql
security definer
-- search_path vacio: dentro de la funcion todo va con esquema explicito, asi
-- nadie puede colarle una tabla `users` propia que se resuelva primero.
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'No hay sesion: no hay cuenta que eliminar'
      using errcode = '42501';
  end if;

  delete from auth.users where id = uid;
end;
$$;

-- Por defecto cualquier rol puede ejecutar una funcion nueva. Solo un usuario
-- con sesion puede eliminar su cuenta.
revoke all     on function public.eliminar_cuenta() from public, anon;
grant  execute on function public.eliminar_cuenta() to authenticated;
