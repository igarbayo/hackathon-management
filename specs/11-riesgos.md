# 11 · Riesgos

> **Estado de implementación:** No aplica (registro de riesgos) · **Última actualización:** 2026-09-22

Probabilidad (P) e impacto (I): Alta / Media / Baja. Hay que revisar los riesgos al cerrar cada fase.

| # | Riesgo | P | I | Mitigación | Dueño / estado |
|---|--------|---|---|------------|----------------|
| R1 | **Privacidad de los eventos de Claude.** La gente no instala el CLI si cree que la vigila. | A | A | Opt-in por persona, `metadata` por defecto, filtrado de repos en local, "ver lo que se ha enviado", borrado en un clic y texto claro en la aprobación ([09](09-privacidad-seguridad.md)). | Abierto |
| R2 | **Ruido en la atribución.** Si nadie usa `F-12`, la IA acierta a medias. | A | A | Sugerir nombres de rama en el detalle y en el MCP, aprendizaje de ramas (capa 2), heurística de "única feature en curso", confirmar con un clic y medir la tasa de rechazo (RNF-ATR-001). | Abierto |
| R3 | **Coste de tokens del análisis.** | M | M | Análisis solo si cambia `input_hash`, solo durante el hackathon, intervalo mínimo por plan, cuota de manuales, contexto limitado a ~30.000 caracteres y registro de `usage`. | Abierto |
| R4 | **Adopción en caliente.** Nadie configura algo que tarde más de 2 minutos. | A | A | Onboarding de 3 pantallas, pasos opcionales, pegar el repo, device flow sin copiar tokens y métrica p50 < 2 min. | Abierto |
| R5 | **Permisos de la GitHub App en orgs.** La instalación necesita la aprobación de un admin. | M | A | Explicar la situación en la interfaz y enlazar la aprobación. Mientras tanto, el equipo puede usar Claude Code y el kanban. | Abierto |
| R6 | **Cambios en los hooks de Claude Code** (nombres o campos). | M | M | Aislar el parseo en un módulo, tests con fixtures de JSON reales, el hook no falla nunca (siempre sale con 0) y versión del esquema de ingesta. | Abierto |
| R7 | **Alucinaciones de la IA** (claves inexistentes o afirmaciones sin base). | M | M | Salida estructurada, posvalidación de claves, justificación obligatoria, alertas deterministas en paralelo y dataset de evaluación. | Abierto |
| R8 | **Modelo relacional sobre Mongo** (memberships y asignaciones). | B | M | Referencias con índices, invariantes en servicios y escala pequeña (equipos de ≤ 10 personas). Ver [ADR-0001](decisiones.md#adr-0001). | Aceptado |
| R9 | **Percepción de vigilancia entre compañeros** (el pulso del equipo, `member_idle`). | M | M | Sin rankings ni juicios. `member_idle` queda en [ABIERTO] y es solo para owners. | Abierto |
| R10 | **Latencia de los hooks** que hace más lento Claude Code. | M | A | Presupuesto < 100 ms, cola local, flush detached y binario global en lugar de `npx`. | Abierto |
| R11 | **Un agente desbocado o manipulado** (inyección de prompts desde una descripción o un commit) hace muchos cambios en el tablero. | M | M | Preset `observar` por defecto, scopes, sin herramientas destructivas, 30 escrituras por minuto, marca `via` en el feed, filtro "Hecho por agentes" y revocación inmediata (RNF-SEC-013). | Abierto |
| R13 | **Phishing de consentimiento OAuth:** una app maliciosa se registra con un nombre engañoso ("Hackboard oficial") y pide permisos de escritura. | B | A | "No verificada" en toda app de registro dinámico, dominio de retorno visible, preset `observar` propuesto por defecto, Apps conectadas con revocación, sin permisos de administración y rate limit al registro. | Abierto |
| R14 | **Un webhook saliente filtra datos** a un destino equivocado o se usa para SSRF. | B | M | Solo owners, nunca eventos de Claude Code ni de MCP, firma, protección SSRF y registro de entregas. | Abierto |
| R12 | **Fuga de un PAT** (pegado en `.mcp.json`, en un README o en un log). | M | A | Caducidad obligatoria, prefijo `hb_pat_` detectable por escaneo de secretos, aviso al crearlo, comando `claude mcp add` sin `--scope project`, sin permisos de administración y revocación en un clic. | Abierto |
