# Especificaciones — Hackboard (nombre provisional)

> Esta carpeta es la **fuente de verdad** del producto. Si el código y la spec no coinciden, uno de los dos tiene un bug, y se arregla en el mismo PR.

Hackboard es una herramienta de gestión para equipos de hackathon. Sirve para definir objetivos y features, decidir con pros y contras, controlar deadlines y ver **quién hizo qué** a partir de la actividad real en GitHub y en Claude Code. Una IA (Gemini) analiza si lo que se construye cubre lo que pide el reto. Todo es accesible también por API y por MCP, para que los agentes y las apps externas vean y modifiquen el tablero con permisos acotados.

## Índice

| # | Documento | Contenido | Estado |
|---|-----------|-----------|--------|
| 00 | [Visión y alcance](00-vision.md) | Problema, usuarios, principios, no-objetivos, glosario | Aceptado |
| 01 | [Arquitectura](01-arquitectura.md) | Componentes, stack, estructura del repo, entornos, configuración | Aceptado |
| 02 | [Modelo de datos](02-modelo-datos.md) | Colecciones Mongoid, campos, índices e invariantes | Aceptado |
| 03 | [API](03-api.md) | Endpoints REST, autenticación, errores, webhooks e ingesta | Aceptado |
| 04 | [Pantallas](04-pantallas.md) | Requisitos funcionales por pantalla y criterios de aceptación | Aceptado |
| 05 | [Atribución de trabajo](05-atribucion.md) | Cómo se asigna la actividad a features en tres capas | Aceptado |
| 06 | [Análisis con IA](06-analisis-ia.md) | Job de análisis con Gemini, contexto, esquema de salida y costes | Aceptado |
| 07 | [Integración GitHub](07-integracion-github.md) | GitHub App, instalación, webhooks y mapeo de autores | Aceptado |
| 08 | [Integración Claude Code](08-integracion-claude-code.md) | CLI de hooks e ingesta | Aceptado |
| 09 | [Privacidad y seguridad](09-privacidad-seguridad.md) | Datos que se guardan, opt-in, tokens, aislamiento y retención | Aceptado |
| 10 | [Roadmap](10-roadmap.md) | Fases (F1–F6), entregables y Definition of Done | Aceptado |
| 11 | [Riesgos](11-riesgos.md) | Riesgos vivos y mitigaciones | Aceptado |
| 12 | [Acceso programático](12-acceso-programatico.md) | API con tokens de acceso personales, scopes, servidor MCP de lectura y escritura, OAuth 2.1 (claude.ai como connector), tokens de integración, webhooks salientes y trazabilidad | Aceptado |
| — | [Decisiones (ADR)](decisiones.md) | Registro de decisiones de arquitectura | Vivo |
| — | [CHANGELOG](CHANGELOG.md) | Historial de cambios de estas specs | Vivo |

## Reglas de mantenimiento

1. **El mismo PR actualiza la spec.** Hay que actualizar la spec afectada en el mismo PR cuando cambia cualquiera de estas cosas: comportamiento visible, modelo de datos, contrato de la API, integraciones, prompts o esquemas de IA, o tratamiento de datos personales.
2. **Los IDs de requisito son estables.** Tienen el formato `RF-<ÁREA>-<NNN>` (funcional) o `RNF-<ÁREA>-<NNN>` (no funcional). Un ID nunca se reutiliza. Un requisito eliminado se marca como `Retirado` y no se borra.
3. **Cada requisito tiene un estado:**
   - `Propuesto`: se está discutiendo.
   - `Aceptado`: se va a construir.
   - `Implementado`: está en `main` y tiene test.
   - `Retirado`.
4. **Las decisiones van en ADR.** Una decisión con alternativas descartadas se registra en [decisiones.md](decisiones.md) y la spec enlaza al ADR.
5. **Las preguntas abiertas se marcan con `[ABIERTO]`.** Antes de construir lo que dependa de una, hay que resolverla y quitar la marca.
6. **Hay una fase por requisito.** `[F1]`…`[F6]` indica en qué fase del [roadmap](10-roadmap.md) se entrega.
7. **El CHANGELOG se actualiza.** Cada cambio de spec añade una línea en [CHANGELOG.md](CHANGELOG.md) con la fecha, el documento y un resumen.
8. **Se escribe en español y en presente:** "El sistema hace X", no "hará X".

## Áreas de requisitos

| Prefijo | Área |
|---------|------|
| AUTH | Autenticación y sesiones |
| TEAM | Equipos, membresías y hackathon |
| OBJ | Objetivos |
| FEAT | Features y kanban |
| PC | Pros y contras |
| DL | Deadlines y milestones |
| ACT | Feed de actividad |
| ATR | Atribución |
| AI | Análisis con IA |
| GH | GitHub |
| CC | Claude Code (CLI y hooks) |
| API | Acceso programático: tokens de acceso personales, scopes y API para terceros |
| MCP | Servidor MCP |
| SEC | Seguridad y privacidad |
| UX | Transversal de interfaz |
| OPS | Operación, rendimiento y observabilidad |
