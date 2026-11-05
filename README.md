# Endeudados — Backend

Base de datos y lógica de servidor de [Endeudados](https://endeudados.vercel.app).
El frontend vive en el repo `Endeudados`.

El backend es **Supabase** (Postgres administrado + autenticación). No hay un
servidor propio que levantar: lo que se versiona acá es el **esquema**, las
**políticas de seguridad** y, más adelante, las **Edge Functions**.

## Por qué existe este repo

Hasta el 14-sep-2026 el esquema de la base se construyó haciendo clic en el
dashboard de Supabase. Eso significaba que:

- nadie podía revisar un cambio de base de datos en un PR
- no había historia: si alguien borraba una política, no quedaba rastro
- no se podía reproducir el proyecto desde cero
- no había forma de saber si lo que corre en producción es lo que creemos

`supabase/migrations/` arregla eso. Cada cambio en la base es un archivo `.sql`
que se revisa como cualquier otro código.

## Estructura

```
supabase/
  config.toml           configuración del proyecto
  migrations/           cada cambio de esquema, en orden cronológico
    20260911122521_esquema_inicial.sql
```

## Reglas

**1. No se toca el dashboard.** Todo cambio de esquema o de políticas entra por
una migración. Si alguien lo hace por el dashboard, el repo queda mintiendo y
volvemos al problema que este repo existe para resolver.

**2. Las migraciones no se editan una vez mergeadas.** Ya corrieron en la base de
alguien. Para cambiar algo, migración nueva.

**3. Una migración, un ticket.** El nombre del archivo y el commit dicen cuál.

**4. La migración inicial es una fotografía, no un diseño.** Transcribe lo que
había el 14-sep con defectos incluidos. Arreglarlos ahí la volvería inútil como
punto de partida verificable.

## Cómo trabajar

```bash
# instalar el CLI (una vez)
# https://github.com/supabase/cli/releases

# enlazar con el proyecto (una vez; basta con haber hecho supabase login)
supabase link --project-ref nuuqonentwzzhptkjjyh

# ver que migraciones estan aplicadas en produccion y cuales solo en local
supabase migration list

# crear una migración nueva
supabase migration new nombre_descriptivo
# ...escribir el SQL en el archivo que aparece en supabase/migrations/

# probarla en local antes de subirla (necesita Docker)
supabase db reset

# aplicarla a producción (solo después de que el PR esté aprobado)
supabase db push
```

## Historial de migraciones

Hasta el 23-sep el proyecto no tenia tabla de migraciones: el esquema se habia
construido desde el dashboard y Supabase no sabia que ya estaba aplicado. Eso
hacia que `supabase db push` intentara crear todo de nuevo.

Ya quedo resuelto: las seis migraciones del repo estan marcadas como aplicadas
en produccion, asi que `supabase migration list` muestra local y remoto iguales
y `db push` solo aplica lo nuevo.

## Estado actual y deuda conocida

La migración inicial captura el esquema con los defectos que ya tienen ticket:

| Ticket | Qué |
|---|---|
| EN-24 | El registro está roto: RLS rechaza el insert del perfil |
| EN-25 | El perfil debería crearlo un trigger, no el cliente |
| EN-31 | `cedula` es `numeric` y los `creado_en` no tienen zona horaria |
| EN-32 | No existen políticas de `UPDATE` ni `DELETE` |

Pendientes sin ticket todavía:

- **Faltan índices en `gastos.usuario_id` e `ingresos.usuario_id`.** Postgres no
  indexa las llaves foráneas solo. Toda política de RLS de esas dos tablas filtra
  por `usuario_id`, así que hoy cada consulta recorre la tabla entera. Con dos
  usuarios no se nota; con datos reales sí.
- **Los redirect URLs solo tienen producción.** Por eso los correos de
  confirmación y de recuperación no funcionan en local ni en previews. Necesita
  permisos de admin en el proyecto de Supabase.

## Proyecto

- **Ref:** `nuuqonentwzzhptkjjyh`
- **Región:** `ca-central-1` (Canadá)

La región es deliberada. La app guarda cédulas y declara cumplimiento de la Ley
1581 de 2012. El artículo 26 restringe la transferencia de datos personales a
países sin nivel adecuado de protección, y en la lista de la SIC está Canadá y no
está Estados Unidos. No se mueve a `us-east-1` por ~20ms de latencia.

## Sobre la anon key

La `anon key` que usa el frontend es **pública por diseño**: viaja al navegador
en cualquier caso y esconderla no aporta nada. Lo que protege los datos son las
políticas de RLS de este repo.

La que **nunca** va a un repo ni al navegador es la `service_role key`, que
ignora RLS por completo.
