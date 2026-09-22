# 02 · Modelo de datos (Mongoid)

> **Estado de implementación:** Implementada · **Última actualización:** 2026-09-22

## Convenciones

- Todos los documentos incluyen `Mongoid::Timestamps` (`created_at`, `updated_at`).
- Los ids son `BSON::ObjectId`. En la API se exponen como string.
- **Multi-tenant:** cualquier documento que no sea `User` o `Session` lleva `team_id` indexado, y todas las consultas se acotan por equipo.
- Las fechas se guardan en UTC. La zona horaria para mostrarlas es `team.hackathon.timezone`.
- Las claves legibles (`F-12`, `O-3`) se generan con un contador atómico en `Team` (`find_one_and_update` con `$inc`). Nunca se reutilizan, aunque se borre el documento.
- Relaciones: se usa `belongs_to`/`has_many` por referencia. Solo se embebe lo que no tiene vida propia fuera de su padre: argumentos de pros y contras, datos del hackathon y la atribución de un evento.

## Diagrama

```
User 1──* Membership *──1 Team 1──* Repository
              1                    1
              └──* AccessToken ────┘ (kind: pat | oauth | integration)
                                   Team 1──* OutboundWebhook 1──* OutboundDelivery
 OAuthClient 1──* AccessToken (kind: oauth) · OAuthClient 1──* OAuthGrant
                           │
          ┌────────┬───────┼──────────┬─────────────┬────────────┐
          *        *       *          *             *            *
     Objective  Feature  Milestone ActivityEvent AiAnalysis  WebhookDelivery
          ▲        │ ▲ (embebe Argument[])  │
          └────────┘ └── attribution.feature_id
       objective_ids
```

---

## User

| Campo | Tipo | Notas |
|-------|------|-------|
| `email` | String | Obligatorio, único, se guarda en minúsculas |
| `name` | String | Obligatorio, 1–80 caracteres |
| `password_digest` | String | Opcional si hay login con GitHub o Google (`ActiveModel::SecurePassword`) |
| `github_uid` | Integer | Único y disperso (`sparse`). Id numérico de GitHub |
| `github_login` | String | Se actualiza en cada login con GitHub |
| `google_sub` | String | Único y disperso. `sub` del ID token de Google |
| `avatar_url` | String | |
| `last_team_id` | ObjectId | Último equipo abierto, para redirigir tras el login |

Índices: `{email: 1}` único, `{github_uid: 1}` único y disperso.

## Session

Sesiones web con cookie opaca.

| Campo | Tipo | Notas |
|-------|------|-------|
| `user_id` | ObjectId | |
| `token_digest` | String | SHA-256 del token. El token en claro solo vive en la cookie |
| `expires_at` | Time | 30 días. Se renueva deslizando con el uso |
| `user_agent`, `ip` | String | Para auditar |

Índices: `{token_digest: 1}` único, `{expires_at: 1}` TTL.

## Team

| Campo | Tipo | Notas |
|-------|------|-------|
| `name` | String | 1–60 caracteres |
| `code` | String | Único, 8 caracteres del alfabeto `23456789ABCDEFGHJKMNPQRSTVWXYZ` y se muestra como `XXXX-XXXX`. El owner puede regenerarlo |
| `hackathon` | embebido `Hackathon` | Ver abajo |
| `feature_seq` | Integer | Contador para `F-n`. Empieza en 0 |
| `objective_seq` | Integer | Contador para `O-n` |
| `plan` | String | `free` \| `pro` |
| `settings` | Hash | `ai_enabled` (bool, true), `ai_attribution_enabled` (bool, true), `analysis_interval_min` (int, según el plan), `claude_code_enabled` (bool, true) |
| `github_installation_ids` | Array<Integer> | Instalaciones de la GitHub App vinculadas |
| `deleted_at` | Time | Borrado lógico. El borrado físico lo hace el job de retención |

**Hackathon** (embebido): `name`, `starts_at`, `ends_at`, `timezone` (IANA, p. ej. `Europe/Madrid`), `url` (opcional), `challenge_text` (texto del reto, opcional, máx. 10.000 caracteres; se usa en el análisis).

Índices: `{code: 1}` único.

## Membership

| Campo | Tipo | Notas |
|-------|------|-------|
| `user_id`, `team_id` | ObjectId | Pareja única |
| `role` | String | `owner` \| `member` |
| `display_name` | String | Por defecto, `user.name` |
| `git_identities` | Array<String> | Emails y logins de git extra para mapear autores de commits ([07](07-integracion-github.md)) |
| `claude_code` | embebido `ClaudeCodeLink` | `nil` si no está conectado |

**ClaudeCodeLink** (embebido):

| Campo | Tipo | Notas |
|-------|------|-------|
| `token_digest` | String | SHA-256 del token de miembro |
| `token_prefix` | String | Los primeros 8 caracteres, para mostrarlos (`hb_mt_ab12…`) |
| `privacy_level` | String | `metadata` (por defecto) \| `summaries` \| `off`. Ver [09](09-privacidad-seguridad.md) |
| `connected_at`, `last_event_at` | Time | |
| `paused` | Boolean | Pausado desde el CLI o desde la web |
| `cli_version` | String | |

Índices: `{team_id: 1, user_id: 1}` único y `{"claude_code.token_digest": 1}` único y disperso.

Invariante: todo equipo tiene al menos un `owner`. No se puede degradar ni eliminar al último.

## AccessToken

Tokens para la API y el MCP ([12](12-acceso-programatico.md#tokens)): de acceso personal, de OAuth y de integración. El token de miembro del CLI sigue en `Membership.claude_code`.

| Campo | Tipo | Notas |
|-------|------|-------|
| `kind` | String | `pat` \| `oauth` \| `integration` |
| `team_id` | ObjectId | El token solo sirve en ese equipo |
| `membership_id`, `user_id` | ObjectId | El dueño. `nil` en `integration` |
| `created_by_id` | ObjectId | Quién lo creó (en `integration`, el owner) |
| `oauth_client_id` | ObjectId | Solo en `oauth` |
| `refresh_token_digest` | String | Solo en `oauth`. Cambia en cada rotación |
| `refresh_family_id` | String | Solo en `oauth`. Si se reutiliza un refresh ya rotado, se revoca toda la familia |
| `resource` | String | Solo en `oauth`. Audiencia (RFC 8707) |
| `name` | String | 1–60 caracteres. En `oauth`, el nombre del cliente |
| `token_digest` | String | SHA-256 del token. El token en claro se muestra una sola vez |
| `token_prefix` | String | Los primeros 12 caracteres, para mostrarlos (`hb_pat_ab12…`). En `oauth` el access token cambia cada hora; el digest es el del access token vigente |
| `scopes` | Array<String> | Ver [12](12-acceso-programatico.md#scopes--rf-api-002-f2-aceptado). Nunca incluye `ingest` |
| `expires_at` | Time | Obligatorio. Máx. 90 días desde la creación. En `oauth` es la caducidad de la conexión; el access token caduca en `access_expires_at` (1 h) |
| `last_used_at` | Time | Resolución de 1 min |
| `revoked_at`, `revoked_by_id` | Time, ObjectId | Revocado por el dueño, por un owner o por el sistema |
| `revoke_reason` | String | `manual` \| `member_left` \| `account_deleted` \| `team_deleted` \| `refresh_reuse` |

Índices: `{token_digest: 1}` único, `{team_id: 1, membership_id: 1, revoked_at: 1}`.

Índices adicionales: `{refresh_token_digest: 1}` único y disperso, `{oauth_client_id: 1}`.

Invariantes: máximo 10 PATs activos por `membership_id` y 10 tokens de integración activos por equipo.

## OAuthClient

Clientes de [OAuth 2.1](12-acceso-programatico.md#oauth-21). **No tiene `team_id`**: un cliente (p. ej. claude.ai) sirve para cualquier equipo. Es la única excepción, junto con `User` y `Session`, a la regla multi-tenant; los tokens y los `OAuthGrant` que emite sí van acotados a un equipo (llevan `team_id`, ver [OAuthGrant](#oauthgrant)).

| Campo | Tipo | Notas |
|-------|------|-------|
| `client_id` | String | Aleatorio, o la URL del *Client ID Metadata Document* |
| `registration` | String | `dynamic` \| `metadata_document` \| `first_party` |
| `name` | String | Máx. 60 caracteres. Se muestra como "no verificado" salvo en `first_party` |
| `redirect_uris` | Array<String> | Coincidencia exacta |
| `client_uri`, `logo_uri` | String | Opcionales. El logo solo se muestra en `first_party` |
| `last_used_at` | Time | |

Índice: `{client_id: 1}` único. Los clientes `dynamic` sin tokens activos se borran a los 30 días sin uso.

## OAuthGrant

Código de autorización pendiente de canjear.

| Campo | Tipo | Notas |
|-------|------|-------|
| `code_digest` | String | SHA-256 del código |
| `oauth_client_id`, `user_id`, `team_id`, `membership_id` | ObjectId | |
| `scopes` | Array<String> | Los aprobados |
| `redirect_uri`, `resource` | String | Se comprueban al canjear |
| `code_challenge` | String | PKCE `S256` |
| `expires_at` | Time | 60 s. TTL |
| `used_at` | Time | Un solo uso. Si se intenta canjear otra vez, se revocan los tokens emitidos con él |

Índices: `{code_digest: 1}` único, `{expires_at: 1}` TTL.

## DeviceAuthorization

Device flow del CLI ([08](08-integracion-claude-code.md#flujo-de-init--rf-cc-021-f5-aceptado)). No estaba en esta spec aunque `RF-CC-001` ya lo requería; análogo a `OAuthGrant` pero para el token de miembro (`hb_mt_`).

| Campo | Tipo | Notas |
|-------|------|-------|
| `device_code_digest` | String | SHA-256 del `device_code` que usa el CLI para hacer polling |
| `user_code` | String | 8 caracteres del alfabeto de `Team.code`, se muestra como `XXXX-XXXX`. Lo escribe la persona en `verification_url` |
| `team_id` | ObjectId | Nullable hasta que se aprueba (si el CLI no mandó `team_code` en la petición inicial) |
| `membership_id` | ObjectId | Nullable hasta que se aprueba |
| `status` | String | `pending` \| `approved` \| `denied` |
| `privacy_level` | String | Elegido al aprobar. Mismos valores que `Membership.claude_code.privacy_level` |
| `consumed_at` | Time | Cuándo se canjeó por un token (un solo uso) |
| `expires_at` | Time | 15 min. TTL |

Índices: `{device_code_digest: 1}` único, `{user_code: 1}`, `{expires_at: 1}` TTL.

## OutboundWebhook

| Campo | Tipo | Notas |
|-------|------|-------|
| `team_id` | ObjectId | |
| `url` | String | Solo HTTPS |
| `events` | Array<String> | Ver [12](12-acceso-programatico.md#webhooks-salientes) |
| `secret_ciphertext` | String | El secreto de firma **cifrado** con `WEBHOOK_SECRETS_KEY` (hace falta para firmar, no basta con un hash) |
| `active` | Boolean | |
| `consecutive_failures` | Integer | A los 50 se pausa |
| `created_by_id` | ObjectId | |

Máximo 5 por equipo.

## OutboundDelivery

| Campo | Tipo | Notas |
|-------|------|-------|
| `team_id`, `outbound_webhook_id` | ObjectId | |
| `event`, `delivery_id` | String | |
| `status` | String | `pending` \| `succeeded` \| `failed` |
| `attempts` | Integer | |
| `response_status`, `duration_ms` | Integer | No se guarda el cuerpo de la respuesta |
| `next_attempt_at` | Time | |

Índices: `{team_id: 1, outbound_webhook_id: 1, created_at: -1}`, `{created_at: 1}` TTL de 14 días.

## Repository

| Campo | Tipo | Notas |
|-------|------|-------|
| `team_id` | ObjectId | |
| `github_repo_id` | Integer | Id estable de GitHub |
| `full_name` | String | `org/repo`. Se actualiza si lo renombran |
| `default_branch` | String | |
| `installation_id` | Integer | |
| `active` | Boolean | `false` si se revoca el acceso |
| `remote_urls` | Array<String> | URLs normalizadas (`github.com/org/repo`) para que el CLI pueda hacer match |

Índices: `{github_repo_id: 1, active: 1}`. Invariante: **un repositorio activo pertenece a un solo equipo** ([ADR-0007](decisiones.md#adr-0007)).

## Objective

| Campo | Tipo | Notas |
|-------|------|-------|
| `team_id` | ObjectId | |
| `number` / `key` | Integer / String | `3` / `O-3` |
| `title` | String | 1–120 caracteres |
| `description` | String | Máx. 2000 caracteres, Markdown |
| `priority` | String | `must` \| `should` \| `could` |
| `position` | Integer | Orden manual |
| `archived_at` | Time | Si está archivado, no entra en el análisis |
| `created_by_id` | ObjectId | User |

Índices: `{team_id: 1, number: 1}` único.

## Feature

| Campo | Tipo | Notas |
|-------|------|-------|
| `team_id` | ObjectId | |
| `number` / `key` | Integer / String | `12` / `F-12` |
| `title` | String | 1–120 caracteres |
| `description` | String | Máx. 5000 caracteres, Markdown |
| `status` | String | `idea` \| `in_progress` \| `done` \| `discarded` |
| `position` | Float | Orden dentro de su columna (reordenar no obliga a reindexar) |
| `objective_ids` | Array<ObjectId> | N:M con Objective |
| `assignee_ids` | Array<ObjectId> | User ids (deben ser miembros del equipo) |
| `deadline` | Time | Opcional |
| `branch_names` | Array<String> | Ramas vinculadas: detectadas por convención o aprendidas al confirmar ([05](05-atribucion.md)) |
| `discarded_reason` | String | Opcional al descartar |
| `status_changed_at` | Time | |
| `arguments` | embebido `Argument[]` | Pros y contras |
| `created_by_id` | ObjectId | |

**Argument** (embebido): `_id`, `kind` (`pro` \| `con`), `text` (1–280 caracteres), `author_id`, `voter_ids` (Array<ObjectId>, un voto por usuario), `created_at`.

Campo calculado (no se guarda): `score = Σ votos(pro) − Σ votos(con)`.

Índices: `{team_id: 1, number: 1}` único, `{team_id: 1, status: 1, position: 1}`, `{team_id: 1, branch_names: 1}`.

## Milestone

| Campo | Tipo | Notas |
|-------|------|-------|
| `team_id` | ObjectId | |
| `title` | String | |
| `kind` | String | `checkpoint` \| `demo` \| `submission` \| `custom` |
| `due_at` | Time | Obligatorio |
| `description` | String | Opcional |

Índice: `{team_id: 1, due_at: 1}`.

## ActivityEvent

El log de actividad. Es append-only, salvo el sub-documento `attribution`.

| Campo | Tipo | Notas |
|-------|------|-------|
| `team_id` | ObjectId | |
| `source` | String | `github` \| `claude_code` \| `mcp` \| `system` |
| `kind` | String | Ver el catálogo abajo |
| `dedupe_key` | String | Único por equipo. P. ej. `gh:commit:<sha>`, `cc:<client_event_id>` |
| `occurred_at` | Time | Cuándo ocurrió (según la fuente) |
| `received_at` | Time | |
| `actor` | Hash | `user_id` (nullable), `membership_id` (nullable), `integration_id` (nullable, token de integración), `display` (String), `github_login` (nullable) |
| `repository_id` | ObjectId | Nullable |
| `branch` | String | Nullable |
| `sha` | String | Nullable |
| `pr_number` | Integer | Nullable |
| `url` | String | Enlace a GitHub si lo hay |
| `title` | String | Línea corta para el feed (máx. 200 caracteres). P. ej., la primera línea del mensaje del commit |
| `summary` | String | Máx. 500 caracteres. Resumen legible (MCP o nivel `summaries`) |
| `files` | Array<Hash> | `{path, additions, deletions}`, máx. 50. Rutas relativas al repo |
| `stats` | Hash | `{files_changed, additions, deletions}` agregados |
| `payload` | Hash | Datos específicos de cada `kind`, ya resumidos. **Nunca** el payload bruto de la fuente |
| `mentioned_feature_keys` | Array<String> | Claves `F-n` encontradas en la rama o el mensaje |
| `attribution` | embebido `Attribution` | Ver abajo |
| `session_ref` | String | Hash de la sesión de Claude Code, para agrupar |
| `via` | Hash | Solo en cambios hechos con un token: `{channel: "api" \| "mcp", token_kind: "member" \| "pat" \| "oauth" \| "integration", token_id, token_prefix, client}`. `client` es el nombre del cliente OAuth o el `clientInfo.name` del cliente MCP (máx. 40 caracteres, no confiable). `nil` si el cambio viene de la web ([RF-API-006](12-acceso-programatico.md#trazabilidad)) |
| `ai_suggestion_attempted_at` | Time | Nullable. Cuándo se intentó la capa 3 de atribución con IA y salió con `confidence < 0.5`. No se reintenta hasta que llegue un evento nuevo en el mismo grupo (actor, rama, sesión) ([05](05-atribucion.md#capa-3--inferencia-con-ia)) |

**Catálogo de `kind`:**

| Fuente | kind |
|--------|------|
| github | `commit`, `pr_opened`, `pr_merged`, `pr_closed`, `pr_reopened`, `branch_created`, `branch_deleted` |
| claude_code | `cc_session_start`, `cc_session_end`, `cc_turn` (turno completo: prompt + herramientas + stop), `cc_prompt` (solo con nivel `summaries`), `system_test` (`hackboard test`, [08](08-integracion-claude-code.md#contrato-de-ingesta)) |
| mcp | `progress_report` |
| system | `feature_status_changed`, `feature_assigned`, `member_joined`, `api_change` (escritura por API o MCP sin evento propio; `payload: {entity, key, action, fields[]}`, sin valores) |

**Attribution** (embebido, nullable):

| Campo | Tipo | Notas |
|-------|------|-------|
| `feature_id` | ObjectId | Nullable (si `status = rejected` sin alternativa) |
| `method` | String | `convention` \| `branch` \| `ai` \| `manual` |
| `status` | String | `confirmed` \| `suggested` \| `rejected` |
| `confidence` | Float | 0–1. Solo aplica a `ai` |
| `reason` | String | Explicación corta (máx. 280 caracteres) |
| `decided_by_id`, `decided_at` | ObjectId, Time | Para `manual`, o al confirmar o rechazar |
| `rejected_feature_ids` | Array<ObjectId> | Sugerencias ya rechazadas, para no repetirlas |

Índices:
- `{team_id: 1, dedupe_key: 1}` único
- `{team_id: 1, occurred_at: -1}`
- `{team_id: 1, "attribution.feature_id": 1, occurred_at: -1}`
- `{team_id: 1, "actor.user_id": 1, occurred_at: -1}`
- `{team_id: 1, "attribution.status": 1}` (para buscar pendientes)
- `{team_id: 1, "via.token_id": 1, occurred_at: -1}` disperso (para "Ver lo que ha hecho" un token)

## AiAnalysis

| Campo | Tipo | Notas |
|-------|------|-------|
| `team_id` | ObjectId | |
| `trigger` | String | `scheduled` \| `manual` |
| `requested_by_id` | ObjectId | Si es manual |
| `status` | String | `queued` \| `running` \| `succeeded` \| `failed` \| `skipped` |
| `skip_reason` | String | P. ej. `no_changes` si `input_hash` coincide con el último análisis |
| `provider`, `model` | String | `gemini`, `gemini-…` |
| `prompt_version` | String | Versión de la plantilla de prompt ([06](06-analisis-ia.md)) |
| `input_hash` | String | SHA-256 del contexto, para no repetir análisis idénticos |
| `context_stats` | Hash | `{objectives, features, events, chars}` |
| `result` | Hash | Esquema de [06](06-analisis-ia.md#esquema-de-salida), ya validado |
| `deterministic_alerts` | Array<Hash> | Alertas calculadas por reglas ([06](06-analisis-ia.md#alertas-deterministas)) |
| `usage` | Hash | `{input_tokens, output_tokens}` |
| `error` | String | |
| `started_at`, `finished_at` | Time | |

Índice: `{team_id: 1, created_at: -1}`.

## WebhookDelivery

Sirve para la idempotencia y la depuración de los webhooks de GitHub.

| Campo | Tipo | Notas |
|-------|------|-------|
| `delivery_id` | String | Cabecera `X-GitHub-Delivery`. Único |
| `event` | String | Cabecera `X-GitHub-Event` |
| `installation_id`, `github_repo_id` | Integer | |
| `status` | String | `received` \| `processed` \| `ignored` \| `failed` |
| `error` | String | |

Índices: `{delivery_id: 1}` único y TTL de 14 días sobre `created_at`. **No** se guarda el cuerpo del webhook.
