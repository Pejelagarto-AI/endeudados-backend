-- Índices en las llaves foráneas de ingresos y gastos.
--
-- Postgres crea un índice automáticamente para las llaves PRIMARIAS y para las
-- constraints UNIQUE, pero **no** para las llaves foráneas. Hay que crearlos a
-- mano y es fácil que se pase.
--
-- Por qué importa acá: las políticas de RLS de las dos tablas filtran por
-- usuario_id en cada consulta,
--
--     usuario_id in (select id from public.usuarios where auth_id = auth.uid())
--
-- así que sin índice Postgres recorre la tabla completa cada vez que alguien
-- abre su pantalla de ingresos o gastos, y descarta las filas de los demás una
-- por una. Con dos usuarios de prueba no se nota. Con un semestre de
-- movimientos reales sí, y justamente en la pantalla que más se usa.
--
-- El otro efecto: el `on delete cascade` de esas llaves también recorre la tabla
-- entera al borrar un usuario. Eso pega directo en el "eliminar mi cuenta" que
-- promete la landing (EN-32).
--
-- Sobre `concurrently`: en una base con tráfico se usaría, porque crear un
-- índice bloquea escrituras en la tabla. Acá no se usa por dos razones. Una,
-- las migraciones corren dentro de una transacción y `create index
-- concurrently` no puede ir dentro de una. Dos, las tablas están prácticamente
-- vacías, así que el bloqueo dura microsegundos. Cuando la base tenga volumen
-- real y haga falta un índice nuevo, ahí sí toca sacar esa sentencia de la
-- migración normal y correrla aparte.

create index if not exists ingresos_usuario_id_idx
  on public.ingresos (usuario_id);

create index if not exists gastos_usuario_id_idx
  on public.gastos (usuario_id);
