# 09 · Privacidad y seguridad

## Principios

1. **Opt-in por persona.** Nadie puede conectar el Claude Code de otro miembro ni cambiar su nivel de privacidad. El owner solo puede ver el estado.
2. **Minimización.** Se guardan metadatos y resúmenes. **Nunca** texto literal de prompts, respuestas de Claude, diffs ni contenido de ficheros.
3. **Filtrar en el origen.** Lo que no debe salir del portátil se descarta en el CLI (repos no vinculados, rutas excluidas), y el servidor lo vuelve a comprobar.
4. **Transparencia.** Cada miembro puede ver exactamente qué se ha guardado de él y borrarlo.

## Inventario de datos

| Dato | Origen | Se guarda | Retención |
|------|--------|-----------|-----------|
| Email, nombre, avatar, login de GitHub | Registro o GitHub | Sí | Mientras exista la cuenta |
| Contraseña | Registro | Solo el hash bcrypt | Mientras exista la cuenta |
| Objetivos, features, argumentos, milestones | Usuarios | Sí | Mientras exista el equipo |
| Commits: sha, mensaje, autor, email, rutas, +/− | GitHub | Sí (el mensaje recortado) | Ver [retención](#retención) |
| Diffs o contenido de ficheros | — | **No** | — |
| Cuerpo bruto de webhooks | GitHub | **No** (solo pasa por la cola de Redis) | — |
| Eventos de Claude Code (metadatos) | CLI | Sí | Ver [retención](#retención) |
| Texto de prompts | CLI | **No** | — |
| Resúmenes de `report_progress` | MCP | Sí (≤ 500 caracteres) | Ver [retención](#retención) |
| Salidas de la IA | Gemini | Sí (`AiAnalysis`) | Como los eventos |

## Terceros

| Tercero | Qué recibe | Para qué |
|---------|------------|----------|
| GitHub | Llamadas a la API con installation tokens | Leer la actividad de los repos vinculados |
| Google (Gemini API) | El contexto de [06](06-analisis-ia.md#construcción-del-contexto-analysisbuildcontext): títulos, descripciones, mensajes de commit, rutas y recuentos | Análisis y atribución |
| Hosting, Mongo y Redis gestionados | Todo lo persistido | Infraestructura |

[ABIERTO] Revisar los términos de uso de datos del plan de Gemini API que se contrate (que no se usen los datos para entrenar) y documentarlo aquí.

## Requisitos de seguridad

| ID | Requisito | Estado |
|----|-----------|--------|
| RNF-SEC-001 | **Aislamiento entre equipos.** Todo acceso a documentos del dominio pasa por `current_team.<relación>`. Hay un test de regresión automático que intenta acceder a recursos de otro equipo desde cada endpoint y espera `404`. | Aceptado [F1] |
| RNF-SEC-002 | Tokens de sesión y de miembro: 32 bytes aleatorios, con prefijo (`hb_s_` y `hb_mt_`). Solo se guarda el SHA-256. El token de miembro se muestra una sola vez. | Aceptado [F1/F5] |
| RNF-SEC-003 | Cookies `httpOnly`, `Secure` y `SameSite=Lax`. Protección CSRF con token de doble envío en los endpoints de sesión que cambian estado. | Aceptado [F1] |
| RNF-SEC-004 | CORS limitado a `APP_URL`. | Aceptado [F1] |
| RNF-SEC-005 | Rate limiting con `rack-attack` sobre Redis: login, signup, join, ingesta, análisis manual y MCP (valores en [03](03-api.md)). | Aceptado [F1] |
| RNF-SEC-006 | Verificación HMAC de webhooks con comparación en tiempo constante. Se rechazan las entregas sin firma. | Aceptado [F3] |
| RNF-SEC-007 | Las respuestas de la IA se tratan como **datos no confiables**: se validan con el esquema, se escapan al renderizar (el Markdown se sanea) y nunca se ejecutan ni se usan para autorizar. | Aceptado [F4] |
| RNF-SEC-008 | **Inyección de prompts:** los mensajes de commit, títulos y descripciones se envían al modelo delimitados y marcados como datos del usuario. La salida solo puede referirse a claves existentes (posvalidación). La IA no tiene acceso a herramientas con efectos. | Aceptado [F4] |
| RNF-SEC-009 | Los logs nunca contienen tokens, cookies, cuerpos de webhook, contextos de IA completos ni prompts. Hay filtro de parámetros de Rails para `token`, `password`, `prompt` y `authorization`. | Aceptado [F1] |
| RNF-SEC-010 | Los secretos solo viven en variables de entorno o un gestor de secretos, nunca en el repo. Hay un escaneo de secretos en CI. | Aceptado [F1] |
| RNF-SEC-011 | Hay un escaneo de dependencias en CI (Dependabot o equivalente) para `api`, `web` y `cli`. | Aceptado [F1] |
| RNF-SEC-012 | El paquete npm `hackboard` se publica con provenance (`npm publish --provenance`) desde CI, y la cuenta de npm tiene 2FA. | Aceptado [F5] |

## Derechos del usuario

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-SEC-001 | Un miembro puede pausar o desconectar Claude Code desde la web o el CLI en cualquier momento, con efecto inmediato. | Aceptado [F5] |
| RF-SEC-002 | "Desconectar y borrar mis eventos" elimina todos sus `ActivityEvent` con `source ∈ {claude_code, mcp}` del equipo. | Aceptado [F5] |
| RF-SEC-003 | Al salir de un equipo se revoca el token y se mantienen sus eventos de GitHub (son historia del repo). Los de Claude Code se borran si el miembro lo elige. | Aceptado [F2] |
| RF-SEC-004 | Borrar la cuenta elimina sus datos personales. En los eventos de GitHub, el actor pasa a mostrarse como "Usuario eliminado" + login. | Aceptado [F2] |
| RF-SEC-005 | Hay una exportación de los datos del equipo en JSON (owner). | Propuesto |

## Retención

- `ActivityEvent` y `AiAnalysis`: se borran **90 días después** de `hackathon.ends_at`, salvo que el owner marque el equipo como "conservar". [ABIERTO] Validar el plazo.
- Equipos con borrado lógico: el borrado físico se hace a los 30 días.
- `WebhookDelivery`: TTL de 14 días. `Session`: TTL a la expiración.
- Lo ejecuta `Maintenance::RetentionJob` (diario).

## Comunicación al usuario

- La pantalla de aprobación del CLI (device flow) y la sección Claude Code de ajustes muestran, con el mismo texto, una tabla "Qué se envía / Qué no se envía" generada a partir de la tabla de niveles de [08](08-integracion-claude-code.md#niveles-de-privacidad). Esa tabla es la fuente única.
- [ABIERTO] Política de privacidad y términos antes del lanzamiento público.
