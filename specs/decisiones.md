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

## ADR-0009

**La API para terceros es la misma API REST, con tokens de acceso personales y scopes** · Aceptado · 2026-09-22

- **Contexto:** se quiere que agentes y aplicaciones externas lean y modifiquen el tablero con autorización. La web ya consume una API REST completa (`/api/v1`).
- **Decisión:** se abre esa misma API a tokens Bearer `hb_pat_`, ligados a un miembro y a un equipo, con scopes (`read`, `features:write`…) y caducidad obligatoria. Los endpoints de cuenta, administración, integraciones, tokens y borrados quedan solo para la sesión web. Se publica una OpenAPI generada desde los tests. Ver [12](12-acceso-programatico.md).
- **Alternativas:**
  - Una API pública separada o GraphQL: dos contratos que mantener durante un hackathon.
  - OAuth 2.1 desde el principio: es lo correcto para apps de terceros multiusuario, pero es caro de construir. Queda en el backlog (RF-API-010).
  - Reutilizar el token de miembro (`hb_mt_`) con más permisos: mezcla la credencial del CLI, que vive en cada portátil, con credenciales de escritura, y no permite tener varias con permisos distintos.
- **Consecuencias:** una sola implementación por operación. Cada endpoint declara su scope y hay tests de scope y de aislamiento. Las apps de terceros que quieran actuar en nombre de varios usuarios tienen que esperar a OAuth.

## ADR-0010

**Los agentes externos pueden escribir en el tablero en nombre de un miembro** · Aceptado · 2026-09-22

- **Contexto:** el MCP inicial era de solo lectura más `report_progress`, que no cambia estados. Al vibecodear se quiere que el agente se asigne trabajo, mueva features y deje pros y contras, sin pasar por la web. El principio 4 de [00](00-vision.md#principios-de-producto) dice que la IA nunca cambia estados.
- **Decisión:** el MCP y la API permiten escribir con un token cuyo dueño ha elegido esos scopes de forma explícita. El agente actúa **como su dueño**. Cada cambio queda en el feed con la marca `via` (canal, token y cliente). No hay herramientas destructivas ni de administración. El principio 4 se precisa: se refiere a la IA interna (Gemini), que sigue sin poder cambiar nada.
- **Alternativas:** MCP de solo lectura con sugerencias que un humano confirma en la web (más seguro, pero rompe el flujo de vibecodear y la gente acabaría compartiendo su sesión); escritura sin marca de canal (no se podría auditar ni filtrar).
- **Consecuencias:** riesgo de agentes desbocados o manipulados por inyección de prompts (R11), mitigado con preset de solo lectura por defecto, scopes, rate limit, trazabilidad y revocación inmediata.

## ADR-0011

**Servidor de autorización OAuth 2.1 propio, con la identidad delegada en Google y GitHub** · Aceptado · 2026-09-22

- **Contexto:** claude.ai solo admite connectors MCP remotos con OAuth, y las apps de terceros no deberían pedir a la gente que pegue tokens. RF-API-010 tenía abierta la elección entre un servidor propio y un proveedor externo. Se quiere que el usuario entre con Google o con GitHub.
- **Decisión:** Hackboard implementa su propio servidor de autorización OAuth 2.1 (authorization code + PKCE, registro dinámico y *Client ID Metadata Documents*, metadatos RFC 8414 y RFC 9728, parámetro `resource`). Emite tokens propios (`hb_oat_`/`hb_ort_`) con los mismos scopes que los PAT. Google (OpenID Connect) y GitHub (la GitHub App, [ADR-0004](#adr-0004)) solo sirven para **identificar** al usuario en el login y en la pantalla de consentimiento. Sustituye a la alternativa "OAuth en el backlog" de [ADR-0009](#adr-0009): OAuth entra en la F6. Ver [12](12-acceso-programatico.md#oauth-21).
- **Alternativas:**
  - Usar Google o GitHub directamente como servidor de autorización: sus tokens tienen su propia audiencia y sus propios scopes, no saben nada de equipos ni de los permisos de Hackboard, y la especificación de MCP prohíbe aceptar y reenviar tokens de otro servicio (*token passthrough*).
  - Un proveedor externo (Auth0, WorkOS, Clerk…): menos código propio, pero añade coste y dependencia, y los usuarios y las sesiones ya viven en Mongo ([ADR-0008](#adr-0008)).
- **Consecuencias:** hay que mantener un servidor de autorización y tratarlo como código crítico de seguridad (RNF-SEC-015, tests de RNF-API-004). No hay implementación mantenida que encaje bien con Mongoid, así que se valida al empezar la F6 si `doorkeeper` con adaptador Mongo es viable o si se implementa sobre los modelos de [02](02-modelo-datos.md#oauthclient). Se añade una dependencia de Google para el login, que es opcional porque sigue habiendo email + contraseña y GitHub.
