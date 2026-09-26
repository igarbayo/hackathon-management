# 04 · Pantallas y requisitos funcionales

> **Estado de implementación:** Implementada · **Última actualización:** 2026-09-25

## Layout general — `RF-UX`

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-UX-001 | Menú lateral fijo con el estilo del sistema de diseño F0 de Factorial ([13](13-sistema-diseno.md)), iconos de Lucide y texto. Va integrado en el fondo de la página (`f1-special-page`), sin borde, sombra ni fondo propio y sin separadores entre cabecera, navegación y pie; solo el contenido flota como panel. Mide lo que la pantalla (menos los márgenes) y no se mueve al hacer scroll aunque la página crezca; si la navegación no cabe, hace scroll dentro del menú. Se colapsa a solo iconos en pantallas < 1024 px y pasa a un drawer en < 768 px, que se cierra al elegir cualquier opción (navegación, logo o cambio de equipo). | Aceptado [F1] |
| RF-UX-002 | Arriba del menú: selector de equipo (si el usuario tiene más de uno), que muestra siempre el nombre del equipo y nunca su id, y nombre del hackathon. | Aceptado [F1] |
| RF-UX-003 | Barra superior con una **cuenta atrás persistente** al siguiente milestone. Cambia a ámbar a menos de 3 h y a rojo a menos de 1 h. | Aceptado [F2] |
| RF-UX-004 | Todas las fechas se muestran en la zona horaria del hackathon e indican la zona, con formato en inglés (`en-US`, RNF-UI-013). | Aceptado [F1] |
| RF-UX-005 | Todas las pantallas tienen estados de *cargando* (skeleton), *vacío* (con un CTA para crear lo primero) y *error* (con reintento). | Aceptado [F1] |
| RF-UX-006 | Modo claro y oscuro según el sistema, con un interruptor manual. | Aceptado [F1] |
| RF-UX-007 | Buscador global `Ctrl/Cmd+K`: salta a una feature por clave o título, o a una pantalla. | Propuesto [F2] |
| RF-UX-008 | Las claves `F-n` y `O-n` que aparecen en cualquier texto se renderizan como enlaces. | Aceptado [F2] |

## Marca y SEO — `RF-UX`

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-UX-040 | **Marca:** los logos de `apps/web/public/` (`logo-horizontal.svg`, `logo-horizontal-negativo.svg`, `logo-icono.svg`, `logo-icono-transparente.svg`) son la única identidad visual. El horizontal va en la cabecera del sidebar y encima de la tarjeta de login y registro; el icono, en el sidebar de solo iconos y en la barra superior móvil. En modo oscuro se usa el negativo sin su fondo (`logo-horizontal-negativo-transparente.svg`). Favicon (`app/favicon.ico`, `app/icon.svg`), `apple-icon.png` e iconos del manifest (`public/icons/`) salen del mismo logo. | Implementado |
| RF-UX-041 | **Metadata y previsualización social:** `metadataBase` desde `NEXT_PUBLIC_SITE_URL`, título con plantilla `%s · Hackboard`, descripción, `canonical`, Open Graph (`en_US`) y tarjeta `summary_large_image` de X. Imagen OG de 1200×630 generada en build (`app/opengraph-image.tsx`) con el logo negativo. Las páginas públicas usan `publicPageMetadata` (`lib/site.ts`) para no perder la imagen OG al sobrescribir `openGraph`. `theme-color` con el morado de marca. | Implementado |
| RF-UX-042 | **Datos estructurados:** JSON-LD (`schema.org`) en todas las páginas con `Organization`, `WebSite` y `SoftwareApplication`, con `inLanguage: "en"`. | Implementado |
| RF-UX-043 | **Indexación:** solo `/`, `/login`, `/signup` y `/privacy` son indexables. `robots.txt` bloquea `/t/`, `/onboarding`, `/oauth/` y `/cli/`, y esas rutas llevan además `noindex, nofollow`. `sitemap.xml` con las rutas públicas y `manifest.webmanifest` con nombre, colores e iconos. | Implementado |
| RF-UX-044 | **`/llms.txt`** ([llmstxt.org](https://llmstxt.org)): qué es Hackboard, qué hace y dónde están sus puntos de entrada públicos (registro, OpenAPI, servidor MCP y discovery de OAuth 2.1), con las URLs de `NEXT_PUBLIC_SITE_URL` y `NEXT_PUBLIC_API_URL`. Está en inglés, como todo el SEO (RNF-UI-013). Nunca incluye datos de equipos. | Implementado |
Rutas: `/login`, `/signup`, `/privacy`, `/onboarding`, `/oauth/consent`, `/t/[teamId]/{home,objectives,features,features/[key],decisions,deadlines,activity,analysis,settings}`.

| Menú | Icono Lucide | Ruta |
|------|--------------|------|
| Inicio | `House` | `home` |
| Objetivos | `Target` | `objectives` |
| Features | `KanbanSquare` | `features` |
| Pros y contras | `Scale` | `decisions` |
| Deadlines | `CalendarClock` | `deadlines` |
| Actividad | `Activity` | `activity` |
| Análisis IA | `Sparkles` | `analysis` |
| Equipo y ajustes | `Settings` | `settings` |

---

## Onboarding — `RF-TEAM`

Objetivo: tener un equipo funcionando **en menos de 2 minutos**.

1. **Registro o login** (email + contraseña, "Continuar con Google" o "Continuar con GitHub").
2. **Perfil** (solo si aún no tiene equipo y no lo ha completado antes): nombre, foto y "Vincular GitHub" si la cuenta no tiene GitHub. Ver RF-TEAM-014.
3. **Elegir:** si ya pertenece a algún equipo, primero puede elegir entrar directamente en uno de ellos; si no, o si quiere otro, "Crear equipo" o "Unirme con código". Al unirse con código se entra directamente en el equipo.
4. **Crear:** nombre del equipo, nombre del hackathon, fecha de inicio (por defecto "ahora", editable, con el aviso "Importaremos los commits de GitHub desde esta fecha") y fecha de fin. La zona horaria se detecta en el navegador. Un solo formulario.
5. **Pegar repo:** el mismo componente de la sección GitHub de ajustes (pegar el repo o instalar la GitHub App). Al vincularlo muestra qué trajo la importación (RF-GH-025). Se puede saltar.
6. **Invitar:** muestra el código `XXXX-XXXX` y un enlace `…/onboarding?code=…` para copiar.
7. Aterrizas en Inicio con un checklist: "Añade 3 objetivos", "Crea features", "Conecta Claude Code".

Arriba se ve en qué paso se está (Perfil · Equipo · Repositorio · Invitar; al unirse, Perfil · Equipo). Los pasos 5 y 6 van en la URL (`/onboarding?team=<id>&step=repo|invite`), para retomarlos al volver de instalar la GitHub App.

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-TEAM-010 | El flujo de crear el equipo tiene como máximo 3 pantallas (crear, repo e invitar) más el perfil, que solo aparece una vez ([ADR-0019](decisiones.md#adr-0019)). Los pasos de repo e invitar se pueden saltar. | Implementado [F1] |
| RF-TEAM-011 | El enlace `…/join?code=` hace login o registro y la unión en un solo paso. | Aceptado [F1] |
| RF-AUTH-010 | Login y registro muestran "Continuar con Google" y "Continuar con GitHub" encima del formulario de email, cada uno con el logo oficial de su proveedor delante del texto (la "G" de Google en sus colores y el GitHub mark en el color del texto). En el perfil se ven los proveedores vinculados y se pueden desvincular (RF-AUTH-009). | Aceptado [F1] |
| RF-AUTH-011 | El pie del sidebar muestra la foto de perfil de Google o GitHub (`avatar_url` de `/me`). Se actualiza en cada login con ese proveedor, así que prevalece la del último con el que se entró; si el proveedor no trae foto se conserva la anterior. Sin foto, o si no carga, se muestran las iniciales. | Implementado [F1] |
| RF-AUTH-012 | Los campos de contraseña de login y registro llevan un botón de ojo a la derecha que alterna entre mostrar y ocultar lo escrito. Empieza oculta; el botón es accesible ("Mostrar contraseña" / "Ocultar contraseña", `aria-pressed`) y no envía el formulario. | Implementado [F1] |
| RF-AUTH-013 | Ajustes tiene una tarjeta "Borrar cuenta" (RF-AUTH-007, RF-SEC-004), al final de la página. Abre un diálogo que explica qué se borra y exige escribir el email de la cuenta para habilitar el botón (no basta con un sí/no). Si el servidor responde `409` (único owner de un equipo con más miembros) el error se muestra en el diálogo; si va bien, se vacía la caché y se vuelve a `/login`. | Implementado [F2] |
| RF-TEAM-012 | Checklist de puesta en marcha en Inicio. Se oculta cuando está completo o si se descarta. | Aceptado [F2] |
| RF-TEAM-014 | **Paso de perfil** al principio del onboarding para quien no tiene equipo: nombre (obligatorio, lo que ya tenga la cuenta), foto del proveedor o iniciales, y "Vincular GitHub" si la cuenta no tiene GitHub (explica que así sus commits se le asignan solos, RF-GH-024). Vincular GitHub añade la identidad a la cuenta de la sesión aunque el email de GitHub sea otro, y vuelve al paso conservando el código de invitación si se llegó con `?code=`; si esa cuenta de GitHub ya es de otro usuario, lo avisa y no la mueve. "Continuar" guarda el nombre y marca el perfil como completado (`profile_completed_at`), así que no vuelve a salir. | Implementado [F1] |
| RF-TEAM-015 | En ajustes, el owner puede cambiar la fecha de inicio y la de fin del hackathon (el resto las ve). Al cambiar el inicio, la API vuelve a importar el histórico de GitHub de todos los repos activos (RF-GH-023), y ajustes lo avisa. | Implementado [F1] |
| RF-TEAM-013 | Al volver a entrar, aterriza directamente en `last_team_id` (RF-AUTH-005), que se actualiza en cada petición de dominio con sesión y al crear o unirse a un equipo. Si no hay uno guardado (p. ej. la cuenta nunca abrió ningún equipo tras esta funcionalidad) pero ya es miembro de alguno, onboarding le deja elegir a cuál entrar en vez de forzarle a crear uno nuevo o unirse con código. | Aceptado [F1] |

**Criterio de aceptación:** un usuario nuevo con cuenta de GitHub crea el equipo, vincula un repo e invita al equipo en menos de 2 minutos, medido en un test de usabilidad con 3 personas.

---

## Inicio

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-UX-020 | Tarjeta de **progreso global**: % de features `done` sobre (`idea` + `in_progress` + `done`) y barra por estado. | Aceptado [F1] |
| RF-UX-021 | Tarjeta de **cuenta atrás** al siguiente milestone con su título y los que vienen después. | Aceptado [F2] |
| RF-UX-022 | **Últimas 10 actividades** con enlace a Actividad. | Aceptado [F3] |
| RF-UX-023 | **Mis features**: las asignadas al usuario que no están en `done` ni `discarded`, ordenadas por deadline. | Aceptado [F2] |
| RF-UX-024 | **Alertas**: las 3 más graves del último análisis y de las alertas deterministas, con enlace a Análisis IA. | Aceptado [F4] |
| RF-UX-025 | **Pulso del equipo**: actividad por miembro en las últimas 3 h (sparkline). Marca en gris a quien lleva más de 2 h sin actividad, **sin** juicios de valor. | Propuesto [F3] |

---

## Objetivos — `RF-OBJ`

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-OBJ-010 | Lista editable en línea (título, prioridad) con un panel lateral para la descripción. | Aceptado [F1] |
| RF-OBJ-011 | Se reordena arrastrando. | Aceptado [F1] |
| RF-OBJ-012 | Cada objetivo muestra un chip con su cobertura del último análisis (cubierto, parcial o sin cubrir) y el número de features vinculadas. | Aceptado [F4] |
| RF-OBJ-013 | "Importar desde el texto del reto": pegas el texto, la IA propone objetivos y el usuario marca cuáles crea. | Aceptado [F4] |
| RF-OBJ-014 | Se pueden archivar objetivos. Los archivados se ocultan tras un toggle. | Aceptado [F1] |

---

## Features (kanban) — `RF-FEAT`

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-FEAT-010 | Cuatro columnas: **Idea**, **En curso**, **Hecha** y **Descartada**. Descartada está plegada por defecto. | Aceptado [F1] |
| RF-FEAT-011 | Arrastrar una tarjeta entre columnas cambia su estado. Dentro de una columna, reordena. La interfaz es optimista y revierte si la API responde con error. | Aceptado [F1] |
| RF-FEAT-012 | La tarjeta muestra la clave `F-n`, el título, los avatares de los asignados, el deadline (en rojo si ha vencido y la tarjeta no está en `done` ni `discarded`), los chips de objetivos, el `score` de pros y contras y el tiempo desde la última actividad. | Aceptado [F1] |
| RF-FEAT-013 | Para asignar, se arrastra el avatar de un miembro desde una barra de miembros hasta la tarjeta, o se usa el selector del detalle. | Aceptado [F2] |
| RF-FEAT-014 | Creación rápida: un input al pie de cada columna (título + Enter). | Aceptado [F1] |
| RF-FEAT-015 | Detalle de la feature (panel lateral o `/features/[key]`): descripción, objetivos, asignados, deadline, ramas vinculadas, sus pros y contras, y su actividad. | Aceptado [F1] |
| RF-FEAT-016 | Al descartar se pide el motivo (opcional). | Aceptado [F2] |
| RF-FEAT-017 | Filtros: persona, objetivo, "sin objetivo" y "sin asignar". | Aceptado [F2] |
| RF-FEAT-018 | En el detalle, un bloque "Cómo vincular trabajo" con el nombre de rama sugerido (`f-12-titulo-en-kebab`) y un botón para copiarlo. Debajo, "Ramas": las ramas con commits de la feature (RF-GH-026), cada una enlazada a Actividad filtrada por esa rama. | Aceptado [F3] |

---

## Pros y contras — `RF-PC`

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-PC-010 | La vista lista las features en `idea` (por defecto) o todas, y al seleccionar una se abre su board. | Aceptado [F2] |
| RF-PC-011 | El board tiene dos columnas, **Pros** y **Contras**. Cada argumento muestra el texto, el autor y un botón de voto con su contador. Un voto por persona y argumento. | Aceptado [F2] |
| RF-PC-012 | Los argumentos se ordenan por votos (descendente) y, en caso de empate, por antigüedad. | Aceptado [F2] |
| RF-PC-013 | Resumen arriba: `score`, número de participantes y botones de decisión: "Pasar a En curso" y "Descartar". | Aceptado [F2] |
| RF-PC-014 | "Pedir a la IA pros y contras": sugiere hasta 3 de cada que el usuario puede añadir. No se añaden solos. | Propuesto [F4] |

---

## Deadlines — `RF-DL`

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-DL-010 | Timeline horizontal desde `hackathon.starts_at` hasta `ends_at`, con una línea de "ahora". | Aceptado [F2] |
| RF-DL-011 | Los milestones aparecen como marcadores verticales con etiqueta. Las features con deadline, como puntos o barras por carril (un carril por asignado, más "sin asignar"). | Aceptado [F2] |
| RF-DL-012 | Una feature va **tarde** si `deadline < ahora` y su estado no es `done` ni `discarded`. Se marca en rojo. Va **en riesgo** si le quedan menos de 2 h y sigue en `idea`, y se marca en ámbar. | Aceptado [F2] |
| RF-DL-013 | Vista de lista alternativa, agrupada por "Vencidas", "Próximas 6 h" y "Más adelante". | Aceptado [F2] |
| RF-DL-014 | Al crear el equipo se proponen milestones por defecto (entrega = `ends_at`), editables. | Aceptado [F2] |

---

## Actividad — `RF-ACT`

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-ACT-010 | Feed cronológico inverso con scroll infinito. Cada fila muestra el icono de la fuente (GitHub, Claude Code, MCP o sistema), la foto del actor (la de Google o GitHub si es miembro; si no, o si no tiene, el avatar de GitHub de su login; sin ninguna, o si no carga, sus iniciales), el actor, un texto ("hizo commit en `f-12-login`: …"), las stats (+/−, número de ficheros), la hora relativa y el chip de feature. | Aceptado [F3] |
| RF-ACT-011 | Filtros: persona, feature, fuente, "sin atribuir" y "sugeridas". Se reflejan en la URL. También por rama (`?branch=`, RF-GH-026): se llega pulsando una etiqueta de rama y se quita con "Quitar filtro". | Aceptado [F3] |
| RF-ACT-012 | Chip de atribución: **confirmada** (sólido), **sugerida** (borde discontinuo, con ✓ y ✗ en línea y el motivo en un tooltip) o **sin atribuir** (botón "Asignar a…"). | Aceptado [F3] |
| RF-ACT-013 | Vista **"Quién hizo qué"**: matriz de personas × features con el número de eventos y el último, en una ventana configurable (3 h, 12 h o todo). | Aceptado [F3] |
| RF-ACT-014 | Los eventos consecutivos de un mismo actor en la misma rama en menos de 10 min se agrupan ("Ana hizo 4 commits en f-12") y se pueden expandir. | Aceptado [F3] |
| RF-ACT-015 | Los eventos de Claude Code nunca muestran texto de prompts con el nivel `metadata`. Muestran "Claude Code session · 6 files edited on `f-12-login`". | Aceptado [F5] |
| RF-ACT-016 | Selección múltiple para confirmar o reasignar en bloque. | Aceptado [F4] |
| RF-ACT-018 | **Autores sin vincular y "Son míos".** Filtro "Autores sin vincular" con la lista de esos autores (login, email, número de eventos) y un botón "Son míos" por autor. Casillas en los eventos de GitHub para seleccionar varios y una barra con "Son míos", "No son míos" y, para owners, "Asignar a…" un miembro. La casilla "Asignarme también los futuros de este autor" (para owners, "Asignar también…") va marcada por defecto. Un miembro solo puede seleccionar eventos sin usuario o suyos; un owner, cualquiera de GitHub. Nadie puede seleccionar sus propios eventos cuyo login de GitHub es el de su cuenta: son suyos seguro, así que ni "No son míos" ni "Asignar a…" otro miembro (la API los omite). Los eventos asignados a mano muestran un discreto "asignado a mano" junto al actor. Ver [07](07-integracion-github.md#mapeo-de-autores) y [ADR-0018](decisiones.md#adr-0018). | Implementado |
| RF-ACT-017 | Los eventos con `via` muestran una etiqueta "vía API" o "vía MCP · <cliente>" junto al actor, y el nombre del token en un tooltip. Filtro "Hecho por agentes/API" y filtro por token (RF-API-008). | Aceptado [F3] |

---

## Análisis IA — `RF-AI`

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-AI-010 | **Matriz objetivos × features.** Las filas son objetivos y las columnas, features activas. Cada celda indica la relación (vinculada por humano o por la IA). A la izquierda, el estado de cobertura de cada objetivo (cubierto, parcial o sin cubrir) con su justificación en un tooltip. | Aceptado [F4] |
| RF-AI-011 | **"Esto sobra":** lista de `orphan_features` con su justificación y acciones ("Vincular a objetivo…" y "Descartar"). | Aceptado [F4] |
| RF-AI-012 | **Huecos:** `gaps` con el botón "Crear feature" (prerrellena el título). | Aceptado [F4] |
| RF-AI-013 | **Alertas:** riesgos ordenados por severidad, combinando los de la IA y los deterministas. Cada alerta indica su origen (regla o IA). | Aceptado [F4] |
| RF-AI-014 | Cabecera con la fecha del análisis ("hace 12 min"), el modelo, el botón "Analizar ahora" (con la cuota restante) y el estado si hay un análisis en curso. | Aceptado [F4] |
| RF-AI-015 | **Evolución:** gráfico de % de objetivos cubiertos a lo largo del tiempo, a partir de los snapshots. | Aceptado [F4] |
| RF-AI-016 | Si `settings.ai_enabled = false`, la pantalla solo muestra las alertas deterministas y un CTA para activar la IA. | Aceptado [F4] |

---

## Equipo y ajustes

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-TEAM-020 | **Miembros:** avatar (su foto de Google o GitHub; sin ella, o si no carga, sus iniciales), nombre, rol, login de GitHub, estado de Claude Code (no conectado, conectado, pausado) y nivel de privacidad. El owner puede cambiar roles y expulsar. | Aceptado [F1] |
| RF-TEAM-021 | **Código de equipo:** se muestra con botones de copiar y copiar enlace. El owner puede regenerarlo. | Aceptado [F1] |
| RF-TEAM-022 | **Hackathon:** nombre, fechas, zona horaria y texto del reto. | Aceptado [F1] |
| RF-GH-010 | **GitHub:** repos vinculados, botón "Añadir repo" (pegar URL o elegir de la lista) y estado de la instalación. Indica si el último webhook tuvo éxito. | Aceptado [F3] |
| RF-CC-010 | **Claude Code (sección personal):** instrucciones en 2 pasos (`npm i -g hackboard` y `hackboard init --team XXXX-XXXX`), estado, nivel de privacidad, botones de pausar, desconectar y "desconectar y borrar mis eventos". Explica en lenguaje llano qué se envía y qué no. | Aceptado [F5] |
| RF-API-020 | **API y MCP (sección personal):** lista de mis tokens (nombre, prefijo, scopes, caducidad y último uso) con botón de revocar. "Nuevo token": nombre, preset (`observe` por defecto, `agent`, `full` o personalizado) y caducidad; el token se muestra **una sola vez** con botón de copiar y un aviso de no subirlo al repo. Enlace a la documentación OpenAPI. Un owner ve además los tokens de todo el equipo y puede revocarlos. | Aceptado [F2] |
| RF-MCP-010 | **MCP (dentro de API y MCP):** el comando `claude mcp add …` listo para copiar, con el token de miembro (lectura + progreso) o con un PAT recién creado (lo que permita su preset). Explica qué podrá ver y hacer el agente con cada opción. | Aceptado [F5] |
| RF-API-021 | **Apps conectadas (sección personal):** conexiones OAuth (claude.ai, apps de terceros) con cliente, equipo, scopes, fecha y último uso, y botón de revocar. Un owner ve las de todo el equipo y puede revocarlas. | Aceptado [F6] |
| RF-API-022 | **Pantalla de consentimiento** (`/oauth/consent`): si no hay sesión, primero login con Google, GitHub o contraseña. Después muestra el nombre de la app (con "no verificada" si se registró sola), el dominio al que volverá, un selector de equipo, los permisos agrupados en lenguaje llano ("Ver el tablero", "Crear y mover features"…) con los presets, y los botones Permitir y Cancelar. Un aviso recuerda que la app actuará en tu nombre. | Aceptado [F6] |
| RF-API-023 | **Integraciones (owner):** tokens de integración (crear, rotar, revocar, último uso) y webhooks salientes (URL, eventos, estado, secreto mostrado una vez, botón Probar, últimas entregas con reenvío). | Aceptado [F6] |
| RF-MCP-011 | **claude.ai (dentro de API y MCP):** la URL del MCP lista para copiar y los pasos para añadirla como *custom connector* en claude.ai, con enlace a Apps conectadas. | Aceptado [F6] |
| RF-AI-020 | **IA (owner):** activar o desactivar el análisis y la atribución por IA, y fijar la frecuencia (dentro de lo que permite el plan). | Aceptado [F4] |
| RF-AI-021 | **IA (Gemini) — clave personal (sección personal, cualquier miembro):** estado (configurada o no), campo para pegar o sustituir la clave y botón para quitarla. Nunca se vuelve a mostrar en claro. Explica para qué se usa (las acciones propias, y además lo automático del equipo si eres owner). | Aceptado [F4] |
