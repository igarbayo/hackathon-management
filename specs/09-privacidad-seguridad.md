# 09 · Privacidad y seguridad

> **Estado de implementación:** Implementada (revisión dedicada contra el catálogo de RNF-SEC-\*/RF-SEC-\*, ver CHANGELOG) · **Última actualización:** 2026-09-24. `[ABIERTO]` sin resolver: plazo exacto de retención y términos de uso (la política de privacidad ya está publicada, RF-SEC-007). RF-SEC-005, exportación en JSON, sigue en `Propuesto`.

## Principios

1. **Opt-in por persona.** Nadie puede conectar el Claude Code de otro miembro ni cambiar su nivel de privacidad. El owner solo puede ver el estado.
2. **Minimización.** Se guardan metadatos y resúmenes. **Nunca** texto literal de prompts, respuestas de Claude, diffs ni contenido de ficheros.
3. **Filtrar en el origen.** Lo que no debe salir del portátil se descarta en el CLI (repos no vinculados, rutas excluidas), y el servidor lo vuelve a comprobar.
4. **Transparencia.** Cada miembro puede ver exactamente qué se ha guardado de él y borrarlo.

## Inventario de datos

| Dato | Origen | Se guarda | Retención |
|------|--------|-----------|-----------|
| Email, nombre, avatar, login de GitHub | Registro, GitHub o Google | Sí | Mientras exista la cuenta |
| `sub` de Google | Google | Sí (solo el identificador; nunca los tokens de Google) | Mientras exista la cuenta |
| Clientes OAuth y conexiones | Apps que se registran, consentimiento | Nombre, URIs de redirección, scopes aprobados y digests de tokens | Hasta 30 días después de revocarse o caducar |
| Secretos de webhooks salientes | Owner | Cifrados | Mientras exista el webhook |
| Entregas de webhooks salientes | Sistema | Estado, código HTTP y duración (sin cuerpos) | 14 días |
| Contraseña | Registro | Solo el hash bcrypt | Mientras exista la cuenta |
| Sesiones web: IP y user agent | Login | Sí, junto al SHA-256 del token de sesión | 30 días desde el último uso (TTL de `Session`) |
| Logs de la API y del worker (incluyen IP y ruta) | Rails, a STDOUT | En los logs de Docker, rotados (`json-file`, 3 × 10 MB en `docker-compose.prod.yml`) | Hasta que se sobrescriben |
| Contadores de `RateLimiter` (clave con IP o usuario) | Sistema | Solo en Redis | ≤ 1 h |
| Objetivos, features, argumentos, milestones | Usuarios | Sí | Mientras exista el equipo |
| Commits: sha, mensaje, autor, email, rutas, +/− | GitHub | Sí (el mensaje recortado) | Ver [retención](#retención) |
| Diffs o contenido de ficheros | — | **No** | — |
| Cuerpo bruto de webhooks | GitHub | **No** (solo pasa por la cola de Redis) | — |
| Eventos de Claude Code (metadatos) | CLI | Sí | Ver [retención](#retención) |
| Texto de prompts | CLI | **No** | — |
| Resúmenes de `report_progress` | MCP | Sí (≤ 500 caracteres) | Ver [retención](#retención) |
| Tokens de acceso personales | Ajustes | Solo el SHA-256, el prefijo, los scopes y `last_used_at` | Hasta 30 días después de revocarse o caducar |
| Clave personal de Gemini | Ajustes | Cifrada (`GeminiApiKeyCipher`), nunca en claro tras guardarla; la API solo informa de si está configurada | Mientras exista la cuenta o hasta que se quite |
| Marca `via` de cambios por API o MCP | API, MCP | Sí (canal, token y nombre del cliente; nunca el cuerpo de la petición) | Como los eventos |
| Respuestas guardadas por `Idempotency-Key` | API | Solo en Redis | 24 h |
| Salidas de la IA | Gemini | Sí (`AiAnalysis`) | Como los eventos |

## Terceros

| Tercero | Qué recibe | Para qué |
|---------|------------|----------|
| GitHub | Llamadas a la API con installation tokens. En el login, la redirección OAuth | Leer la actividad de los repos vinculados e identificar al usuario |
| Google | Solo la redirección de login (OpenID Connect) | Identificar al usuario. Hackboard no pide acceso a Gmail, Drive ni ningún otro dato de Google |
| Anthropic (claude.ai), si un miembro lo conecta | Los resultados de las herramientas MCP que Claude llame, según los scopes aprobados | Que el miembro consulte y actualice el tablero desde el chat |
| Destinos de webhooks salientes (los elige un owner) | Eventos de features, objetivos, milestones, análisis y actividad de GitHub y del sistema. **Nunca** eventos de Claude Code ni de MCP | Integrar con otras herramientas del equipo |
| Google (Gemini API), con la clave de quien corresponda ([06](06-analisis-ia.md#clave-de-api--rf-ai-021-f4-aceptado)) | El contexto de [06](06-analisis-ia.md#construcción-del-contexto-analysisbuildcontext): títulos, descripciones, mensajes de commit, rutas y recuentos | Análisis y atribución |
| Servidor propio en España (api, worker, web) | Todo | Infraestructura |
| Cloudflare (Tunnel) | Todo el tráfico HTTP en tránsito, con la IP del cliente | Exponer el servidor sin abrir puertos |
| MongoDB Atlas y Upstash, en regiones de la UE | Todo lo persistido y las colas | Base de datos y Redis gestionados |
| Apps y agentes que el miembro conecta con un token | Lo que permitan los scopes del token (como mínimo, todo lo que el miembro ve del equipo) | Lo decide el miembro. Hackboard no controla qué hace ese tercero con los datos; la web lo avisa al crear el token |

[ABIERTO] Revisar los términos de uso de datos del plan de Gemini API que contrate cada persona (que no se usen los datos para entrenar) y documentarlo aquí; al ser una clave personal, Hackboard ya no puede garantizarlo por todo el mundo, solo avisar de qué se envía.

## Requisitos de seguridad

| ID | Requisito | Estado |
|----|-----------|--------|
| RNF-SEC-001 | **Aislamiento entre equipos.** Todo acceso a documentos del dominio pasa por `current_team.<relación>`. Hay un test de regresión automático que intenta acceder a recursos de otro equipo desde cada endpoint y espera `404`. | Aceptado [F1] |
| RNF-SEC-002 | Tokens de sesión, de miembro y de acceso personal: 32 bytes aleatorios, con prefijo (`hb_s_`, `hb_mt_` y `hb_pat_`). Solo se guarda el SHA-256, comparado en tiempo constante. Los tokens de miembro y los PAT se muestran una sola vez. Los prefijos son distintivos para que el escaneo de secretos los detecte. | Aceptado [F1/F2/F5] |
| RNF-SEC-003 | Cookies `httpOnly`, `Secure` y `SameSite=Lax`. Protección CSRF con token de doble envío en los endpoints de sesión que cambian estado. | Aceptado [F1] |
| RNF-SEC-004 | CORS limitado a `APP_URL`. | Aceptado [F1] |
| RNF-SEC-005 | Rate limiting con `RateLimiter` (contador propio sobre `Sidekiq.redis`, [ADR-0012](decisiones.md#adr-0012)): login, signup, join, ingesta, análisis manual, peticiones con PAT y MCP (valores en [03](03-api.md) y [12](12-acceso-programatico.md#requisitos-no-funcionales)). Detrás de Cloudflare Tunnel, la IP del cliente sale de `CF-Connecting-IP` (middleware `CloudflareRemoteIp`), solo si la conexión llega desde una red privada o loopback. | Aceptado [F1] |
| RNF-SEC-006 | Verificación HMAC de webhooks con comparación en tiempo constante. Se rechazan las entregas sin firma. | Aceptado [F3] |
| RNF-SEC-007 | Las respuestas de la IA se tratan como **datos no confiables**: se validan con el esquema, se escapan al renderizar (el Markdown se sanea) y nunca se ejecutan ni se usan para autorizar. | Aceptado [F4] |
| RNF-SEC-008 | **Inyección de prompts:** los mensajes de commit, títulos y descripciones se envían al modelo delimitados y marcados como datos del usuario. La salida solo puede referirse a claves existentes (posvalidación). La IA no tiene acceso a herramientas con efectos. | Aceptado [F4] |
| RNF-SEC-009 | Los logs nunca contienen tokens, cookies, cuerpos de webhook, contextos de IA completos ni prompts. Hay filtro de parámetros de Rails para `token`, `password`, `prompt`, `authorization` e `idempotency_key`, y los logs nunca registran los argumentos de las herramientas MCP (solo el nombre de la herramienta, el resultado y la duración). | Aceptado [F1] |
| RNF-SEC-010 | Los secretos solo viven en variables de entorno o un gestor de secretos, nunca en el repo. Hay un escaneo de secretos en CI. | Aceptado [F1] |
| RNF-SEC-011 | Hay un escaneo de dependencias en CI (Dependabot o equivalente) para `api`, `web` y `cli`. | Aceptado [F1] |
| RNF-SEC-013 | **Agentes y datos no confiables.** Lo que devuelven la API y el MCP (títulos, descripciones, argumentos, mensajes de commit) lo han escrito personas o GitHub y puede contener instrucciones maliciosas para el agente que lo lee. Las descripciones de las herramientas MCP lo advierten, la escritura se limita por scopes y rate limit, no existen herramientas destructivas y todo cambio queda en el feed con `via` para poder revisarlo y revertirlo. | Aceptado [F5] |
| RNF-SEC-014 | Un token de un equipo borrado, o un PAT/OAuth cuya membresía ya no existe, nunca se resuelve (`Tokens::Resolve`), aunque no se haya revocado; lo mismo el token de miembro en la ingesta. Los permisos efectivos de un token son `scopes ∩ permisos del rol`. Los endpoints `session_only` ([12](12-acceso-programatico.md#qué-no-se-puede-hacer-con-un-token)) nunca aceptan Bearer. | Aceptado [F2] |
| RNF-SEC-015 | **OAuth 2.1:** PKCE `S256` obligatorio. Coincidencia exacta de `redirect_uri`. `state` obligatorio. Tokens ligados al `resource`. Códigos de un solo uso y 60 s. Refresh tokens rotados con detección de reutilización. Nunca se aceptan ni se reenvían tokens de Google o GitHub (sin *token passthrough*). El login con Google valida el ID token (firma, `iss`, `aud`, `nonce`, `exp`) y exige `email_verified`. Una cuenta solo se vincula por email si el proveedor lo da como verificado. | Aceptado [F1/F6] |
| RNF-SEC-016 | **Webhooks salientes:** firma HMAC-SHA256 con timestamp, secretos cifrados, solo HTTPS, sin seguir redirecciones, timeout de 5 s y protección SSRF (resolución de DNS en el envío y bloqueo de rangos privados, loopback, link-local y metadatos de nube). | Aceptado [F6] |
| RNF-SEC-012 | El paquete npm `hackboard` se publica con provenance (`npm publish --provenance`) desde CI, y la cuenta de npm tiene 2FA. Workflow: `.github/workflows/release-cli.yml` (ver [08](08-integracion-claude-code.md#publicación-en-npm--rnf-sec-012-f5-aceptado)). Pasa a Implementado con la primera versión publicada. | Aceptado [F5] |

## Derechos del usuario

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-SEC-001 | Un miembro puede pausar o desconectar Claude Code desde la web o el CLI en cualquier momento, con efecto inmediato. | Aceptado [F5] |
| RF-SEC-002 | "Desconectar y borrar mis eventos" elimina todos sus `ActivityEvent` con `source ∈ {claude_code, mcp}` del equipo. | Aceptado [F5] |
| RF-SEC-003 | Al salir de un equipo se revoca el token y se mantienen sus eventos de GitHub (son historia del repo). Los de Claude Code se borran si el miembro lo elige. | Aceptado [F2] |
| RF-SEC-004 | Borrar la cuenta elimina sus datos personales (`Accounts::Destroy`): el usuario y sus sesiones, sus membresías (con el enlace de Claude Code), sus `OAuthGrant`, sus eventos `claude_code` y `mcp`, y revoca sus PAT y tokens OAuth (`revoke_reason: account_deleted`; los de integración son del equipo y siguen). En el resto de eventos el actor pasa a `user_id`/`membership_id` nulos y `display` "Usuario eliminado", sin `email` ni `author_name` (RF-GH-024), conservando `github_login`. Lo que escribió en el equipo (features, argumentos) se queda. | Implementado [F2] |
| RF-SEC-005 | Hay una exportación de los datos del equipo en JSON (owner). | Propuesto |
| RF-SEC-007 | **Política de privacidad pública** en `/privacy` (arts. 13 y 14 del RGPD): responsable y contacto, tratamientos con finalidad, base legal y plazo, datos de no usuarios (autores de commits), terceros y transferencias, declaración de uso limitado de datos de Google, cookies, derechos y AEPD, decisiones automatizadas, menores (mínimo 16 años) y cambios. Enlazada desde login y registro. Su contenido sigue este documento: un cambio en el inventario, en los terceros o en la retención la actualiza en el mismo cambio. | Implementado |
| RF-SEC-006 | Cada miembro ve sus tokens y lo que ha hecho cada uno, y los revoca con efecto inmediato. Un owner puede revocar los de cualquiera, pero nunca crear tokens en nombre de otro. | Aceptado [F2] |

## Retención

- `ActivityEvent` y `AiAnalysis`: se borran **90 días después** de `hackathon.ends_at`, salvo que el owner marque el equipo como "conservar". [ABIERTO] Validar el plazo.
- Equipos con borrado lógico: el borrado físico se hace a los 30 días.
- `WebhookDelivery`: TTL de 14 días. `Session`: TTL a la expiración.
- Lo ejecuta `Maintenance::RetentionJob` (diario).

## Comunicación al usuario

- La pantalla de aprobación del CLI (device flow) y la sección Claude Code de ajustes muestran, con el mismo texto, una tabla "Qué se envía / Qué no se envía" generada a partir de la tabla de niveles de [08](08-integracion-claude-code.md#niveles-de-privacidad). Esa tabla es la fuente única.
- La política de privacidad se publica en `/privacy` (RF-SEC-007). Responsable: Ignacio Garbayo, contacto `iggarbayo@gmail.com`.
- Borrar la cuenta se hace desde Ajustes (RF-AUTH-013).
- [ABIERTO] Términos de uso antes del lanzamiento público.
