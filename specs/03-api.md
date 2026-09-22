# 03 · API

> **Estado de implementación:** En proceso (auth, equipos, objetivos, features, pros y contras, milestones, actividad, análisis IA y GitHub implementados; faltan los endpoints de Claude Code y acceso programático) · **Última actualización:** 2026-09-22

## Convenciones generales

- Base: `/api/v1`. Todo es JSON (`application/json`). Los nombres van en `snake_case`.
- **Autenticación de la web:** cookie `hb_session` (httpOnly, Secure, SameSite=Lax) que contiene un token opaco ([02 · Session](02-modelo-datos.md#session)). Las peticiones que cambian estado exigen la cabecera `X-CSRF-Token`, que se obtiene de `GET /api/v1/csrf`.
- **Autenticación del CLI:** `Authorization: Bearer hb_mt_<token>` (token de miembro).
- **Autenticación de apps externas, agentes y MCP:** `Authorization: Bearer <token>` con un token de acceso personal (`hb_pat_`), un access token de OAuth (`hb_oat_`), un token de integración (`hb_it_`) o el token de miembro con sus scopes fijos. Las reglas (scopes, endpoints excluidos, idempotencia, trazabilidad) están en [12 · Acceso programático](12-acceso-programatico.md). Las peticiones con Bearer no usan CSRF.
- **Autenticación de GitHub:** firma HMAC `X-Hub-Signature-256`.
- **Contexto de equipo:** las rutas del dominio van anidadas en `/teams/:team_id/…`. El servidor comprueba que el usuario es miembro. Si no lo es, responde `404`, no `403`, para no revelar que el equipo existe.
- **Paginación:** por cursor. `?limit=50&cursor=<opaco>`. La respuesta trae `{ data: [...], next_cursor: "…" | null }`.
- **Fechas:** ISO 8601 en UTC.
- **Idempotencia:** los `POST` admiten `Idempotency-Key` ([RF-API-005](12-acceso-programatico.md#idempotencia--rf-api-005-f2-aceptado)).
- **Concurrencia:** las actualizaciones de `Feature` y `Objective` aceptan `If-Match: <updated_at>`. Si no coincide, se responde `409` con el documento actual (así se evita que dos personas arrastrando tarjetas a la vez se pisen).

### Formato de error

```json
{ "error": { "code": "validation_failed", "message": "Título obligatorio", "details": { "title": ["can't be blank"] } } }
```

| HTTP | `code` |
|------|--------|
| 400 | `bad_request` |
| 401 | `unauthenticated` |
| 403 | `forbidden` (el rol no basta, dentro de un equipo del que eres miembro), `insufficient_scope` (al token le falta el scope; `details.required_scope`) o `session_required` (el endpoint no admite tokens) |
| 404 | `not_found` |
| 409 | `conflict` |
| 422 | `validation_failed`, `idempotency_key_reused` |
| 429 | `rate_limited` (con cabecera `Retry-After`) |
| 500 | `internal_error` |

## Autenticación — `RF-AUTH`

| Método | Ruta | Descripción | Req |
|--------|------|-------------|-----|
| POST | `/auth/signup` | `{email, name, password}` → crea el usuario y la sesión | RF-AUTH-001 [F1] |
| POST | `/auth/login` | `{email, password}` → sesión | RF-AUTH-002 [F1] |
| POST | `/auth/logout` | Invalida la sesión actual | RF-AUTH-003 [F1] |
| GET | `/auth/github` | Redirige al OAuth de usuario de la GitHub App (`state` firmado) | RF-AUTH-004 [F1] |
| GET | `/auth/github/callback` | Crea o vincula el usuario por `github_uid` y, si no, por email verificado. Abre sesión | RF-AUTH-004 |
| GET | `/auth/google` | Redirige al login de Google (OpenID Connect, scopes `openid email profile`, `state` y `nonce` firmados, PKCE) | RF-AUTH-008 [F1] |
| GET | `/auth/google/callback` | Valida el ID token (firma, `iss`, `aud`, `nonce`, `exp`) y exige `email_verified`. Crea o vincula el usuario por `google_sub` y, si no, por email verificado. Abre sesión | RF-AUTH-008 |
| DELETE | `/me/identities/:provider` | Desvincula Google o GitHub. Falla si es la única forma de entrar (sin contraseña ni otro proveedor) | RF-AUTH-009 [F2] |
| GET | `/me` | Usuario, membresías (equipo y rol) y `last_team_id` | RF-AUTH-005 [F1] |
| PATCH | `/me` | `name`, `password` | RF-AUTH-006 [F1] |
| DELETE | `/me` | Borra la cuenta. Falla si el usuario es el único owner de un equipo con más miembros | RF-AUTH-007 [F2] |

Reglas:
- La contraseña tiene un mínimo de 10 caracteres.
- El login tiene rate limit: 10 intentos cada 15 min por IP y por email.
- [ABIERTO] Recuperación de contraseña por email. Necesita un proveedor de email; en el MVP el login con GitHub o con Google es la alternativa.

## Equipos — `RF-TEAM`

| Método | Ruta | Rol | Descripción | Req |
|--------|------|-----|-------------|-----|
| POST | `/teams` | usuario | `{name, hackathon:{name, starts_at, ends_at, timezone}}` → equipo con el usuario como owner | RF-TEAM-001 [F1] |
| POST | `/teams/join` | usuario | `{code}` → membresía `member`. Si ya era miembro, idempotente | RF-TEAM-002 [F1] |
| GET | `/teams/:id` | miembro | Equipo, hackathon, ajustes (sin secretos) | RF-TEAM-003 [F1] |
| PATCH | `/teams/:id` | owner | Nombre, hackathon, `challenge_text`, ajustes | RF-TEAM-004 [F1] |
| POST | `/teams/:id/code/rotate` | owner | Regenera el código. El anterior deja de servir | RF-TEAM-005 [F1] |
| GET | `/teams/:id/members` | miembro | Lista con rol y estado de Claude Code (conectado, pausado, nivel) | RF-TEAM-006 [F1] |
| PATCH | `/teams/:id/members/:mid` | owner | `role`. También `display_name` y `git_identities` (el propio miembro puede cambiar los suyos) | RF-TEAM-007 [F2] |
| DELETE | `/teams/:id/members/:mid` | owner o el propio miembro | Expulsar o salir. Revoca el token de Claude Code | RF-TEAM-008 [F1] |
| DELETE | `/teams/:id` | owner | Borrado lógico. Confirmación escribiendo el nombre del equipo | RF-TEAM-009 [F2] |

Rate limit en `/teams/join`: 20 intentos por hora por usuario, para que no se puedan enumerar códigos.

## Objetivos — `RF-OBJ`

| Método | Ruta | Descripción | Req |
|--------|------|-------------|-----|
| GET | `/teams/:id/objectives` | Lista ordenada por `position`. Cada objetivo incluye `feature_count` por estado | RF-OBJ-001 [F1] |
| POST | `/teams/:id/objectives` | `{title, description?, priority}` | RF-OBJ-002 [F1] |
| PATCH | `/teams/:id/objectives/:oid` | Campos editables, `position`, `archived` | RF-OBJ-003 [F1] |
| DELETE | `/teams/:id/objectives/:oid` | Borrado físico. Quita el id de `feature.objective_ids` | RF-OBJ-004 [F1] |
| POST | `/teams/:id/objectives/import` | `{text}`: pega el texto del reto y la IA propone una lista de objetivos (que no se guarda sin confirmar) | RF-OBJ-005 [F4] |

## Features — `RF-FEAT`

| Método | Ruta | Descripción | Req |
|--------|------|-------------|-----|
| GET | `/teams/:id/features` | Filtros: `status`, `assignee_id`, `objective_id`, `q`. Incluye `score` y `last_activity_at` | RF-FEAT-001 [F1] |
| GET | `/teams/:id/features/:key` | Por clave (`F-12`) o id. Detalle con argumentos | RF-FEAT-002 [F1] |
| POST | `/teams/:id/features` | `{title, description?, status?, objective_ids?, assignee_ids?, deadline?}`. Asigna `number` de forma atómica | RF-FEAT-003 [F1] |
| PATCH | `/teams/:id/features/:key` | Campos editables. Los cambios de `status` y `assignee_ids` generan eventos `system` | RF-FEAT-004 [F1] |
| POST | `/teams/:id/features/:key/move` | `{status, before_id?, after_id?}`: mueve la tarjeta en el kanban (calcula `position`) | RF-FEAT-005 [F1] |
| DELETE | `/teams/:id/features/:key` | Solo si no tiene eventos atribuidos. Si los tiene, hay que usar `discarded` | RF-FEAT-006 [F1] |

## Pros y contras — `RF-PC`

| Método | Ruta | Descripción | Req |
|--------|------|-------------|-----|
| POST | `/teams/:id/features/:key/arguments` | `{kind, text}` | RF-PC-001 [F2] |
| PATCH | `/teams/:id/features/:key/arguments/:aid` | Solo el autor: `text` | RF-PC-002 [F2] |
| DELETE | `/teams/:id/features/:key/arguments/:aid` | El autor o un owner | RF-PC-003 [F2] |
| PUT / DELETE | `/teams/:id/features/:key/arguments/:aid/vote` | Vota o quita el voto (idempotente, con `$addToSet`/`$pull`) | RF-PC-004 [F2] |

## Milestones — `RF-DL`

| Método | Ruta | Descripción | Req |
|--------|------|-------------|-----|
| GET | `/teams/:id/milestones` | Ordenados por `due_at` | RF-DL-001 [F2] |
| POST / PATCH / DELETE | `/teams/:id/milestones[/:mid]` | CRUD. Cualquier miembro | RF-DL-002 [F2] |
| GET | `/teams/:id/timeline` | Milestones + features con `deadline`, cada una con `overdue: bool` | RF-DL-003 [F2] |

## Actividad — `RF-ACT`

| Método | Ruta | Descripción | Req |
|--------|------|-------------|-----|
| GET | `/teams/:id/activity` | Filtros: `user_id`, `feature_id`, `source`, `kind`, `attribution_status` (`confirmed`\|`suggested`\|`none`), `via` (`web`\|`api`\|`mcp`), `token_id`, `since`, `until`. Paginado | RF-ACT-001 [F3] |
| GET | `/teams/:id/activity/summary` | Recuento por persona y por feature en una ventana (`?window=24h`) | RF-ACT-002 [F3] |
| POST | `/teams/:id/activity/:eid/attribution` | `{action: "confirm" \| "reject" \| "set", feature_id?}` | RF-ATR-004 [F3] |
| POST | `/teams/:id/activity/attribution/bulk` | `{event_ids[], action, feature_id?}` (máx. 100) | RF-ATR-005 [F4] |

## Análisis IA — `RF-AI`

| Método | Ruta | Descripción | Req |
|--------|------|-------------|-----|
| GET | `/teams/:id/analyses` | Historial (sin `result` completo) | RF-AI-001 [F4] |
| GET | `/teams/:id/analyses/latest` | El último `succeeded` + alertas deterministas calculadas ahora | RF-AI-002 [F4] |
| GET | `/teams/:id/analyses/:aid` | Detalle | RF-AI-003 [F4] |
| POST | `/teams/:id/analyses` | Lanza un análisis manual. `429` si se supera la cuota ([06](06-analisis-ia.md#cuotas)) | RF-AI-004 [F4] |

## Integración GitHub — `RF-GH`

| Método | Ruta | Descripción | Req |
|--------|------|-------------|-----|
| GET | `/teams/:id/github/install_url` | URL de instalación de la App con `state` firmado (team_id, user_id, exp) | RF-GH-001 [F3] |
| GET | `/github/setup` | Setup URL de la App: recibe `installation_id` y `state`, vincula la instalación al equipo y redirige a la web | RF-GH-002 [F3] |
| GET | `/teams/:id/github/available_repos` | Repos accesibles por las instalaciones del equipo | RF-GH-003 [F3] |
| GET | `/teams/:id/repositories` | Repos vinculados y activos del equipo, para la sección GitHub de ajustes (RF-GH-010) | RF-GH-004 [F3] |
| POST | `/teams/:id/repositories` | `{full_name}` o `{url}`. Pegar el repo: si la App ya tiene acceso, lo vincula; si no, responde `needs_install` con la URL | RF-GH-004 [F3] |
| DELETE | `/teams/:id/repositories/:rid` | Desvincula el repo (no borra los eventos) | RF-GH-005 [F3] |
| POST | `/teams/:id/repositories/:rid/resync` | "Resincronizar": relanza la importación del histórico reciente | RNF-GH-003 [F3] |
| POST | `/webhooks/github` | Receptor de webhooks ([07](07-integracion-github.md)) | RF-GH-006 [F3] |

## Claude Code — `RF-CC`

| Método | Ruta | Auth | Descripción | Req |
|--------|------|------|-------------|-----|
| POST | `/cli/device` | ninguna | Inicia el device flow: `{team_code?}` → `{device_code, user_code, verification_url, interval, expires_in}` | RF-CC-001 [F5] |
| POST | `/cli/device/token` | ninguna | Polling con `device_code`. Tras aprobar → `{token, team, member, privacy_level, repositories}` | RF-CC-001 |
| POST | `/teams/:id/cli/device/approve` | sesión web | El usuario aprueba el `user_code` y elige el nivel de privacidad | RF-CC-002 [F5] |
| GET | `/cli/config` | token de miembro | Repos vinculados (`remote_urls`), nivel de privacidad, `paused`, reglas de exclusión | RF-CC-003 [F5] |
| POST | `/ingest/claude_code` | token de miembro | Lote de eventos ([08](08-integracion-claude-code.md#contrato-de-ingesta)). `202` | RF-CC-004 [F5] |
| PATCH | `/teams/:id/me/claude_code` | sesión web | `privacy_level`, `paused` | RF-CC-005 [F5] |
| DELETE | `/teams/:id/me/claude_code` | sesión web o token | Desconecta y revoca el token. `?purge=true` borra además los eventos `claude_code` y `mcp` del miembro | RF-CC-006 [F5] |
| POST | `/mcp` | PAT o token de miembro | Endpoint MCP (Streamable HTTP). Herramientas en [12](12-acceso-programatico.md#servidor-mcp) | RF-MCP-001 [F5] |

Rate limit de la ingesta: 120 peticiones por minuto por token y 200 eventos por petición.

## Acceso programático — `RF-API`

Detalle en [12 · Acceso programático](12-acceso-programatico.md).

| Método | Ruta | Auth | Descripción | Req |
|--------|------|------|-------------|-----|
| GET | `/teams/:id/tokens` | sesión web | Mis PATs (prefijo, nombre, scopes, caducidad, `last_used_at`). Un owner puede pedir `?all=true` para ver los de todo el equipo | RF-API-001 [F2] |
| POST | `/teams/:id/tokens` | sesión web | `{name, preset? \| scopes?, expires_at?}` → el token en claro, **una sola vez** | RF-API-001 [F2] |
| DELETE | `/teams/:id/tokens/:tid` | sesión web | Revoca. El dueño o un owner | RF-API-003 [F2] |
| GET | `/token` | PAT o token de miembro | Introspección: equipo, miembro, rol, scopes y caducidad | RF-API-004 [F2] |
| GET | `/openapi.json` | ninguna | Especificación OpenAPI 3.1 con el scope de cada endpoint | RF-API-007 [F2] |

| GET / DELETE | `/me/oauth_connections[/:cid]` | sesión web | Apps conectadas por OAuth (cliente, equipo, scopes, último uso) y revocación | RF-API-021 [F6] |
| GET / POST / DELETE | `/teams/:id/integrations[/:iid]` | sesión web, owner | Tokens de integración. `POST .../:iid/rotate` rota el token | RF-API-011 [F6] |
| GET / POST / PATCH / DELETE | `/teams/:id/webhooks[/:wid]` | sesión web, owner | Webhooks salientes. `POST .../:wid/test` envía un `ping`, `POST .../:wid/rotate_secret` rota el secreto | RF-API-009 [F6] |
| GET | `/teams/:id/webhooks/:wid/deliveries` | sesión web, owner | Últimas entregas. `POST .../deliveries/:did/redeliver` reenvía | RF-API-009 |

Los endpoints de OAuth 2.1 (`/.well-known/*`, `/oauth/*`) están fuera de `/api/v1` y se detallan en [12](12-acceso-programatico.md#oauth-21).

Rate limit con token: 120 peticiones por minuto y 30 escrituras por minuto (RNF-API-001).
