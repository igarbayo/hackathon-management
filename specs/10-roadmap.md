# 10 · Roadmap

Cada fase dura aproximadamente 1 semana. Una fase no está terminada hasta que cumple su **Definition of Done (DoD)**. Además de los criterios de cada fase, todas deben cumplir el DoD común.

**DoD común:**
- Los requisitos de la fase están en estado `Implementado` en estas specs.
- Hay tests: modelos y servicios (RSpec), endpoints (request specs, incluido el test de aislamiento RNF-SEC-001) y un flujo e2e (Playwright) por pantalla nueva.
- Está desplegado en staging.
- El CHANGELOG de specs está actualizado.

## Fase 1 · Esqueleto

**Objetivo:** un equipo puede registrarse, crear o unirse a un equipo y gestionar objetivos y features en un kanban.

- Monorepo, `docker-compose`, CI (lint + tests + escaneo de secretos y dependencias).
- Rails 8 API + Mongoid + Sidekiq (sin jobs de negocio aún). Next.js + Tailwind + shadcn/ui.
- RF-AUTH-001…006, 008, 010 (incluidos el login con GitHub, que ya usa la GitHub App, y el login con Google). RNF-SEC-015 en la parte de login.
- RF-TEAM-001…006, 008, 010, 011, 020–022.
- Layout RF-UX-001, 002, 004, 005, 006.
- Objetivos RF-OBJ-001…004, 010, 011, 014.
- Features RF-FEAT-001…006, 010–012, 014, 015.
- Inicio con progreso global (RF-UX-020).
- RNF-SEC-001…005, 009–011. RNF-OPS-004…006.
- [ABIERTO] Elegir el hosting.

**DoD específico:** dos personas en dos navegadores crean un equipo, se unen con el código, crean 3 objetivos y 5 features y las mueven por el kanban sin conflictos.

## Fase 2 · Colaboración

**Objetivo:** decidir qué se construye y controlar el tiempo.

- Pros y contras RF-PC-001…004, 010–013.
- Milestones y timeline RF-DL-001…003, 010–014. Cuenta atrás RF-UX-003, 021.
- Asignaciones con drag-and-drop RF-FEAT-013, 016, 017. Mis features RF-UX-023.
- Gestión de miembros RF-TEAM-007, 009, 012. RF-AUTH-007, 009. RF-SEC-003, 004.
- Enlaces de claves RF-UX-008.
- **Acceso programático por API:** tokens de acceso personales y scopes RF-API-001…005, 007, 020. Trazabilidad RF-API-006. RNF-API-001…003. RNF-SEC-014. RF-SEC-006.

**DoD específico:** en la timeline, una feature con deadline vencido aparece en rojo, y un milestone a menos de 1 h pone la cuenta atrás en rojo. Con un PAT `agente`, un `curl` crea una feature y la mueve a `in_progress`; con un PAT `observar`, el mismo `curl` recibe `403 insufficient_scope`.

## Fase 3 · GitHub

**Objetivo:** ver quién hizo qué a partir de GitHub, con atribución por convención.

- GitHub App (configuración en dev y staging). RF-GH-001…006, 010, 020–024.
- Webhooks, normalización y stats de commits. RNF-GH-001…003. RNF-SEC-006.
- Feed de actividad RF-ACT-001, 002, 010–014. Inicio: últimas actividades (RF-UX-022).
- Atribución, capas 1 y 2 (RF-ATR-001, 002) y acciones humanas (RF-ATR-004). RF-FEAT-018.
- RNF-OPS-001, 003, 007.
- Etiqueta "vía API/MCP" en el feed RF-ACT-017 y "Ver lo que ha hecho" cada token RF-API-008.

**DoD específico:** hacer push de un commit con `F-3` en una rama `f-3-algo` lo muestra en el feed atribuido a F-3 en menos de 30 s, y los commits siguientes en esa rama sin clave también quedan atribuidos a F-3.

## Fase 4 · IA

**Objetivo:** saber si se está construyendo lo que pide el reto.

- `Ai::Provider` + `Ai::Gemini`. RNF-AI-001, 002 (dataset de evaluación).
- Análisis de cobertura RF-AI-001…004, 010–016, 020, 030. Alertas deterministas.
- Atribución sugerida RF-ATR-003, 005, RNF-ATR-001. Acciones en bloque RF-ACT-016.
- Importar objetivos RF-OBJ-005, 013. Chips de cobertura RF-OBJ-012. Alertas en Inicio RF-UX-024.
- RNF-SEC-007, 008.
- Resolver [ABIERTO]: modelo de Gemini, cuotas de tokens y autoconfirmación.

**DoD específico:** en el dataset de evaluación, ≥ 80 % de concordancia en el estado de cobertura. Un análisis en un equipo de 10 objetivos y 30 features termina en < 60 s.

## Fase 5 · Claude Code

**Objetivo:** que la actividad en Claude Code aparezca en el feed sin fricción y respetando la privacidad.

- CLI `hackboard`: RF-CC-020…026, RNF-CC-001. Publicación en npm (RNF-SEC-012).
- Device flow e ingesta RF-CC-001…006. RNF-OPS-002.
- Ajustes RF-CC-010. Derechos RF-SEC-001, 002. Visualización RF-ACT-015.
- Servidor MCP: RF-MCP-001…004, 010. RNF-MCP-001. RNF-SEC-013.
- Resolver [ABIERTO]: el modo `summaries` (opción A o B).

**DoD específico:** con el MCP registrado con un PAT `agente`, Claude Code responde "¿qué me toca?" con `get_team_status`, se asigna una feature y la mueve a `in_progress`, y el cambio aparece en el feed como "vía MCP". En macOS y Windows, `hackboard init` → editar un fichero con Claude Code en una rama `f-5-x` → el evento aparece en el feed atribuido a F-5 en < 60 s. Un repo no vinculado no genera tráfico de red (verificado con un proxy).

## Fase 6 · Integraciones

**Objetivo:** conectar Hackboard con claude.ai y con otras apps sin copiar tokens a mano.

- Servidor de autorización OAuth 2.1: RF-API-010, 012. Apps conectadas y consentimiento RF-API-021, 022. RNF-SEC-015, RNF-API-004.
- claude.ai como connector: RF-MCP-020, 011.
- Tokens de integración de equipo RF-API-011 y webhooks salientes RF-API-009. Pantalla de Integraciones RF-API-023. RNF-SEC-016.

**DoD específico:** en claude.ai se añade la URL del MCP como connector, el usuario entra con Google, aprueba el preset `observar` y Claude responde en el chat "¿cómo va el equipo?" con datos reales; al revocarlo en "Apps conectadas", la siguiente llamada falla con `401`. Un webhook a un receptor de pruebas recibe `feature.status_changed` firmado en < 30 s tras mover una tarjeta, y un webhook apuntado a `http://169.254.169.254` se rechaza.

## Después del MVP (backlog)

- Tiempo real con ActionCable.
- Vista de solo lectura para mentores y jueces.
- Sugerencias de pros y contras con IA (RF-PC-014).
- Buscador global (RF-UX-007).
- Plan de pago y facturación.
