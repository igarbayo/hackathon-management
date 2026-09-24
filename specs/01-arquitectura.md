# 01 · Arquitectura

> **Estado de implementación:** Implementada · **Última actualización:** 2026-09-22

## Vista general

```
                    ┌──────────────────────────┐
  Navegador ──────▶ │  web  (Next.js App Router)│
                    └────────────┬─────────────┘
                                 │ HTTPS + cookie de sesión
                                 ▼
┌──────────┐ webhooks  ┌──────────────────────────┐   ┌─────────┐
│  GitHub  │─────────▶ │  api  (Rails 8 --api)     │──▶│ MongoDB │
│   App    │◀───────── │  Mongoid                  │   └─────────┘
└──────────┘ REST API  └──────┬───────────▲────────┘
                              │ encola     │
                              ▼            │
                       ┌─────────────┐  ┌──┴──────┐
                       │  Sidekiq    │─▶│  Redis  │
                       │  (workers)  │  └─────────┘
                       └──────┬──────┘
                              │ JSON estructurado
                              ▼
                       ┌─────────────┐
                       │ Gemini API  │
                       └─────────────┘

 Portátil del miembro:
 Claude Code ──hooks──▶ hackboard CLI ──POST /ingest──▶ api
 Claude Code ──MCP (HTTP)──────────────────────────────▶ api /mcp

 Agentes y apps externas (con PAT hb_pat_):
 Cualquier cliente MCP ──MCP (HTTP)────────────────────▶ api /mcp
 Scripts, bots, integraciones ──REST /api/v1 + Bearer──▶ api

 Con OAuth 2.1 (hb_oat_), identidad vía Google, GitHub o contraseña:
 claude.ai (connector) y apps de terceros ──/oauth/* + MCP/REST──▶ api

 Salida:
 api ──webhooks firmados (Webhooks::DeliverJob)──▶ Slack, n8n, apps externas
```

## Componentes

| Componente | Tecnología | Responsabilidad |
|------------|------------|-----------------|
| `web` | Next.js (App Router), TypeScript, Tailwind, shadcn/ui, Lucide, TanStack Query, dnd-kit, estilo F0 de Factorial (tokens de `f0-core`, ver [13](13-sistema-diseno.md)) | La interfaz. Se renderiza en el cliente con datos de la API. No contiene lógica de negocio. |
| `api` | Rails 8 en modo `--api`, Mongoid, Ruby 3.3+ | Dominio, autenticación, API REST, webhooks, ingesta y MCP |
| `workers` | Sidekiq y sidekiq-cron sobre Redis | Procesar webhooks, llamadas a la API de GitHub, atribución y análisis con IA |
| `cli` | Node.js ≥ 20, TypeScript, paquete npm `hackboard` | Instalar hooks en Claude Code, encolar eventos en local y enviarlos |
| `mcp` | Endpoint HTTP dentro de `api` (Streamable HTTP) | Herramientas MCP de lectura y escritura para agentes, sobre los mismos servicios de dominio que la REST ([12](12-acceso-programatico.md#servidor-mcp)) |
| MongoDB | ≥ 7 | Persistencia |
| Redis | ≥ 7 | Colas de Sidekiq, rate limiting y cachés efímeras |
| Gemini API | Modelo configurable (`GEMINI_MODEL`) | Análisis de cobertura y atribución sugerida ([06](06-analisis-ia.md)) |

La IA de la app usa **Gemini** detrás de una interfaz de proveedor, de modo que se puede cambiar de proveedor sin tocar el dominio. Claude **no** es el motor de IA de la app. Claude aparece como **fuente de actividad**: el Claude Code de cada miembro. Ver [ADR-0003](decisiones.md#adr-0003).

## Estructura del repositorio (monorepo)

```
/
├── apps/
│   ├── web/                 # Next.js
│   └── api/                 # Rails 8 API + Sidekiq
├── packages/
│   ├── cli/                 # npm: hackboard (hooks de Claude Code)
│   └── shared-schemas/      # JSON Schemas compartidos (eventos de ingesta, salida de IA)
├── specs/                   # ESTAS specs
├── docker-compose.yml       # mongo, redis, api, worker, web para desarrollo
└── CLAUDE.md
```

`packages/shared-schemas` contiene los JSON Schema de la ingesta y de la salida de la IA. La api los valida en Ruby con `json_schemer`, y el CLI los usa para generar sus tipos TypeScript. Así hay una sola definición por contrato.

## Organización interna de `api`

```
app/
  controllers/api/v1/…       # REST de la app
  controllers/webhooks/github_controller.rb
  controllers/ingest/…       # ingesta del CLI
  controllers/oauth/…        # servidor de autorización OAuth 2.1 y /.well-known
  controllers/mcp/…          # endpoint MCP (cada herramienta llama a un servicio de services/)
  controllers/concerns/token_authentication.rb  # Bearer hb_pat_ / hb_mt_ → current_token, current_team, scopes
  models/…                   # documentos Mongoid
  services/                  # lógica de dominio (verbo + sustantivo): Attribution::Resolve, Analysis::BuildContext…
  jobs/                      # workers de Sidekiq (sufijo Job)
  lib/ai/                    # Ai::Provider (interfaz), Ai::Gemini (implementación)
  policies/                  # autorización por rol y por scope del token
```

- Los controladores son finos. La lógica va en `services/`. La web, la API con token y el MCP usan **los mismos servicios**: no hay lógica de dominio duplicada por canal.
- **Todos** los accesos a datos del dominio pasan por `current_team`. Nunca se busca por id sin acotar al equipo (ver [RNF-SEC-001](09-privacidad-seguridad.md)).

## Comunicación y tiempo real

- **MVP:** la web hace polling con TanStack Query. Cada 15 s en Inicio y Actividad, cada 60 s en el resto, y refresca al recuperar el foco. Ver [ADR-0005](decisiones.md#adr-0005).
- **Más adelante:** ActionCable (reutiliza Redis) para el feed y el kanban. `[Propuesto]`

## Jobs de Sidekiq

| Job | Cola | Disparo | Descripción |
|-----|------|---------|-------------|
| `Github::ProcessDeliveryJob` | `webhooks` | Webhook recibido | Normaliza la entrega en `ActivityEvent`s |
| `Github::FetchCommitStatsJob` | `github` | Tras un push | Pide ficheros y stats de cada commit a la API de GitHub |
| `Attribution::ConventionJob` | `attribution` | Evento creado | Aplica las capas 1 y 2 ([05](05-atribucion.md)) |
| `Attribution::AiSuggestJob` | `ai` | Cron cada 10 min por equipo con eventos pendientes | Aplica la capa 3 |
| `Analysis::RunJob` | `ai` | Cron (según el plan) o bajo demanda | Análisis de cobertura ([06](06-analisis-ia.md)) |
| `Ingest::ProcessBatchJob` | `ingest` | POST a `/ingest` | Normaliza los eventos de Claude Code |
| `Webhooks::DeliverJob` | `outbound` | Cambio en el dominio con webhooks suscritos | Envía y reintenta los webhooks salientes ([12](12-acceso-programatico.md#webhooks-salientes)) |
| `Webhooks::MilestoneDueSoonJob` | `low` | Cron cada 5 min | Emite `milestone.due_soon` |
| `Maintenance::RetentionJob` | `low` | Cron diario | Aplica la política de retención ([09](09-privacidad-seguridad.md)) |

Pesos de las colas: `webhooks: 5, ingest: 5, attribution: 3, github: 2, outbound: 2, ai: 1, low: 1`. Todos los jobs son **idempotentes**, porque pueden reintentarse.

## Configuración (variables de entorno)

| Variable | Componente | Descripción |
|----------|------------|-------------|
| `MONGODB_URI` | api | Conexión a Mongo |
| `REDIS_URL` | api | Sidekiq y rate limiting |
| `APP_URL`, `API_URL` | api, web | URLs públicas |
| `SESSION_SECRET` | api | Firma de cookies |
| `GITHUB_APP_ID`, `GITHUB_APP_SLUG`, `GITHUB_APP_PRIVATE_KEY`, `GITHUB_WEBHOOK_SECRET`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` | api | GitHub App (incluye el login OAuth de usuario) |
| `GEMINI_MODEL` | api | Modelo de Gemini. La clave de API ya no es una variable de entorno: cada persona pone la suya en su perfil ([06](06-analisis-ia.md#clave-de-api--rf-ai-021-f4-aceptado)) |
| `GEMINI_API_KEY_ENCRYPTION_KEY` | api | Clave para cifrar en reposo la clave de Gemini de cada persona |
| `GEMINI_API_KEY` | dev | Solo para `rake ai:eval` (RNF-AI-002), en el entorno de quien lo ejecuta. La app no la lee en runtime |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | api | Login con Google (OpenID Connect) |
| `WEBHOOK_SECRETS_KEY` | api | Clave para cifrar los secretos de los webhooks salientes |
| `AI_PROVIDER` | api | `gemini` (por defecto). Deja preparado el cambio de proveedor |
| `NEXT_PUBLIC_API_URL` | web | Base de la API |
| `NEXT_PUBLIC_SITE_URL` | web | URL pública de la web (`metadataBase`, `canonical`, sitemap, robots, JSON-LD, `llms.txt`). Por defecto `https://hackboard.ignaciogarbayo.com` |
| `HACKBOARD_API_URL` | cli | Por defecto, la URL de producción |

## Entornos

| Entorno | Uso |
|---------|-----|
| `development` | `docker compose up`. GitHub App de desarrollo con webhooks vía smee.io o cloudflared |
| `staging` | Despliegue automático desde `main` |
| `production` | Despliegue manual con tag |

Hosting de producción: servidor propio en España (Raspberry Pi, `docker-compose.prod.yml`) expuesto con Cloudflare Tunnel, MongoDB Atlas y Upstash (Redis), ambos en regiones de la Unión Europea. Lo recoge la política de privacidad (RF-SEC-007).

## Requisitos no funcionales

| ID | Requisito | Estado |
|----|-----------|--------|
| RNF-OPS-001 | Los webhooks de GitHub responden `202` en < 500 ms (p95). El trabajo se hace en jobs. | Aceptado [F3] |
| RNF-OPS-002 | La ingesta del CLI responde `202` en < 300 ms (p95). | Aceptado [F5] |
| RNF-OPS-003 | Un evento aparece en el feed < 30 s después de ocurrir (p95), sin contar la latencia de GitHub. | Aceptado [F3] |
| RNF-OPS-004 | Las pantallas cargan en < 1,5 s (p75) con 500 eventos y 100 features por equipo. | Aceptado [F1] |
| RNF-OPS-005 | Logs estructurados en JSON con `team_id`, `request_id` y `job_id`. Ningún log contiene tokens, prompts ni el payload bruto de un webhook. | Aceptado [F1] |
| RNF-OPS-006 | Error tracking en api, web y workers. [ABIERTO] Sentry u otra herramienta. | Aceptado [F1] |
| RNF-OPS-007 | Los jobs que fallan reintentan con backoff (lo que trae Sidekiq por defecto, máx. 10). Los de IA, máx. 3. | Aceptado [F3] |
