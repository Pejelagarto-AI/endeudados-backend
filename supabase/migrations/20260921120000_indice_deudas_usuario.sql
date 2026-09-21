-- Indice en la llave foranea de deudas (EN-55).
--
-- Mismo caso que ingresos y gastos (EN-33): Postgres crea indice automatico
-- para la llave primaria y para las constraints UNIQUE, pero no para las
-- llaves foraneas.
--
-- Importa porque la politica de RLS de deudas filtra por usuario_id en cada
-- consulta:
--
--     usuario_id = (select id from public.usuarios where auth_id = auth.uid())
--
-- Sin indice, Postgres recorre la tabla completa cada vez que alguien abre su
-- plan de pago, y descarta las deudas de los demas una por una. Con cuatro
-- usuarios no se nota; con datos reales si, y justo en la pantalla que es el
-- producto.
--
-- Ademas el `on delete cascade` hacia usuarios recorre la tabla entera al
-- borrar una cuenta, que es lo que pide EN-44.
--
-- No se usa `concurrently`: las migraciones corren dentro de una transaccion y
-- `create index concurrently` no puede ir dentro de una. Con la tabla casi
-- vacia el bloqueo dura microsegundos.

create index if not exists deudas_usuario_id_idx
  on public.deudas (usuario_id);
