# Hackboard (nombre provisional)

Herramienta de gestión para equipos de hackathon: objetivos, features en kanban, pros y contras, deadlines, feed de actividad (GitHub + Claude Code) y análisis de cobertura con IA (Gemini).

## Normas básicas

- Las specs de `docs/specs/` son documentación viva y la fuente de verdad del proyecto.
- Responde siempre en español.
- Los commits nunca llevan atribución a Claude: nada de `Co-Authored-By: Claude` ni menciones a Claude o a IA en el mensaje.

## Las specs son la fuente de verdad

- Las especificaciones están en `docs/specs/`. Empieza por `docs/specs/README.md`.
- **Todo cambio de comportamiento, modelo de datos, API, integraciones, prompts o tratamiento de datos debe actualizar la spec correspondiente en el mismo cambio**, añadir una línea en `docs/specs/CHANGELOG.md` y, si cambia el estado de un requisito, reflejarlo (`Propuesto` → `Aceptado` → `Implementado`).
- Antes de implementar algo, localiza su requisito (`RF-…` / `RNF-…`) y cítalo en el commit o el PR.
- Si la spec y el código se contradicen, no elijas en silencio: señálalo y resuélvelo en ambos.
- Las decisiones con alternativas se registran como ADR en `docs/specs/decisiones.md`.
- No implementes nada marcado como `[ABIERTO]` sin resolverlo antes con el usuario.

## Stack

- `apps/web`: Next.js (App Router), Tailwind, shadcn/ui, Lucide, TanStack Query, dnd-kit
- `apps/api`: Rails 8 `--api`, Mongoid, Sidekiq + Redis
- `packages/cli`: CLI `hackboard` (hooks de Claude Code)
- `packages/shared-schemas`: JSON Schemas compartidos
- IA interna: Gemini, a través de `Ai::Provider`

## Reglas que no se negocian

- Toda consulta de dominio se acota por `current_team` (RNF-SEC-001).
- Nunca se persisten diffs, contenido de ficheros ni texto de prompts (09-privacidad-seguridad).
- Los hooks del CLI nunca bloquean ni fallan: salen siempre con 0 y sin stdout (RNF-CC-001).
