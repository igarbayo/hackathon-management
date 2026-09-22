# CHANGELOG de specs

Formato: `AAAA-MM-DD · documento(s) · resumen`. Lo más reciente va arriba.

- 2026-09-22 · 08 · Implementación completa de la spec: backend del device flow y la ingesta, sección personal de Claude Code en ajustes y pantalla de aprobación en la web, y el paquete `packages/cli` (`hackboard`) con todos los comandos de RF-CC-020. Verificado con RSpec, Vitest y un e2e de Playwright del device flow completo, y una prueba manual del CLI real (compilado) contra la API en marcha, incluida la fusión de hooks en un `~/.claude/settings.json` real sin tocar el resto de su contenido.
- 2026-09-22 · 08 · Añade `PATCH`/`DELETE /cli/me` (Bearer, mismo contrato que las rutas de sesión `.../me/claude_code`): `hackboard pause/resume/privacy/uninstall` solo tienen el token de miembro, nunca la cookie de sesión, y la spec solo daba la vía de sesión para sincronizar el enlace.
- 2026-09-22 · 02, 08 · Define el contrato del device flow (`POST /cli/device`, `/cli/device/token`, `/teams/:id/cli/device/approve|deny`) siguiendo RFC 8628, y el de `/cli/config` y `/teams/:id/me/claude_code`: la spec ya exigía el device flow (RF-CC-001/002) y estos endpoints (RF-CC-004, RF-CC-010) pero no daba su JSON.
- 2026-09-22 · 02, 08 · Añade el modelo `DeviceAuthorization` (device flow del CLI, RF-CC-001), que faltaba en el modelo de datos. Añade `system_test` al catálogo de `kind` de `claude_code`: el contrato de ingesta de 08 ya lo usaba (`hackboard test`) pero no estaba en el catálogo de 02. Corrige la ruta del schema de ingesta en 08 para que coincida con dónde vive de verdad el resto de schemas (`packages/shared-schemas/schemas/`, no en la raíz del paquete).

- 2026-09-22 · 03 · Añade `GET /teams/:id/repositories` (listar repos vinculados) y `POST /teams/:id/repositories/:rid/resync`: faltaban en la spec pero RF-GH-010 y RNF-GH-003 ya los mencionaban en prosa sin darles una ruta concreta.

- 2026-09-22 · 02, 05 · Añade `ActivityEvent.ai_suggestion_attempted_at`, necesario para implementar la regla de 05 "no se reintenta [la capa 3] hasta que llegue un evento nuevo del mismo grupo", que no tenía dónde guardar ese estado en el modelo de datos existente.

- 2026-09-22 · README, 00-12 · Cada spec numerada añade una cabecera con su estado de implementación (Implementada / En proceso / Pendiente / No aplica) y la fecha de la última actualización, para trazabilidad (regla 9 de mantenimiento).

- 2026-09-22 · 05 · Corrige la regex de la capa 1 de atribución: la que daba la spec (`(?![0-9])` al final) sí matchea `F-123a` (extrae 123), contradiciendo el propio texto ("No acepta... F-123a"). Se cambia el lookahead final a `(?![0-9A-Za-z])`.
- 2026-09-22 · 02 · Corrige una contradicción: la sección de `OAuthClient` decía que `OAuthGrant` no lleva `team_id`, pero su propia tabla de campos sí lo incluye (y `AccessToken.kind: oauth` lo necesita). Se aclara que solo `User`, `Session` y `OAuthClient` son la excepción a la regla multi-tenant.

- 2026-09-22 · 12, 00, 01, 02, 03, 04, 08, 09, 10, 11, decisiones, README · Login con Google (RF-AUTH-008…010). Servidor de autorización OAuth 2.1 propio, con identidad vía Google, GitHub o contraseña (ADR-0011, se resuelve el [ABIERTO] de RF-API-010). claude.ai como connector (RF-MCP-020, 011). Tokens de integración de equipo (RF-API-011) y webhooks salientes (RF-API-009) pasan a Aceptado. Nueva Fase 6 · Integraciones. `hackboard init` registra el MCP (RF-CC-026, Aceptado).
- 2026-09-22 · 12 (nuevo), 00, 01, 02, 03, 04, 08, 09, 10, 11, decisiones, README · Acceso programático: API REST con tokens de acceso personales (`hb_pat_`) y scopes, servidor MCP con herramientas de lectura (`get_team_status`, actividad, análisis…) y de escritura, trazabilidad `via` en el feed, OpenAPI e idempotencia. El MCP pasa de "si da tiempo" a comprometido en F5 y su especificación se mueve de 08 a 12. ADR-0009 y ADR-0010.
- 2026-09-21 · todas · Las specs se mueven de `docs/specs/` a `specs/` en la raíz del repo.
- 2026-09-21 · todas · Versión inicial de las specs a partir del plan del producto. La IA interna usa Gemini (ADR-0003) y Claude Code se integra como fuente de actividad mediante hooks y MCP.
