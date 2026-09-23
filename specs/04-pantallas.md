# 04 · Pantallas y requisitos funcionales

> **Estado de implementación:** Implementada · **Última actualización:** 2026-09-23

## Layout general — `RF-UX`

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-UX-001 | Menú lateral fijo con el estilo del sistema de diseño F0 de Factorial ([13](13-sistema-diseno.md)), iconos de Lucide y texto. Se colapsa a solo iconos en pantallas < 1024 px y pasa a un drawer en < 768 px. | Aceptado [F1] |
| RF-UX-002 | Arriba del menú: selector de equipo (si el usuario tiene más de uno) y nombre del hackathon. | Aceptado [F1] |
| RF-UX-003 | Barra superior con una **cuenta atrás persistente** al siguiente milestone. Cambia a ámbar a menos de 3 h y a rojo a menos de 1 h. | Aceptado [F2] |
| RF-UX-004 | Todas las fechas se muestran en la zona horaria del hackathon e indican la zona. | Aceptado [F1] |
| RF-UX-005 | Todas las pantallas tienen estados de *cargando* (skeleton), *vacío* (con un CTA para crear lo primero) y *error* (con reintento). | Aceptado [F1] |
| RF-UX-006 | Modo claro y oscuro según el sistema, con un interruptor manual. | Aceptado [F1] |
| RF-UX-007 | Buscador global `Ctrl/Cmd+K`: salta a una feature por clave o título, o a una pantalla. | Propuesto [F2] |
| RF-UX-008 | Las claves `F-n` y `O-n` que aparecen en cualquier texto se renderizan como enlaces. | Aceptado [F2] |

Rutas: `/login`, `/signup`, `/onboarding`, `/oauth/consent`, `/t/[teamId]/{home,objectives,features,features/[key],decisions,deadlines,activity,analysis,settings}`.

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
2. **Elegir:** si ya pertenece a algún equipo, primero puede elegir entrar directamente en uno de ellos; si no, o si quiere otro, "Crear equipo" o "Unirme con código".
3. **Crear:** nombre del equipo, nombre del hackathon y fecha de fin (el inicio es "ahora" por defecto y la zona horaria se detecta en el navegador). Un solo formulario.
4. **Pegar repo:** un campo "URL del repositorio" con un botón que instala la GitHub App. Se puede saltar.
5. **Invitar:** muestra el código `XXXX-XXXX` y un enlace `…/join?code=…` para copiar.
6. Aterrizas en Inicio con un checklist: "Añade 3 objetivos", "Crea features", "Conecta Claude Code".

| ID | Requisito | Estado |
|----|-----------|--------|
| RF-TEAM-010 | El flujo de crear el equipo tiene como máximo 3 pantallas y los pasos 4 y 5 se pueden saltar. | Aceptado [F1] |
| RF-TEAM-011 | El enlace `…/join?code=` hace login o registro y la unión en un solo paso. | Aceptado [F1] |
| RF-AUTH-010 | Login y registro muestran "Continuar con Google" y "Continuar con GitHub" encima del formulario de email. En el perfil se ven los proveedores vinculados y se pueden desvincular (RF-AUTH-009). | Aceptado [F1] |
| RF-AUTH-011 | El pie del sidebar muestra la foto de perfil de Google o GitHub (`avatar_url` de `/me`). Se actualiza en cada login con ese proveedor, así que prevalece la del último con el que se entró; si el proveedor no trae foto se conserva la anterior. Sin foto, o si no carga, se muestran las iniciales. | Implementado [F1] |
| RF-TEAM-012 | Checklist de puesta en marcha en Inicio. Se oculta cuando está completo o si se descarta. | Aceptado [F2] |
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
| RF-FEAT-018 | En el detalle, un bloque "Cómo vincular trabajo" con el nombre de rama sugerido (`f-12-titulo-en-kebab`) y un botón para copiarlo. | Aceptado [F3] |

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
| RF-ACT-010 | Feed cronológico inverso con scroll infinito. Cada fila muestra el icono de la fuente (GitHub, Claude Code, MCP o sistema), el actor, un texto ("hizo commit en `f-12-login`: …"), las stats (+/−, número de ficheros), la hora relativa y el chip de feature. | Aceptado [F3] |
| RF-ACT-011 | Filtros: persona, feature, fuente, "sin atribuir" y "sugeridas". Se reflejan en la URL. | Aceptado [F3] |
| RF-ACT-012 | Chip de atribución: **confirmada** (sólido), **sugerida** (borde discontinuo, con ✓ y ✗ en línea y el motivo en un tooltip) o **sin atribuir** (botón "Asignar a…"). | Aceptado [F3] |
| RF-ACT-013 | Vista **"Quién hizo qué"**: matriz de personas × features con el número de eventos y el último, en una ventana configurable (3 h, 12 h o todo). | Aceptado [F3] |
| RF-ACT-014 | Los eventos consecutivos de un mismo actor en la misma rama en menos de 10 min se agrupan ("Ana hizo 4 commits en f-12") y se pueden expandir. | Aceptado [F3] |
| RF-ACT-015 | Los eventos de Claude Code nunca muestran texto de prompts con el nivel `metadata`. Muestran "Sesión de Claude Code · 6 ficheros editados en `f-12-login`". | Aceptado [F5] |
| RF-ACT-016 | Selección múltiple para confirmar o reasignar en bloque. | Aceptado [F4] |
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
| RF-TEAM-020 | **Miembros:** avatar, nombre, rol, login de GitHub, estado de Claude Code (no conectado, conectado, pausado) y nivel de privacidad. El owner puede cambiar roles y expulsar. | Aceptado [F1] |
| RF-TEAM-021 | **Código de equipo:** se muestra con botones de copiar y copiar enlace. El owner puede regenerarlo. | Aceptado [F1] |
| RF-TEAM-022 | **Hackathon:** nombre, fechas, zona horaria y texto del reto. | Aceptado [F1] |
| RF-GH-010 | **GitHub:** repos vinculados, botón "Añadir repo" (pegar URL o elegir de la lista) y estado de la instalación. Indica si el último webhook tuvo éxito. | Aceptado [F3] |
| RF-CC-010 | **Claude Code (sección personal):** instrucciones en 2 pasos (`npm i -g hackboard` y `hackboard init --team XXXX-XXXX`), estado, nivel de privacidad, botones de pausar, desconectar y "desconectar y borrar mis eventos". Explica en lenguaje llano qué se envía y qué no. | Aceptado [F5] |
| RF-API-020 | **API y MCP (sección personal):** lista de mis tokens (nombre, prefijo, scopes, caducidad y último uso) con botón de revocar. "Nuevo token": nombre, preset (`observar` por defecto, `agente`, `completo` o personalizado) y caducidad; el token se muestra **una sola vez** con botón de copiar y un aviso de no subirlo al repo. Enlace a la documentación OpenAPI. Un owner ve además los tokens de todo el equipo y puede revocarlos. | Aceptado [F2] |
| RF-MCP-010 | **MCP (dentro de API y MCP):** el comando `claude mcp add …` listo para copiar, con el token de miembro (lectura + progreso) o con un PAT recién creado (lo que permita su preset). Explica qué podrá ver y hacer el agente con cada opción. | Aceptado [F5] |
| RF-API-021 | **Apps conectadas (sección personal):** conexiones OAuth (claude.ai, apps de terceros) con cliente, equipo, scopes, fecha y último uso, y botón de revocar. Un owner ve las de todo el equipo y puede revocarlas. | Aceptado [F6] |
| RF-API-022 | **Pantalla de consentimiento** (`/oauth/consent`): si no hay sesión, primero login con Google, GitHub o contraseña. Después muestra el nombre de la app (con "no verificada" si se registró sola), el dominio al que volverá, un selector de equipo, los permisos agrupados en lenguaje llano ("Ver el tablero", "Crear y mover features"…) con los presets, y los botones Permitir y Cancelar. Un aviso recuerda que la app actuará en tu nombre. | Aceptado [F6] |
| RF-API-023 | **Integraciones (owner):** tokens de integración (crear, rotar, revocar, último uso) y webhooks salientes (URL, eventos, estado, secreto mostrado una vez, botón Probar, últimas entregas con reenvío). | Aceptado [F6] |
| RF-MCP-011 | **claude.ai (dentro de API y MCP):** la URL del MCP lista para copiar y los pasos para añadirla como *custom connector* en claude.ai, con enlace a Apps conectadas. | Aceptado [F6] |
| RF-AI-020 | **IA (owner):** activar o desactivar el análisis y la atribución por IA, y fijar la frecuencia (dentro de lo que permite el plan). | Aceptado [F4] |
| RF-AI-021 | **IA (Gemini) — clave personal (sección personal, cualquier miembro):** estado (configurada o no), campo para pegar o sustituir la clave y botón para quitarla. Nunca se vuelve a mostrar en claro. Explica para qué se usa (las acciones propias, y además lo automático del equipo si eres owner). | Aceptado [F4] |
