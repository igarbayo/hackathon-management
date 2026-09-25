# 07 · Integración con GitHub

> **Estado de implementación:** Implementada · **Última actualización:** 2026-09-22

Se usa una **GitHub App** en lugar de OAuth personal: los webhooks van por repo, los permisos son acotados y no depende del token de una persona. Ver [ADR-0004](decisiones.md#adr-0004).

## Configuración de la App

| Ajuste | Valor |
|--------|-------|
| Permisos de repositorio | **Contents: read**, **Metadata: read**, **Pull requests: read** |
| Permisos de cuenta | **Email addresses: read** (para el login de usuario) |
| Eventos suscritos | `push`, `pull_request`, `create`, `delete`, `installation`, `installation_repositories`, `repository` (renombrados) |
| Webhook URL | `https://<api>/api/v1/webhooks/github` |
| Setup URL | `https://<api>/api/v1/github/setup` (con "Redirect on update") |
| Callback URL (OAuth de usuario) | `https://<api>/api/v1/auth/github/callback` |
| Webhook secret | `GITHUB_WEBHOOK_SECRET` |

La misma App sirve para el **login con GitHub** (user-to-server OAuth) y para la **ingesta** (installation tokens).

## Flujo de vinculación — "pegar repo y listo"

`RF-GH-020` [F3] Aceptado

1. El usuario pega `https://github.com/org/repo` (o `org/repo`) en onboarding o en ajustes.
2. La API normaliza la URL y busca si alguna instalación ya vinculada al equipo tiene acceso al repo (`GET /installation/repositories`, con caché de 5 min).
   - **Hay acceso:** se crea `Repository` y se muestra "Conectado ✓" al instante.
   - **No hay acceso:** se responde `needs_install` con la URL `https://github.com/apps/<slug>/installations/new?state=<firmado>`.
3. El usuario instala la App (en su cuenta u org) y elige el repo.
4. GitHub redirige a la Setup URL con `installation_id` y `state`. La API valida el `state` (firma, expiración de 15 min, que el usuario sea miembro del equipo), añade `installation_id` a `team.github_installation_ids` y vincula el repo que se pegó en el paso 1 (guardado en el `state`).
5. Se redirige a la web con el repo conectado.

Reglas:
- `RF-GH-021`: si el repo ya está vinculado **activo** a otro equipo, se responde `409 repo_already_linked`, y el mensaje sugiere unirse a ese equipo. Ver [ADR-0007](decisiones.md#adr-0007).
- `RF-GH-022`: si el usuario no es admin de la org, la instalación queda pendiente de aprobación en GitHub. La interfaz explica esta situación con un enlace para que el admin la apruebe.
- `RF-GH-023`: al vincular un repo se importa el histórico reciente: los commits de las ramas activas desde `hackathon.starts_at` (máx. 200 commits) y los PRs abiertos. Se hace en un job. Los commits anteriores a `starts_at` nunca se importan ([ADR-0019](decisiones.md#adr-0019)); para traerlos, se adelanta el inicio en ajustes (RF-TEAM-015), que relanza la importación. Si el hackathon no tiene `starts_at` (equipos creados antes de que se pusiera por defecto), no se importa ningún commit.
- `RF-GH-025` Implementado: el resultado de la última importación se guarda en `Repository.last_import` (cuántos commits y PRs, desde qué fecha, o por qué ninguno) y se muestra bajo cada repo en ajustes y en el paso de repo del onboarding: "Importando el histórico…", "87 commits desde el 25 abr 2026 y 0 PRs abiertos." o "El hackathon no tiene fecha de inicio, así que no se han importado commits.". Mientras se importa, la web consulta cada 3 s.

## Recepción de webhooks — `RF-GH-006` [F3] Aceptado

1. Se verifica `X-Hub-Signature-256` (HMAC-SHA256 con comparación en tiempo constante). Si no es válida, `401`.
2. Idempotencia: si `X-GitHub-Delivery` ya existe en `WebhookDelivery`, se responde `200` y se ignora.
3. Se crea `WebhookDelivery{status: received}`, se encola `Github::ProcessDeliveryJob` con el cuerpo **en la cola, no en Mongo**, y se responde `202`.
4. El job resuelve el equipo por `repository.id` → `Repository` activo. Si no hay ninguno, marca `ignored`.

## Normalización por evento

| Evento GitHub | → `ActivityEvent` | Notas |
|---------------|-------------------|-------|
| `push` | Un `commit` por commit (`dedupe_key: gh:commit:<sha>`) | Se ignoran los pushes de tags, los commits de merge de la rama por defecto hechos desde la interfaz de GitHub (ya representados por `pr_merged`) y los pushes `forced` (se registra solo la cabecera nueva). El payload trae un máximo de 20 commits. Si hay más, se usa la Compare API. |
| `pull_request` `opened`/`closed`(+merged)/`reopened` | `pr_opened`/`pr_merged`/`pr_closed`/`pr_reopened` | `branch` = rama head. `title` = título del PR. Los ficheros se piden aparte (máx. 50) |
| `create` (ref_type `branch`) | `branch_created` | Útil para la capa 1: `f-12-…` |
| `delete` (ref_type `branch`) | `branch_deleted` | No quita las ramas de `branch_names` |
| `installation` `deleted`/`suspend` | — | Marca los `Repository` de esa instalación como `active: false` y avisa en ajustes |
| `installation_repositories` `removed` | — | `active: false` para esos repos |
| `repository` `renamed` | — | Actualiza `full_name` y `remote_urls` |

**Stats de los commits:** `Github::FetchCommitStatsJob` pide `GET /repos/{o}/{r}/commits/{sha}` con el installation token (con caché de ~55 min) y guarda las rutas y los +/− (máx. 50 ficheros). **No se guarda el `patch`.** Si se alcanza el rate limit de GitHub, se reintenta según `X-RateLimit-Reset`.

Contenido que se guarda de cada commit: sha, primera línea del mensaje en `title` (máx. 200 caracteres), el resto del mensaje recortado a 1000 caracteres en `payload.message_body`, autor (nombre, email y login), rama, URL, ficheros y stats.

## Mapeo de autores

`RF-GH-024` [F3] Implementado. Ver [ADR-0018](decisiones.md#adr-0018).

**Cada evento de GitHub guarda siempre la identidad de su autor**, sea o no miembro del equipo: `actor.github_login`, `actor.email` (en minúsculas; solo commits, los PRs y ramas no la traen) y `actor.author_name` (nombre del autor en git, o el login si no lo hay). Así, un commit de alguien que todavía no está dado de alta se puede asignar a esa persona cuando entre.

**Asignación al llegar el evento.** Para resolver `actor.user_id` se aplica esta cascada, siempre contra miembros del equipo:

1. `commit.author.username` / `sender.login` → `User.github_login` de un miembro, o un login guardado en sus `Membership.git_identities`.
2. Email del autor del commit → `User.email` o un email de `Membership.git_identities` de un miembro.
3. Email *noreply* de GitHub (`12345+login@users.noreply.github.com`) → se extrae el login y se aplica el paso 1.
4. Si no hay coincidencia: `actor.user_id = nil` y `actor.display = actor.author_name`. El evento es de un **autor sin vincular**.

Los logins y los emails se comparan sin distinguir mayúsculas. Si el evento se asigna en este paso, `actor.mapped_by = "auto"`.

**Asignación retroactiva** — `Activity::ClaimForMembership` (job `Activity::ClaimForMembershipJob`). Busca los eventos de GitHub del equipo **sin usuario** cuya identidad (`actor.github_login` o `actor.email`, incluido el login de un email *noreply*) coincide con la de un miembro y se los asigna (`mapped_by: "auto"`, `display` = nombre del miembro). Nunca toca un evento que ya tiene usuario ni uno que ese miembro haya marcado como "No son míos". Se lanza:

- al crear la membresía (crear el equipo o unirse con el código);
- cuando cambian `User.github_login` o `User.email` (entrar o vincular con GitHub o con Google), para todas las membresías de esa persona;
- cuando se añaden identidades a `Membership.git_identities`.

**Asignación manual** — ver RF-ACT-018 en [04](04-pantallas.md#actividad) y `POST /teams/:id/activity/claim` / `unclaim` en [03](03-api.md).

## Requisitos no funcionales

| ID | Requisito |
|----|-----------|
| RNF-GH-001 | La clave privada de la App solo vive en variables de entorno o en un gestor de secretos. Los installation tokens se cachean en Redis y nunca en Mongo. |
| RNF-GH-002 | La API de GitHub se usa con un rate limiting propio por instalación, dejando un margen del 20 % sobre lo que permite GitHub. |
| RNF-GH-003 | Los webhooks perdidos se recuperan: un botón "Resincronizar" en ajustes relanza la importación del histórico reciente (RF-GH-023). |
