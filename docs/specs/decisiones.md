# Registro de decisiones (ADR)

Formato: contexto, decisión, alternativas y consecuencias. Una decisión no se edita: se **sustituye** por un ADR nuevo que la marca como `Sustituido por ADR-XXXX`.

---

## ADR-0001

**MongoDB con Mongoid como base de datos** · Aceptado · 2026-09-21

- **Contexto:** el grueso de los datos es un log de eventos heterogéneos (commits, eventos de Claude y análisis), y el esquema va a cambiar mucho durante el MVP.
- **Decisión:** MongoDB + Mongoid. Las entidades relacionales (usuarios, equipos, membresías y asignaciones) usan referencias con índices, y las invariantes se imponen en servicios.
- **Alternativas:** PostgreSQL con JSONB (más robusto para lo relacional, pero descartado por preferencia del equipo y por el log de eventos).
- **Consecuencias:** no hay transacciones multi-documento por defecto. Las operaciones críticas (contadores `F-n`, votos) se hacen con operadores atómicos (`$inc`, `$addToSet`). Solid Queue y GoodJob no sirven (→ ADR-0002).

## ADR-0002

**Sidekiq + Redis para los jobs** · Aceptado · 2026-09-21

- **Contexto:** Solid Queue y GoodJob dependen de SQL.
- **Decisión:** Sidekiq con `sidekiq-cron` para las tareas periódicas. Redis se usa también para rate limiting, locks y caché de tokens de GitHub.
- **Consecuencias:** hay un servicio más (Redis) que operar.

## ADR-0003

**Gemini como proveedor de IA de la app, detrás de una interfaz** · Aceptado · 2026-09-21

- **Contexto:** el plan original proponía la API de Claude. Se decide integrar la API de Gemini para la IA interna. Claude sigue presente como **fuente de actividad** (el Claude Code de los miembros), no como motor de análisis.
- **Decisión:** `Ai::Provider` con una implementación `Ai::Gemini`, salida JSON estructurada con `responseSchema` y validación propia en el servidor. El modelo se configura con `GEMINI_MODEL`.
- **Alternativas:** la API de Claude (se puede añadir como otra implementación de `Ai::Provider` sin tocar el dominio).
- **Consecuencias:** los esquemas de salida viven en `shared-schemas` y se traducen al subconjunto de OpenAPI que acepta Gemini. Hay que revisar sus límites (tipos soportados, enums) al implementarlo.

## ADR-0004

**GitHub App en lugar de OAuth personal** · Aceptado · 2026-09-21

- **Decisión:** una GitHub App con permisos de solo lectura, webhooks por instalación y OAuth de usuario para el login.
- **Alternativas:** OAuth App con token personal (permisos amplios, webhooks creados a mano por repo y dependencia de una persona).
- **Consecuencias:** en orgs, un admin tiene que aprobar la instalación (R5).

## ADR-0005

**Polling en lugar de websockets en el MVP** · Aceptado · 2026-09-21

- **Decisión:** TanStack Query con intervalos de 15–60 s y refetch al recuperar el foco.
- **Consecuencias:** latencia visible de hasta 15 s. Se migra a ActionCable si el feedback lo pide.

## ADR-0006

**Metadatos por defecto en los eventos de Claude Code** · Aceptado · 2026-09-21

- **Decisión:** el nivel `metadata` es el que viene por defecto. El texto de los prompts nunca se persiste. Los resúmenes provienen de Claude vía MCP (opción A de [08](08-integracion-claude-code.md#niveles-de-privacidad)).
- **Consecuencias:** hay menos riqueza para la atribución por IA, compensada con rutas de ficheros y ramas.

## ADR-0007

**Un repositorio activo pertenece a un solo equipo** · Aceptado · 2026-09-21

- **Contexto:** un webhook se tiene que resolver a un único equipo sin ambigüedad.
- **Decisión:** hay unicidad sobre `(github_repo_id, active: true)`.
- **Consecuencias:** no se contemplan dos equipos compartiendo repo. Se revisará si aparece el caso.

## ADR-0008

**Sesión con cookie opaca en lugar de JWT** · Aceptado · 2026-09-21

- **Decisión:** token aleatorio en una cookie httpOnly y `Session` en Mongo (con el digest), con revocación inmediata.
- **Alternativas:** JWT (sin revocación sencilla) o Devise (encaja peor en modo API con Mongoid).
- **Consecuencias:** la web y la API tienen que compartir dominio padre (p. ej. `app.x` y `api.x`) para que funcione `SameSite=Lax`.
