# 08 · Integración con Claude Code

## Qué es posible y qué no

- **claude.ai (el chat web)** no tiene una API pública para leer las conversaciones de un usuario, así que **no** se integra leyendo historial. La única vía es que Claude informe por sí mismo con un servidor MCP registrado como *connector* (ver [MCP](#servidor-mcp)). [ABIERTO] Requiere OAuth y queda fuera del MVP.
- **Claude Code** sí se integra mediante **hooks**: comandos que Claude Code ejecuta en eventos de su ciclo de vida y que reciben por stdin un JSON con datos de la sesión y del evento. Es donde ocurre el trabajo de desarrollo durante un hackathon.

La integración es **opcional y por persona** (opt-in). Nadie puede activarla por otro miembro. Ver [09](09-privacidad-seguridad.md).

## Componentes

1. **CLI `hackboard`** (paquete npm en `packages/cli`): instala los hooks, guarda la credencial, encola los eventos y los envía.
2. **Endpoint de ingesta** `POST /api/v1/ingest/claude_code`, autenticado con el token de miembro.
3. **Servidor MCP** (opcional, F5 si da tiempo): herramientas para que Claude lea features e informe de su progreso.

---

## CLI

### Instalación

```
npm i -g hackboard
hackboard init --team K7Q2-M9XA
```

Se recomienda instalarlo en global porque cada hook ejecuta el binario, y `npx` añade una latencia inaceptable en cada llamada (RNF-CC-001). `npx hackboard init` también funciona para el paso de `init`: detecta que falta la instalación global y la propone.

### Comandos — `RF-CC-020` [F5] Aceptado

| Comando | Descripción |
|---------|-------------|
| `hackboard init [--team CODE] [--scope local\|user]` | Device flow, elección del nivel de privacidad, instalación de hooks y prueba de conexión. `--scope local` (por defecto) escribe en `<repo>/.claude/settings.local.json`; `user` escribe en `~/.claude/settings.json` |
| `hackboard status` | Equipo, miembro, nivel, pausado o no, eventos en cola, último envío correcto y repos vinculados |
| `hackboard pause` / `resume` | Deja de enviar o reanuda (se sincroniza con el servidor) |
| `hackboard privacy <metadata\|summaries\|off>` | Cambia el nivel (se sincroniza con el servidor) |
| `hackboard test` | Envía un evento `system` de prueba y muestra el resultado |
| `hackboard uninstall [--purge]` | Quita los hooks, borra la credencial y revoca el token. `--purge` borra también los eventos en el servidor |
| `hackboard hook <evento>` | **Uso interno.** Lo que invocan los hooks |
| `hackboard flush` | **Uso interno.** Envía la cola |

### Flujo de `init` — `RF-CC-021` [F5] Aceptado

1. Comprueba que el directorio actual está dentro de un repo git con remote de GitHub (si no, avisa pero continúa en scope `user`).
2. **Device flow:** `POST /cli/device` → muestra `user_code` y abre en el navegador `verification_url`. El usuario inicia sesión, ve el equipo, **ve la explicación de qué datos se envían**, elige el nivel de privacidad y aprueba. El CLI hace polling hasta recibir el token.
3. Guarda la credencial en `~/.config/hackboard/credentials.json` (Windows: `%APPDATA%\hackboard\credentials.json`) con permisos `0600`. **Nunca** se guarda dentro del repo.
4. Descarga `/cli/config` (repos vinculados y reglas) y lo cachea en `~/.config/hackboard/config.json`. Se refresca cada 15 min en el `flush`.
5. **Fusiona** los hooks en el fichero de settings elegido sin tocar lo que ya había. Las entradas propias se identifican porque el comando empieza por `hackboard hook`. Si el fichero existe, antes de escribir guarda una copia en `.bak`.
6. Si el scope es `local`, comprueba que `.claude/settings.local.json` está ignorado por git. Si no lo está, lo añade a `.gitignore`.
7. Ejecuta `hackboard test` y muestra "Listo. Tus eventos aparecerán en <url>/activity".

**Criterio de aceptación:** de `init` a ver el primer evento en el feed, menos de 60 s.

### Hooks instalados

```json
{
  "hooks": {
    "SessionStart":     [{ "hooks": [{ "type": "command", "command": "hackboard hook session-start", "timeout": 5 }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "hackboard hook prompt", "timeout": 5 }] }],
    "PostToolUse":      [{ "matcher": "Edit|MultiEdit|Write|NotebookEdit",
                           "hooks": [{ "type": "command", "command": "hackboard hook tool", "timeout": 5 }] }],
    "Stop":             [{ "hooks": [{ "type": "command", "command": "hackboard hook stop", "timeout": 5 }] }],
    "SessionEnd":       [{ "hooks": [{ "type": "command", "command": "hackboard hook session-end", "timeout": 5 }] }]
  }
}
```

> Al implementarlo hay que verificar los nombres de los eventos, el formato y los campos del JSON de entrada contra la documentación vigente de hooks de Claude Code, y actualizar esta sección si han cambiado.

### Comportamiento de `hackboard hook` — `RNF-CC-001` [F5] Aceptado

- **Nunca bloquea ni rompe Claude Code.** Siempre termina con código de salida `0`, sin escribir nada en stdout (ciertos eventos inyectan el stdout en el contexto de Claude). Los errores van a `~/.config/hackboard/hook.log` (con rotación a 1 MB).
- Presupuesto: **< 100 ms** p95. El hook solo lee stdin, filtra, **añade una línea a la cola local** (`~/.config/hackboard/queue.jsonl`) y, si hace falta enviar, lanza `hackboard flush` como proceso *detached* y termina.
- **Filtro de repositorio (privacidad):** se calcula el remote de `cwd` (`git config --get remote.origin.url`, normalizado y cacheado por `cwd`). **Si no coincide con un repo vinculado al equipo, el evento se descarta en local.** El trabajo en otros proyectos nunca sale del portátil.
- La rama y el HEAD se calculan en local (`git rev-parse --abbrev-ref HEAD`, `git rev-parse HEAD`), con caché de 2 s.
- Si el enlace está `paused` o el nivel es `off`, se descarta.

### Qué recoge cada hook

La cola agrega los eventos por **turno** (desde `UserPromptSubmit` hasta `Stop`) para enviar pocos eventos y con sentido.

| Hook | Datos que lee | Qué produce |
|------|---------------|-------------|
| `SessionStart` | `session_id`, `cwd`, `source` | `cc_session_start` |
| `UserPromptSubmit` | `prompt` | Abre el turno. Con nivel `metadata` solo se guarda `prompt_chars` (la longitud) y **el texto se descarta en memoria**. Con nivel `summaries`, ver abajo |
| `PostToolUse` | `tool_name`, `tool_input.file_path` (o equivalente) | Añade `{path relativo al repo, tool}` al turno. Se ignoran las rutas fuera del repo y las que coinciden con las exclusiones |
| `Stop` | `session_id` | Cierra el turno → `cc_turn` con ficheros editados, número de herramientas, duración y rama. Dispara `flush` |
| `SessionEnd` | `session_id`, `reason` | `cc_session_end`. Dispara `flush` |

**Exclusiones por defecto** (no se envía ni la ruta): `.env*`, `**/secrets/**`, `**/*.pem`, `**/*.key`, `**/credentials*`. El owner puede añadir globs en ajustes (van en `/cli/config`) y cada miembro puede añadir las suyas en `~/.config/hackboard/config.json`.

`session_id` se envía como `session_ref = sha256(session_id + member_id)[0..16]`: sirve para agrupar sin exponer el id real.

### Niveles de privacidad

| Nivel | Se envía | No se envía |
|-------|----------|-------------|
| `off` | Nada | — |
| `metadata` **(por defecto)** | Tipo de evento, horas, rama, sha de HEAD, rutas relativas de ficheros editados, número de herramientas y longitud del prompt | Texto de prompts, respuestas de Claude, contenido de ficheros, comandos ejecutados |
| `summaries` | Lo de `metadata` + **un resumen** del turno | Texto literal del prompt (no se guarda nunca) |

**Cómo se generan los resúmenes** (`summaries`). [ABIERTO] Hay dos opciones:
- **A (preferida):** los resúmenes solo los escribe Claude mediante la herramienta MCP `report_progress`. El usuario los ve en su terminal antes de que se envíen. No se transmite el prompt.
- **B:** el CLI envía el prompt recortado (máx. 2000 caracteres) por TLS, el servidor lo resume con Gemini en memoria (≤ 200 caracteres) y **descarta el original sin persistirlo ni loguearlo**. Es más cómodo, pero el prompt sale del portátil y pasa por un tercero.

Hasta que se decida, en el MVP `summaries` = opción A.

### Envío (`flush`)

- Lotes de hasta 200 eventos. Se reintenta con backoff exponencial (1 s → 5 min). La cola sobrevive a reinicios.
- La cola local tiene un tope de 5000 eventos. Si se supera, se descartan los más antiguos y se anota en el log.
- Un lock de fichero evita que haya dos `flush` a la vez.
- Si la respuesta es `401` (token revocado), el CLI se marca como desconectado, deja de encolar y `status` lo indica.

---

## Contrato de ingesta

`POST /api/v1/ingest/claude_code` · `Authorization: Bearer hb_mt_…` · `RF-CC-004`

```json
{
  "cli_version": "0.3.1",
  "events": [
    {
      "client_event_id": "01J9Z…",            // ULID, clave de idempotencia
      "kind": "cc_turn",                      // cc_session_start | cc_session_end | cc_turn | system_test
      "occurred_at": "2026-09-21T18:03:11Z",
      "session_ref": "a1b2c3d4e5f60718",
      "repo": { "remote": "github.com/org/repo", "branch": "f-12-login", "head_sha": "9f2c…" },
      "data": {
        "files": [ { "path": "apps/web/app/login/page.tsx", "tool": "Edit" } ],
        "tool_uses": 7,
        "prompt_chars": 342,
        "duration_ms": 81234
      }
    }
  ]
}
```

- El esquema está en `packages/shared-schemas/ingest-claude-code.schema.json`. Los eventos inválidos se descartan de forma individual y la respuesta los lista:
  ```json
  { "accepted": 12, "duplicates": 1, "rejected": [ { "client_event_id": "…", "reason": "repo_not_linked" } ] }
  ```
- El servidor **vuelve a validar** que `repo.remote` es un repo activo del equipo (`repo_not_linked` si no) y que el nivel del miembro lo permite. Descarta cualquier campo que no esté en el esquema.
- `actor` = el miembro dueño del token, sin excepciones.
- `dedupe_key = cc:<client_event_id>`.
- El procesamiento es asíncrono (`Ingest::ProcessBatchJob`) y después pasa por la atribución (capas 1–3).

---

## Servidor MCP

`RF-MCP-001` [F5] Aceptado (si da tiempo; si no, pasa a una fase posterior).

- Transporte: **Streamable HTTP** en `POST /api/v1/mcp`, autenticado con el token de miembro. Así no hay que instalar nada más:
  ```
  claude mcp add --transport http hackboard https://<api>/api/v1/mcp --header "Authorization: Bearer hb_mt_…"
  ```
  La web muestra este comando listo para copiar (RF-MCP-010).
- Herramientas:

| Herramienta | Entrada | Salida | Efecto |
|-------------|---------|--------|--------|
| `list_features` | `{status?, mine?: bool}` | Lista de `{key, title, status, assignees, deadline}` | Solo lectura |
| `get_feature` | `{key}` | Detalle con la descripción y los objetivos | Solo lectura |
| `list_objectives` | `{}` | `{key, title, priority}` | Solo lectura |
| `report_progress` | `{feature_key, summary (≤ 500), status_hint?: "started"\|"blocked"\|"ready_for_review"}` | `{ok, event_id}` | Crea `ActivityEvent{source: mcp, kind: progress_report}` con atribución `convention/confirmed` a esa feature. **No cambia** el estado de la feature: `status_hint` solo se muestra como sugerencia |
| `suggest_branch_name` | `{feature_key}` | `"f-12-login-con-github"` | Solo lectura |

- Las descripciones de las herramientas indican a Claude que use `report_progress` al terminar una unidad de trabajo significativa y que el resumen **no** debe incluir secretos ni código.
- Rate limit de `report_progress`: 30 al día por miembro y feature.
- **claude.ai como connector:** los connectors remotos requieren OAuth. [ABIERTO] Implementar un servidor de autorización OAuth 2.1 (o un proveedor externo) en una fase posterior.

## Requisitos adicionales

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-CC-022 | Funciona en macOS, Linux y Windows (en Windows, con Git Bash o PowerShell; los hooks invocan `hackboard.cmd` si hace falta). | Aceptado [F5] |
| RF-CC-023 | `hackboard uninstall` deja los ficheros de settings exactamente como estaban, salvo cambios de terceros hechos después. | Aceptado [F5] |
| RF-CC-024 | Si cambia la versión del esquema de ingesta, el servidor acepta la versión N y la N−1. Con una versión más antigua responde `426` y el CLI propone actualizarse. | Aceptado [F5] |
| RF-CC-025 | La web muestra a cada miembro **sus propios** eventos de Claude Code tal como se guardaron ("Ver lo que se ha enviado"). | Aceptado [F5] |
