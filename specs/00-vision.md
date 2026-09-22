# 00 · Visión y alcance

## Problema

Durante un hackathon, un equipo de 2 a 6 personas trabaja con muy poco tiempo y mucha presión. Suelen fallar tres cosas:

1. **Se pierde de vista el reto.** Se construyen features vistosas que no puntúan y se dejan sin cubrir objetivos que sí puntúan.
2. **Nadie sabe quién está con qué.** El trabajo se reparte de palabra y se duplica o se queda sin dueño.
3. **Los deadlines llegan por sorpresa.** El checkpoint, la demo y la entrega se descubren tarde.

Las herramientas genéricas (Jira, Trello, Notion) exigen actualizar el estado a mano, y en un hackathon nadie lo hace. Hackboard **deduce el estado de la actividad real** (commits, PRs y sesiones de Claude Code) y lo contrasta con los objetivos del reto.

## Usuarios

| Perfil | Necesidad principal |
|--------|--------------------|
| **Owner del equipo** (quien crea el equipo) | Configurar en menos de 2 minutos, repartir el trabajo y ver si se cubre el reto |
| **Miembro** | Saber qué le toca, cuándo vence y apuntarse a features sin fricción |
| **Mentor o juez** (futuro, fuera de alcance del MVP) | Ver el progreso de un equipo en modo lectura |

## Propuesta de valor

- **Onboarding en 2 minutos:** crear el equipo, pegar el repo y listo.
- **Quién hizo qué sin reportarlo a mano:** GitHub y Claude Code alimentan el feed solos.
- **"¿Estamos construyendo lo que pide el reto?"**: la IA responde con la matriz de objetivos × features, lo que sobra y las alertas.

## Principios de producto

1. **Cero trabajo administrativo.** Si algo se puede inferir, se infiere. Si la inferencia no es segura, se propone y un humano la confirma con un clic.
2. **Privacidad por defecto.** Integrar Claude Code es opcional y se decide persona a persona. Por defecto solo se guardan metadatos, nunca el texto de los prompts ni código.
3. **El tiempo es la unidad principal.** Todas las pantallas dicen cuánto queda.
4. **La IA propone y el humano decide.** La IA interna (Gemini) nunca cambia estados, asignaciones ni atribuciones confirmadas. Los agentes externos (por API o MCP) sí pueden, pero solo con un token que su dueño ha creado con esos permisos, y cada cambio queda marcado en el feed ([12](12-acceso-programatico.md), [ADR-0010](decisiones.md#adr-0010)).
5. **Lo determinista va antes que la IA.** Las alertas que se pueden calcular con reglas (un objetivo sin features, una feature vencida) no dependen del modelo.
6. **Abierto a agentes y a otras apps.** Lo que se ve en la web se puede leer por API y MCP, y casi todo se puede escribir, siempre autorizado y en nombre de un miembro.

## Alcance del MVP

Incluye: autenticación, equipos con código de unión, objetivos, features en kanban, pros y contras con votos, milestones y timeline, GitHub App con feed de actividad, atribución en tres capas, análisis con Gemini, CLI de hooks para Claude Code, API con tokens de acceso personales, servidor MCP de lectura y escritura, login con Google y GitHub y, tras el MVP (F6), OAuth 2.1 con claude.ai como connector, tokens de integración y webhooks salientes.

## No-objetivos (por ahora)

- Leer conversaciones de claude.ai: no hay una API pública para ello. Con el connector, Claude consulta y actualiza el tablero, pero Hackboard no ve el chat.
- Guardar diffs o código fuente.
- Integraciones con GitLab o Bitbucket.
- Chat interno, videollamadas o notificaciones push al móvil.
- Vistas para jueces u organizadores de hackathon. [ABIERTO] Podría ser una línea de negocio futura.
- Facturación. El plan gratuito se limita por cuotas, y el cobro no está en el MVP.

## Métricas de éxito

| Métrica | Objetivo |
|---------|----------|
| Tiempo desde el registro hasta el primer evento de GitHub en el feed | p50 < 2 min |
| % de eventos atribuidos a una feature (confirmados o sugeridos) | > 70 % |
| % de sugerencias de la IA aceptadas | > 60 % |
| % de miembros que activan Claude Code, en equipos que lo usan | > 50 % |
| Equipos que abren el análisis de IA al menos una vez por hackathon | > 60 % |

## Glosario

| Término | Definición |
|---------|------------|
| **Equipo** | Grupo de personas que participa en un hackathon. Tiene un único hackathon asociado. |
| **Código de equipo** | Código corto (p. ej. `K7Q2-M9XA`) para unirse a un equipo. |
| **Objetivo** | Algo que el reto (o el propio equipo) pide conseguir. Es la base del análisis. Clave `O-n`. |
| **Feature** | Unidad de trabajo del equipo. Clave `F-n`, única dentro del equipo. |
| **Milestone** | Deadline global del hackathon: checkpoint, demo, entrega o personalizado. |
| **Evento de actividad** | Algo que ha pasado en GitHub, Claude Code o MCP: commit, PR, edición de fichero, reporte de progreso… |
| **Atribución** | Relación entre un evento y una feature, con método (convención, rama, IA o manual) y estado (confirmada, sugerida o rechazada). |
| **Convención** | Escribir `F-12` en el nombre de la rama o en el mensaje del commit. |
| **Snapshot de análisis** | Resultado guardado de una ejecución del análisis con IA (`AiAnalysis`). |
| **Token de miembro** | Credencial por persona y equipo que crea `hackboard init` y que usan el CLI y el MCP básico (`hb_mt_`). |
| **Token de acceso personal (PAT)** | Credencial con scopes que un miembro crea en ajustes para que un agente o una app use la API o el MCP en su nombre (`hb_pat_`). |
| **Scope** | Permiso concreto de un token (`read`, `features:write`…). Nunca supera lo que permite el rol del miembro. |
