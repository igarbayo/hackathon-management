# 12 · Acceso programático: API, MCP, OAuth y webhooks

Hackboard se puede usar sin la web. Hay varias puertas de entrada, todas autorizadas:

- **API REST** (`/api/v1`): es la misma API que usa la web ([03](03-api.md)), abierta a scripts, bots y aplicaciones externas con un **token de acceso personal**.
- **Servidor MCP** (`/api/v1/mcp`): herramientas para que los agentes (Claude Code u otros clientes MCP) **vean el estado del proyecto** y, si el token lo permite, **lo modifiquen**: crear features, moverlas en el kanban, asignarse trabajo, añadir pros y contras, informar del progreso…
- **OAuth 2.1** ([abajo](#oauth-21)): claude.ai (como connector) y las apps de terceros piden acceso con una pantalla de consentimiento en la que el usuario entra con Google, GitHub o su contraseña, sin copiar tokens.
- **Tokens de integración** ([abajo](#tokens-de-integración-de-equipo)): credenciales del equipo, no de una persona, para bots y automatizaciones.
- **Webhooks salientes** ([abajo](#webhooks-salientes)): Hackboard avisa a otras apps (Slack, Discord, n8n…) cuando pasa algo.

El caso de uso central es **vibecodear sin perder de vista el tablero**: el agente que escribe el código puede consultar qué feature toca, cuánto falta para el siguiente milestone y qué está haciendo el resto del equipo, y dejar constancia de lo que hace. Ver [ADR-0009](decisiones.md#adr-0009), [ADR-0010](decisiones.md#adr-0010) y [ADR-0011](decisiones.md#adr-0011).

## Principios

1. **Todo acceso tiene un responsable.** Un token pertenece a una persona y a un equipo, y lo que hace un agente o una app con él aparece como hecho por esa persona, con la marca del canal (API o MCP). La única excepción son los tokens de integración, que crea un owner y cuyo actor es la propia integración. No hay accesos anónimos.
2. **Nunca más que el miembro.** Los permisos de un token son la intersección de sus *scopes* con lo que el rol del miembro permite. Un token no puede hacer nada que su dueño no pueda hacer desde la web.
3. **Solo lectura por defecto.** El preset por defecto al crear un token es `observar`. Escribir exige elegirlo de forma explícita.
4. **Sin operaciones destructivas ni de administración.** Borrar, gestionar miembros, repos, tokens o la cuenta solo se hace desde la web con sesión ([tabla de exclusiones](#qué-no-se-puede-hacer-con-un-token)).
5. **Todo cambio es trazable.** Cada escritura hecha con un token deja rastro en el feed con el canal y el prefijo del token ([RF-API-006](#trazabilidad)).
6. **La IA interna no cambia.** El principio "la IA propone y el humano decide" ([00](00-vision.md#principios-de-producto)) se refiere a Gemini dentro de Hackboard. Un agente externo que escribe con un token actúa **como su dueño**, que lo ha autorizado de forma explícita.

---

## Tokens

### Tipos de token

| Prefijo | Tipo | Cómo se obtiene | Para qué |
|---------|------|-----------------|----------|
| `hb_s_` | Sesión | Login en la web | La web (cookie). No sirve como Bearer |
| `hb_mt_` | Token de miembro | `hackboard init` (device flow, [08](08-integracion-claude-code.md)) | CLI de hooks y MCP básico. Scopes fijos: `ingest`, `read`, `progress:write` |
| `hb_pat_` | Token de acceso personal (PAT) | Ajustes → API y MCP ([RF-API-020](04-pantallas.md#equipo-y-ajustes)) | API REST y MCP, con los scopes que elija el miembro |
| `hb_oat_` / `hb_ort_` | Access y refresh token de OAuth | Flujo [OAuth 2.1](#oauth-21) con consentimiento | claude.ai como connector y apps de terceros, con los scopes aprobados |
| `hb_it_` | Token de integración de equipo | Ajustes → Integraciones, solo owners | Bots y automatizaciones del equipo. El actor es la integración |

Todos se envían como `Authorization: Bearer <token>` (salvo la sesión y el refresh token). Solo se guarda el SHA-256, y los que crea una persona se muestran una única vez (RNF-SEC-002).

### Scopes — `RF-API-002` [F2] Aceptado

| Scope | Permite |
|-------|---------|
| `read` | Leer todo el dominio del equipo: equipo (sin secretos), miembros, objetivos, features, argumentos, milestones, timeline, actividad y análisis |
| `features:write` | Crear y editar features, moverlas en el kanban y cambiar asignaciones |
| `objectives:write` | Crear y editar objetivos (no borrarlos) |
| `arguments:write` | Añadir pros y contras, editar los propios y votar |
| `milestones:write` | Crear y editar milestones |
| `attribution:write` | Confirmar, rechazar o fijar la atribución de eventos |
| `analyses:run` | Lanzar un análisis manual (respeta la cuota de [06](06-analisis-ia.md#cuotas)) |
| `progress:write` | Informar del progreso (`report_progress`) |
| `ingest` | Enviar eventos de Claude Code. **Exclusivo del token de miembro** |

Todos los scopes de escritura incluyen `read`.

**Presets** (lo que ofrece la web al crear un token):

| Preset | Scopes | Uso típico |
|--------|--------|------------|
| `observar` **(por defecto)** | `read` | Ver qué está pasando mientras vibecodeas, dashboards, bots de Slack |
| `agente` | `read`, `features:write`, `arguments:write`, `progress:write` | Un agente que se asigna features, las mueve y documenta lo que hace |
| `completo` | Todos salvo `ingest` | Integraciones que sincronizan el tablero con otra herramienta |
| personalizado | Los que se marquen | — |

### Ciclo de vida — `RF-API-001`, `RF-API-003` [F2] Aceptado

- **RF-API-001.** Cualquier miembro crea PATs para sí mismo desde la web, con sesión. Un PAT no puede crear otros tokens. Campos: nombre (obligatorio, p. ej. "Claude Code portátil"), preset o scopes, y caducidad.
- **RF-API-003.**
  - Caducidad por defecto: `hackathon.ends_at + 7 días`. Máximo: 90 días desde la creación. No hay tokens sin caducidad.
  - Máximo 10 PATs activos por miembro y equipo.
  - Revocación inmediata desde la web, por el dueño o por un owner del equipo. Un owner **ve y revoca** los tokens de otros, pero **no** los crea ni ve el valor.
  - Se revocan automáticamente todos los tokens de un miembro al salir o ser expulsado del equipo (RF-TEAM-008), al borrar su cuenta (RF-AUTH-007) y al borrar el equipo (RF-TEAM-009).
  - Se guarda `last_used_at` (con resolución de 1 min, para no escribir en cada petición).

### Introspección

`GET /api/v1/token` con cualquier Bearer devuelve `{kind, token_prefix, team: {id, name}, member: {id, display_name, role}, scopes, expires_at}`. Sirve para que un agente o una app sepa qué puede hacer antes de intentarlo.

---

## API REST — `RF-API-004` [F2] Aceptado

- Es la misma API de [03](03-api.md): mismas rutas, mismos formatos, mismos errores. **No hay una API "pública" aparte.**
- Con cualquier token, el equipo de la ruta (`/teams/:team_id/…`) tiene que ser el del token. Si no lo es, `404` (como con cualquier equipo ajeno, RNF-SEC-001).
- Las peticiones con Bearer no llevan cookie ni necesitan `X-CSRF-Token`. Si una petición trae a la vez cookie y Bearer, se rechaza con `400`.
- CORS sigue limitado a `APP_URL` (RNF-SEC-004): los tokens están pensados para usarse desde servidores, CLIs y agentes, no desde el navegador de otra web.
- Si falta el scope, `403` con `code: "insufficient_scope"` y `details: {required_scope: "features:write"}`.
- Cada endpoint de [03](03-api.md) declara en la OpenAPI el scope que necesita (`x-hackboard-scope`), o `session_only` si no admite tokens.

### Qué no se puede hacer con un token

Estos endpoints solo aceptan sesión web (responden `403 session_required` a un Bearer):

| Área | Endpoints |
|------|-----------|
| Cuenta | `/auth/*`, `PATCH /me`, `DELETE /me` |
| Administración del equipo | `POST /teams`, `POST /teams/join`, `PATCH /teams/:id`, `POST /teams/:id/code/rotate`, `DELETE /teams/:id` |
| Miembros | `PATCH` y `DELETE /teams/:id/members/:mid` |
| GitHub | Todo `/teams/:id/github/*` y `POST`/`DELETE /teams/:id/repositories` |
| Claude Code | `POST /teams/:id/cli/device/approve`, `PATCH /teams/:id/me/claude_code` |
| Tokens y conexiones | Todo `/teams/:id/tokens`, `/teams/:id/integrations`, `/teams/:id/webhooks` y `/me/oauth_connections`, y la decisión de consentimiento de OAuth |
| Borrados | `DELETE` de features, objetivos, milestones y argumentos |

`GET /me` sí admite Bearer y responde con los datos del dueño del token acotados a su equipo.

### Idempotencia — `RF-API-005` [F2] Aceptado

- Los `POST` admiten la cabecera `Idempotency-Key` (1–64 caracteres). La respuesta se guarda en Redis 24 h por `(token, clave)`. Repetir la petición devuelve la misma respuesta con `Idempotent-Replayed: true`.
- Reutilizar la clave con otro cuerpo responde `422 idempotency_key_reused`.
- Así un agente que reintenta tras un timeout no crea dos features.

### OpenAPI — `RF-API-007` [F2] Aceptado

- `GET /api/v1/openapi.json`, pública y sin auth, en OpenAPI 3.1.
- Se genera a partir de los request specs (rswag o equivalente) y la CI falla si la documentación y los tests no coinciden.
- Incluye, por endpoint, el scope necesario y si admite tokens. Enlazada desde Ajustes → API y MCP.

### Versionado — `RNF-API-003` [F2] Aceptado

- `v1` es estable: se pueden **añadir** campos, parámetros opcionales y endpoints. Los clientes deben ignorar campos que no conozcan.
- Un cambio incompatible va a `/api/v2`. `v1` se mantiene al menos 30 días después, con las cabeceras `Deprecation` y `Sunset`.
- Lo mismo aplica a los nombres y a los esquemas de entrada de las herramientas MCP.

---

## Servidor MCP

`RF-MCP-001` [F5] Aceptado.

- Transporte: **Streamable HTTP** en `POST /api/v1/mcp`. Acepta `hb_pat_`, `hb_mt_`, `hb_oat_` y `hb_it_`. No hay que instalar nada:
  ```
  claude mcp add --transport http hackboard https://<api>/api/v1/mcp --header "Authorization: Bearer hb_pat_…"
  ```
  La web muestra este comando listo para copiar (RF-MCP-010). Se recomienda el scope `local` o `user` de Claude Code; **nunca** `--scope project`, que escribe el token en `.mcp.json` dentro del repo.
- Sirve a cualquier cliente MCP, no solo a Claude Code.
- El nombre del cliente que envía el `initialize` (`clientInfo.name`, p. ej. `claude-code`) se guarda recortado a 40 caracteres en la trazabilidad. Es un dato informativo y no confiable.

### Herramientas de lectura — `RF-MCP-002` [F5] Aceptado

Scope `read`. Todas llevan la anotación `readOnlyHint: true`.

| Herramienta | Entrada | Salida |
|-------------|---------|--------|
| `whoami` | `{}` | Equipo, miembro, rol, tipo de token, scopes y caducidad |
| `get_team_status` | `{}` | **Foto del proyecto ahora:** tiempo hasta el fin del hackathon y hasta el siguiente milestone, features por estado, mis features en curso, features vencidas, % de cobertura del último análisis y sus alertas, y los 10 últimos eventos del feed |
| `list_features` | `{status?, mine?: bool, objective_key?, q?}` | `{key, title, status, assignees, deadline, score, last_activity_at}` |
| `get_feature` | `{key}` | Detalle: descripción, objetivos, asignados, pros y contras con votos, ramas vinculadas y los 10 últimos eventos atribuidos |
| `list_objectives` | `{}` | `{key, title, priority, feature_count, coverage?}` |
| `get_timeline` | `{}` | Milestones y features con deadline, con `overdue` |
| `list_activity` | `{since?, feature_key?, member?, source?, limit? (≤ 50)}` | Eventos del feed tal como los ve la web (mismas reglas de privacidad, RF-ACT-015) |
| `get_latest_analysis` | `{}` | Resumen del último análisis `succeeded`, matriz de cobertura resumida y alertas deterministas |
| `suggest_branch_name` | `{feature_key}` | `"f-12-login-con-github"` |

### Herramientas de escritura — `RF-MCP-003` [F5] Aceptado

Cada una exige su scope. Todas llevan `readOnlyHint: false` y `destructiveHint: false` (no hay herramientas destructivas). Usan los mismos servicios de dominio que la API REST, con las mismas validaciones.

| Herramienta | Scope | Entrada | Efecto |
|-------------|-------|---------|--------|
| `report_progress` | `progress:write` | `{feature_key, summary (≤ 500), status_hint?: "started"\|"blocked"\|"ready_for_review"}` | Crea `ActivityEvent{source: mcp, kind: progress_report}` con atribución `convention/confirmed`. **No cambia** el estado: `status_hint` es solo una sugerencia visible |
| `create_feature` | `features:write` | `{title, description?, objective_keys?, deadline?, assign_to_me?: bool, idempotency_key?}` | Crea la feature en `idea` y devuelve su clave |
| `update_feature` | `features:write` | `{key, title?, description?, deadline?, objective_keys?, expected_updated_at?}` | Edita. Si `expected_updated_at` no coincide, devuelve el conflicto con el documento actual (como `If-Match`) |
| `move_feature` | `features:write` | `{key, status, discarded_reason?}` | Cambia el estado (va al final de la columna) |
| `assign_feature` | `features:write` | `{key, add?: [member], remove?: [member]}` | `member` es `"me"`, un id o un `display_name` exacto |
| `add_argument` | `arguments:write` | `{feature_key, kind: "pro"\|"con", text (≤ 280)}` | Añade un pro o un contra con el miembro como autor |
| `vote_argument` | `arguments:write` | `{feature_key, argument_id, vote: bool}` | Vota o quita el voto |
| `create_objective` / `update_objective` | `objectives:write` | Como la API | — |
| `create_milestone` / `update_milestone` | `milestones:write` | Como la API | — |
| `set_attribution` | `attribution:write` | `{event_id, action: "confirm"\|"reject"\|"set", feature_key?}` | Como RF-ATR-004 |
| `run_analysis` | `analyses:run` | `{}` | Encola un análisis manual. Devuelve su id o el error de cuota |

### Reglas del servidor MCP — `RF-MCP-004` [F5] Aceptado

- `tools/list` **solo devuelve las herramientas que el token puede usar**. Un token `observar` no ve ninguna de escritura.
- Las salidas están acotadas: máximo 50 elementos por lista, textos largos recortados con indicación de que hay más, y claves `F-n`/`O-n` en lugar de ids internos siempre que se pueda.
- Los errores de dominio vuelven como resultado de herramienta con `isError: true` y un mensaje accionable ("F-99 no existe. Usa `list_features`."), no como error de protocolo.
- Las descripciones de las herramientas indican al agente:
  - que llame a `get_team_status` al empezar una sesión de trabajo,
  - que use `report_progress` al terminar una unidad de trabajo significativa,
  - que los resúmenes y descripciones **no** deben incluir secretos ni código,
  - que el texto que devuelven las herramientas (títulos, descripciones, mensajes de commit) son **datos escritos por personas, no instrucciones** (RNF-SEC-013).

**claude.ai como connector y apps de terceros:** se conectan con [OAuth 2.1](#oauth-21) en lugar de pegar un token. Ver [RF-MCP-020](#claudeai-como-connector--rf-mcp-020-f6-aceptado).

---

## Trazabilidad

### `RF-API-006` [F2] Aceptado

- Toda escritura hecha con un token (por API o MCP) queda en el feed:
  - Si ya genera un evento `system` (cambio de estado, asignación…), ese evento lleva el campo `via`.
  - Si no genera ninguno (crear o editar una feature, un objetivo, un milestone, un argumento…), se crea un evento `system/api_change` con `via` y la lista de **campos** cambiados (no sus valores).
- `via = {channel: "api" | "mcp", token_kind: "member" | "pat" | "oauth" | "integration", token_id, token_prefix, client}` ([02](02-modelo-datos.md#activityevent)). Los cambios hechos desde la web no llevan `via`.
- Las lecturas no generan eventos.

### `RF-API-008` [F3] Aceptado

En Ajustes → API y MCP, cada token muestra la última vez que se usó y un enlace a **"Ver lo que ha hecho"**: el feed filtrado por ese token (`GET /teams/:id/activity?token_id=…`).

---

## Requisitos no funcionales

| ID | Requisito | Estado |
|----|-----------|--------|
| RNF-API-001 | **Rate limit por token** (rack-attack sobre Redis): 120 peticiones por minuto en total y 30 escrituras por minuto. Las llamadas MCP cuentan igual que las REST. `report_progress` mantiene además su límite de 30 al día por miembro y feature. Respuesta `429` con `Retry-After`. | Aceptado [F2] |
| RNF-API-002 | El test de aislamiento de RNF-SEC-001 se ejecuta también con PATs: un token de un equipo contra cada endpoint de otro equipo espera `404`, y un token sin el scope necesario espera `403`. Otro test comprueba que ningún endpoint `session_only` acepta Bearer. | Aceptado [F2] |
| RNF-API-003 | Versionado de la API y de las herramientas MCP ([arriba](#versionado--rnf-api-003-f2-aceptado)). | Aceptado [F2] |
| RNF-API-004 | Los tests de RNF-API-002 cubren también los tokens OAuth y de integración. Hay tests del flujo OAuth completo: PKCE incorrecto, `redirect_uri` distinto, `resource` ajeno, código reutilizado y refresh token reutilizado (que debe revocar la conexión). | Aceptado [F6] |
| RNF-MCP-001 | Las herramientas de lectura responden en < 500 ms (p95) con 100 features y 500 eventos por equipo. | Aceptado [F5] |

---

## OAuth 2.1

`RF-API-010` [F6] Aceptado. Ver [ADR-0011](decisiones.md#adr-0011).

Sirve para que **claude.ai** y **apps de terceros** obtengan acceso sin que nadie copie un token: la app redirige a Hackboard, el usuario inicia sesión, elige equipo y permisos, y la app recibe un token.

### Quién hace qué

- **Hackboard es el servidor de autorización** y el servidor de recursos. Emite sus propios tokens, con los scopes de [arriba](#scopes--rf-api-002-f2-aceptado) y ligados a un miembro y a un equipo.
- **Google y GitHub son solo proveedores de identidad.** En la pantalla de consentimiento el usuario se identifica con Google (RF-AUTH-008), con GitHub (RF-AUTH-004) o con email y contraseña. Los tokens de Google o GitHub **nunca** se aceptan en la API ni se reenvían a terceros.

### Endpoints

Todos en el host de la api. `issuer = API_URL`.

| Método | Ruta | Descripción | Norma |
|--------|------|-------------|-------|
| GET | `/.well-known/oauth-protected-resource/api/v1/mcp` (y `/api/v1`) | Metadatos del recurso protegido: `resource`, `authorization_servers`, `scopes_supported` | RFC 9728 |
| GET | `/.well-known/oauth-authorization-server` | Metadatos del servidor de autorización | RFC 8414 |
| GET | `/oauth/authorize` | Valida la petición y redirige a la pantalla de consentimiento de la web (`APP_URL/oauth/consent`, RF-API-022). Si no hay sesión, pasa antes por el login | OAuth 2.1 |
| POST | `/oauth/authorize/decision` | La web (con sesión y CSRF) envía `{request_id, approve, team_id, scopes[]}`. Crea el código y redirige al `redirect_uri` | — |
| POST | `/oauth/token` | `authorization_code` (con `code_verifier`) y `refresh_token` | OAuth 2.1 |
| POST | `/oauth/register` | Registro dinámico de clientes | RFC 7591 |
| POST | `/oauth/revoke` | Revocación de tokens | RFC 7009 |

Cuando falta el token o no es válido, la API y el MCP responden `401` con `WWW-Authenticate: Bearer resource_metadata="<url de metadatos>", scope="read"`, que es lo que usan los clientes MCP para descubrir cómo autenticarse.

> Al implementarlo hay que verificar el flujo contra la versión vigente de la especificación de autorización de MCP (descubrimiento, registro de clientes, *Client ID Metadata Documents*, parámetro `resource`) y actualizar esta sección si ha cambiado.

### Reglas — `RF-API-012` [F6] Aceptado

- Solo el flujo **authorization code con PKCE `S256`**, que es obligatorio. No existen el flujo implícito ni *password grant*.
- **Clientes:** se pueden registrar por registro dinámico (RFC 7591) o con un *Client ID Metadata Document* (el `client_id` es una URL HTTPS que publica los metadatos del cliente). Todos son clientes públicos sin secreto, salvo los que registra el equipo de Hackboard a mano (`first_party`).
- `redirect_uri` tiene que coincidir **exactamente** con uno de los registrados. Solo HTTPS, o `http://127.0.0.1`/`localhost` con cualquier puerto para apps nativas.
- **Audiencia:** el parámetro `resource` (RFC 8707) es obligatorio y tiene que ser `API_URL/api/v1` o `API_URL/api/v1/mcp`. El token solo vale para ese recurso.
- **Un token OAuth = un miembro en un equipo.** Si el usuario pertenece a varios equipos, elige uno en el consentimiento. Para dar acceso a otro equipo hay que autorizar otra vez.
- **Scopes:** los que pida el cliente, que el usuario puede reducir en el consentimiento. Si el cliente no pide ninguno, se propone el preset `observar`. `ingest` nunca se concede por OAuth.
- **Vida de los tokens:** access token `hb_oat_` de 1 h. Refresh token `hb_ort_` de 30 días, **rotado en cada uso**. Si se reutiliza un refresh token ya usado, se revoca toda la conexión (detección de robo). La conexión caduca a los 90 días como máximo y hay que volver a autorizarla.
- La conexión se revoca, con todos sus tokens, cuando el usuario la quita en "Apps conectadas" (RF-API-021), cuando un owner la revoca, y en los mismos casos que un PAT (salir del equipo, borrar la cuenta, borrar el equipo).
- Los cambios hechos con OAuth llevan `via.client` = nombre del cliente registrado, marcado como "no verificado" si viene de registro dinámico.
- Rate limit: `/oauth/register`, 10 registros por hora e IP. `/oauth/token`, 30 peticiones por minuto por cliente. Con un token OAuth se aplican los mismos límites que con un PAT (RNF-API-001).

### claude.ai como connector — `RF-MCP-020` [F6] Aceptado

- En claude.ai (Settings → Connectors → *Add custom connector*) se pega la URL `https://<api>/api/v1/mcp`. claude.ai descubre los metadatos, se registra como cliente y abre la pantalla de consentimiento de Hackboard.
- El usuario entra con Google, GitHub o contraseña, elige el equipo y el preset (`observar` por defecto, o `agente`) y aprueba. Desde ese momento puede preguntar a Claude en el chat "¿cómo va el equipo?", "¿qué me toca?", o pedirle que cree o mueva features, según el preset.
- **No se leen conversaciones de claude.ai.** Lo único que llega a Hackboard son las llamadas a herramientas que hace Claude. Lo que Claude escribe con `report_progress` se guarda como cualquier otro `progress_report` (≤ 500 caracteres).
- Lo mismo sirve para cualquier otro cliente MCP remoto que implemente la especificación de autorización de MCP.
- La web muestra la URL lista para copiar y los pasos (RF-MCP-011).

---

## Tokens de integración de equipo

`RF-API-011` [F6] Aceptado.

Para bots e integraciones que pertenecen al **equipo**, no a una persona: un bot de Slack que publica el estado, un workflow de n8n, un GitHub Action que mueve una feature a `done` al mergear…

- Los crea, revoca y rota **solo un owner**, desde la web (RF-API-023). Prefijo `hb_it_`.
- Tienen nombre ("Bot de Slack"), scopes y caducidad (máximo 90 días, por defecto `hackathon.ends_at + 7 días`).
- **El actor es la integración**, no una persona: en el feed aparece "Bot de Slack (integración)" y `actor.integration_id` apunta al token.
- Permisos: como un miembro con rol `member`, nunca como owner. No pueden usar `progress:write` (el progreso es de una persona), `ingest`, ni el filtro `mine`.
- Siguen activos aunque el owner que los creó salga del equipo. Se muestra quién los creó.
- Máximo 10 activos por equipo.

---

## Webhooks salientes

`RF-API-009` [F6] Aceptado.

Hackboard avisa a otras apps cuando pasa algo, para que no tengan que hacer polling.

- Los configura **un owner** (RF-API-023): URL HTTPS, eventos suscritos y activo o pausado. Máximo 5 por equipo.
- **Eventos:**

| Evento | Cuándo |
|--------|--------|
| `feature.created`, `feature.updated`, `feature.status_changed`, `feature.assigned` | Cambios en features |
| `objective.created`, `objective.updated` | Cambios en objetivos |
| `milestone.created`, `milestone.updated`, `milestone.due_soon` | Cambios en milestones y aviso 1 h antes de `due_at` |
| `activity.created` | Evento nuevo en el feed de fuente `github` o `system` |
| `analysis.succeeded` | Análisis de IA terminado, con el resumen y las alertas |
| `ping` | Al crear el webhook y con el botón "Probar" |

- **Privacidad:** los eventos de fuente `claude_code` y `mcp` **no se envían nunca** por webhook. Son opt-in por persona (principio 1 de [09](09-privacidad-seguridad.md#principios)) y un owner no puede decidir sacarlos a un tercero.
- **Cuerpo:** `{id, event, occurred_at, team: {id, name}, data}`, donde `data` es la misma representación que devuelve la API REST para ese recurso.
- **Firma:** cabeceras `X-Hackboard-Event`, `X-Hackboard-Delivery` (id único), `X-Hackboard-Timestamp` y `X-Hackboard-Signature-256: sha256=<HMAC(secreto, timestamp + "." + cuerpo)>`. El receptor debe rechazar lo que tenga más de 5 min. El secreto se muestra una vez al crearlo y se puede rotar.
- **Entrega:** `Webhooks::DeliverJob` en la cola `outbound`. Timeout de 5 s, sin seguir redirecciones. Cualquier respuesta `2xx` es un éxito. Reintentos con backoff durante 24 h como máximo. Después de 50 fallos seguidos, el webhook se pausa y se avisa a los owners en la web.
- **Registro:** las últimas entregas (estado, código HTTP y duración, sin el cuerpo de la respuesta) se ven en la web, con un botón para reenviar.
- **Protección SSRF** (RNF-SEC-016): se resuelve el DNS en el momento del envío y se rechazan las IPs privadas, de loopback, link-local y de metadatos de nube.
