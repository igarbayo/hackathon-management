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

## ADR-0012

**Rate limiting con un contador propio en Redis en vez de `rack-attack`** · Aceptado · 2026-09-22

- **Contexto:** [09](09-privacidad-seguridad.md#requisitos-de-seguridad) (RNF-SEC-005) y [12](12-acceso-programatico.md#requisitos-no-funcionales) (RNF-API-001) nombraban `rack-attack` como mecanismo. Al implementar login (F1) ya se había construido `RateLimiter`, un contador de ventana fija sobre `Sidekiq.redis` (mismo Redis que ya usa el proyecto, sin gem ni inicializador nuevos), con una excepción (`RateLimiter::LimitExceeded`) que `ApplicationController` traduce al formato de error estándar (`03-api.md#convenciones-generales`) igual que cualquier otro `ApiError`.
- **Decisión:** se mantiene `RateLimiter` como el único mecanismo de rate limiting de la API (login, signup, join, ingesta; PAT/MCP y `report_progress` lo usarán igual en [12](12-acceso-programatico.md)). Los RNF-SEC-005 y RNF-API-001 se corrigen para nombrarlo en vez de `rack-attack`.
- **Alternativas:** `rack-attack` da throttling a nivel de middleware (antes de `ActionController`, así que una IP bloqueada ni siquiera llega a autenticar), listas de bloqueo/permitidas y una consola de inspección, pero es una dependencia y un inicializador más para un proyecto que ya tiene sus propios límites atados a claves de negocio (`email`, `token_id`, `membership_id`) que no son triviales de expresar como discriminadores de `rack-attack` sin las mismas líneas de código.
- **Consecuencias:** un pico de tráfico malicioso consume algo más de ciclos de Rails que con `rack-attack` (llega hasta el controlador antes de que se le corte), aceptable al volumen de un hackathon. Si hiciera falta bloqueo a nivel de IP/red más agresivo en el futuro, se puede añadir `rack-attack` **además** de `RateLimiter` sin tocar este último.

## ADR-0013

**Sistema de diseño: F0 de Factorial portado sobre shadcn/Base UI** · Aceptado · 2026-09-23

- **Contexto:** RF-UX-001 pedía un menú lateral "tipo Factorial" desde el principio, pero la interfaz nunca se llegó a alinear con ningún sistema de diseño concreto: usaba la paleta gris por defecto de shadcn sin tocar. Se decide adoptar explícitamente **F0**, el sistema de diseño público de Factorial (`github.com/factorialco/f0`, docs en `f0.factorial.dev`), como referencia de estilo.
- **Decisión:** no se instala `@factorialco/f0-react`. Se portan literalmente los tokens de `@factorialco/f0-core@2.7.0` (colores `f1-*`, tipografía Inter, radios, sombras y espaciado) al `globals.css` de `apps/web`, expuestos en Tailwind v4 vía `@theme inline` con los mismos nombres de clase que usa F0 (`text-f1-foreground-secondary`, `bg-f1-background-critical`…). Los primitivos de `components/ui` (shadcn "base-nova" sobre Base UI) se restilan para calcar el aspecto de los componentes F0 (F0Button, F0Card, F0TagStatus, Sidebar, PageHeader) copiando sus clases reales del código fuente de F0, y se siguen sus reglas de escritura y de patrones CRUD. Los iconos siguen siendo Lucide (no el set propio de F0), con los tamaños y grosores de F0. Ver [13](13-sistema-diseno.md).
- **Alternativas:**
  - **Instalar `@factorialco/f0-react` directamente:** es lo más fiel al pie de la letra, pero el paquete fija `react`/`react-dom` en exactamente `18.3.1` y exige Tailwind `^3.4.3` más unas 20 dependencias de Radix y otra veintena de paquetes pesados (`pdfjs-dist`, `livekit-client`, `@xyflow/react`…), lo que obligaría a bajar el proyecto de Next 16/React 19/Tailwind v4 a un stack antiguo solo para el aspecto visual. Sus componentes de aplicación (`ApplicationFrame`, `OneDataCollection`) son además experimentales y pensados para el propio monorepo de Factorial, sin documentación de uso en Next.js.
  - **Híbrido, solo `@factorialco/f0-core` como dependencia npm:** casi el mismo resultado que la opción elegida, pero ata el build a la publicación de ese paquete en vez de a una copia literal de los tokens, sin ninguna ventaja real dado que los tokens son un puñado de constantes estables.
- **Consecuencias:** cualquier deriva entre los tokens copiados y una futura versión de `f0-core` hay que detectarla a mano (no hay paquete que avise). Los componentes no son instancias reales de F0: replican su clase CSS pero no heredan su lógica (accesibilidad ARIA fina, animaciones con `motion`, i18n). RF-UX-001 pasa a referenciar F0 explícitamente en vez de una alusión genérica a "tipo Factorial".

## ADR-0014

**Clave de Gemini por persona en vez de una clave compartida del servidor** · Aceptado · 2026-09-23

- **Contexto:** hasta ahora la app usaba una única `GEMINI_API_KEY` del servidor para todo el consumo de IA de todos los equipos (análisis programado, manual y atribución sugerida). Con varios equipos usando la herramienta a la vez, todo el gasto de tokens recaía sobre esa clave, puesta y pagada por una sola persona.
- **Decisión:** cada persona pone su propia clave de Gemini en su perfil (RF-AI-021, [06](06-analisis-ia.md#clave-de-api--rf-ai-021-f4-aceptado)), cifrada en reposo. Las acciones que dispara alguien (manual, MCP) usan su clave; lo automático de un equipo (cron, atribución) usa la del owner del equipo. Sin clave puesta, esa llamada a la IA simplemente no se hace (se marca `skipped`/`no_api_key` o se reintenta en el siguiente ciclo) — no hay fallback a una clave compartida.
- **Alternativas:**
  - **Clave a nivel de equipo, puesta por el owner:** más simple (un solo campo en `Team.settings`), pero no resuelve el problema para equipos con un owner que no quiere o no puede poner su clave, y no permite que un miembro use la suya para sus propias acciones bajo demanda.
  - **Mantener `GEMINI_API_KEY` del servidor como fallback:** menos disruptivo, pero no cumple el objetivo (si nadie configura la suya, se sigue gastando la clave compartida).
- **Consecuencias:** `Ai::Gemini`/`Ai::ProviderFactory.build` pasan a exigir `api_key:` explícito, ya no leen `ENV["GEMINI_API_KEY"]`. `rake ai:eval` (herramienta de desarrollador, no runtime de la app) sigue leyendo esa variable del entorno de quien lo ejecuta. Un equipo sin ninguna clave puesta no tiene IA hasta que alguien la configure; la pantalla de análisis y el botón "Analizar ahora" lo indican.

## ADR-0015

**Acento de marca morado en lugar del radical de F0** · Aceptado · 2026-09-23

- **Contexto:** con los tokens de F0 portados tal cual ([ADR-0013](#adr-0013)), el acento de toda la web (botón primario, textos e iconos de acento) era el radical carmesí de Factorial. Hackboard tiene ya logos propios en morado (`#5E3A8C`) y el carmesí chocaba con ellos.
- **Decisión:** se sustituyen solo `--accent-50/60/70` por la escala del morado de los logos, en claro y en oscuro (RNF-UI-005, [13](13-sistema-diseno.md)). El resto de la paleta de F0 (neutros, `selected`/anillo de foco viridian, estados, moods, gráficos) no se toca.
- **Alternativas:**
  - **Mantener el radical de F0 y usar el morado solo en los logos:** fiel a F0, pero la marca y la interfaz tendrían dos colores protagonistas que compiten.
  - **Teñir de morado también `selected` y el anillo de foco:** más "de marca", pero confunde acento (acción principal) con selección, y el viridian es parte de cómo F0 distingue ambos estados.
- **Consecuencias:** es la primera desviación deliberada de un valor de F0; cualquier nueva desviación debe quedar documentada igual en la spec 13. El morado oscuro con texto blanco cumple AA en ambos temas.

## ADR-0016

**Licencia AGPL-3.0-or-later** · Aceptado · 2026-09-23

- **Contexto:** el repositorio no tenía licencia (el CLI se declaraba `UNLICENSED`) y se publica como "the open-source hackathon management platform". Se inventariaron todos los componentes (814 entradas de `package-lock.json`, 134 de `Gemfile.lock`, imágenes y servicios de `docker-compose*.yml`, fuentes, iconos, código copiado y APIs externas) para decidir con datos. Todo lo que forma parte de la aplicación es permisivo (MIT, ISC, BSD, Apache-2.0, BlueOak, Python-2.0, CC-BY-4.0 para datos) o copyleft débil compatible (Sidekiq LGPL-3.0, libvips LGPL-3.0 opcional, MPL-2.0 solo en desarrollo). Lo no OSI (MongoDB SSPL, Redis 7.4 RSAL/SSPL, Brakeman) son servicios o herramientas separadas, no enlazadas ni distribuidas.
- **Decisión:** HackBoard se licencia bajo **AGPL-3.0-or-later**. Texto en `LICENSE` y `LICENSES/AGPL-3.0-or-later.txt`; justificación e inventario completo en `docs/COMPONENTS_LICENSE.md`. Todos los `package.json` del monorepo declaran `"license": "AGPL-3.0-or-later"`. Excepción: los **logos e iconos** (`apps/web/public/*.svg`, `apps/web/public/icons/*`, `apple-icon.png`, `favicon.ico`, `icon.svg`) son de todos los derechos reservados (`LicenseRef-AllRightsReserved`) y un fork debe sustituirlos. El repo cumple REUSE 3.3: `REUSE.toml` declara AGPL por defecto y la excepción de los logos, y el código copiado de terceros lleva cabecera SPDX con su autor y licencia original (`MIT AND AGPL-3.0-or-later`), con el texto en `LICENSES/MIT.txt`. CI ejecuta `reuse lint`.
- **Alternativas:**
  - **MIT / BSD-3-Clause:** máxima adopción, pero permiten que alguien aloje una versión modificada y cerrada como servicio, que es justo como se usa HackBoard.
  - **Apache-2.0:** añade concesión de patentes, pero tiene el mismo hueco de SaaS. Sería la opción si la prioridad pasara a ser la adopción corporativa.
  - **GPL-3.0:** solo obliga al distribuir copias; ejecutar la app en un servidor propio no es distribuir ("SaaS loophole").
  - **AGPL-3.0-only:** descartada a favor de "or later" (recomendación de la FSF; compatibilidad con futuras versiones).
- **Consecuencias:** quien despliegue una versión **modificada** como servicio debe ofrecer su código a sus usuarios (§13); el despliegue propio debería enlazar al repositorio desde la interfaz (pendiente: requiere un requisito de UI en [04](04-pantallas.md)). Todo código copiado o adaptado de otro proyecto necesita cabecera SPDX con su autor y licencia, el texto de esa licencia en `LICENSES/` y una fila en `docs/COMPONENTS_LICENSE.md`; si no, `reuse lint` rompe el CI. Al no ser libres los logos, el repositorio no es 100 % software libre, y quien despliegue un fork necesita su propia marca. Algunas organizaciones prohíben AGPL internamente; se asume porque el público son equipos y organizadores de hackathons. Mientras Ignacio Garbayo sea el único titular del copyright se puede relicenciar (p. ej. `packages/shared-schemas` a MIT); con contribuciones externas sin CLA ya no.

## ADR-0017

**Neutros grises (tipo Discord) en el modo oscuro** · Aceptado · 2026-09-23

- **Contexto:** el modo oscuro de F0 tiñe de azul marino el fondo de paneles y tarjetas (`--neutral-0: 218 48% 10%`) y las sombras. Con el acento morado de marca ([ADR-0015](#adr-0015)) ese azul no convencía: se pidió un gris neutro como el de la interfaz oscura de Discord.
- **Decisión:** en `.dark` se sustituyen `--neutral-0` por `228 6% 20%` (#313338), `--page` por `225 6% 13%` (#1e1f22, opaco en vez de blanco al 3 %), `--neutral-2/3` por blancos translúcidos y `--shadow-color` por negro (RNF-UI-006, [13](13-sistema-diseno.md)). Los demás neutros oscuros ya eran blancos translúcidos y se quedan. Matiza ADR-0015, que dejaba intactos todos los neutros de F0: el modo claro sigue siéndolo.
- **Alternativas:**
  - **Mantener el azul marino de F0:** fiel a F0, pero es justo el tono que no gustaba.
  - **Negro puro o casi (`#121212`):** más contraste y ahorra batería en OLED, pero los paneles flotantes pierden separación con el fondo de página y cansa más en sesiones largas.
- **Consecuencias:** segunda desviación deliberada de F0, documentada en la spec 13. El texto blanco (y los secundarios al 50 %) sobre `#313338` sigue cumpliendo AA. El `theme-color` oscuro (`BRAND_COLOR_DARK`, morado) y la imagen Open Graph no cambian.
