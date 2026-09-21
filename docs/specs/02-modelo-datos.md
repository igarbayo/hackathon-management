# 02 · Modelo de datos (Mongoid)

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
| `password_digest` | String | Opcional si hay login con GitHub (`ActiveModel::SecurePassword`) |
| `github_uid` | Integer | Único y disperso (`sparse`). Id numérico de GitHub |
| `github_login` | String | Se actualiza en cada login con GitHub |
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
| `actor` | Hash | `user_id` (nullable), `membership_id` (nullable), `display` (String), `github_login` (nullable) |
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

**Catálogo de `kind`:**

| Fuente | kind |
|--------|------|
| github | `commit`, `pr_opened`, `pr_merged`, `pr_closed`, `pr_reopened`, `branch_created`, `branch_deleted` |
| claude_code | `cc_session_start`, `cc_session_end`, `cc_turn` (turno completo: prompt + herramientas + stop), `cc_prompt` (solo con nivel `summaries`) |
| mcp | `progress_report` |
| system | `feature_status_changed`, `feature_assigned`, `member_joined` |

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
