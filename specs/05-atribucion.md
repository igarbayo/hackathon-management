# 05 · Atribución de trabajo a features

> **Estado de implementación:** Implementada · **Última actualización:** 2026-09-22

Atribuir es **la clave del producto**: convierte la actividad en respuestas del tipo "quién hizo qué, y para qué feature". Se resuelve en tres capas, de más fiable a menos. Cada evento pasa por ellas en orden y se detiene en la primera que da resultado.

```
Evento nuevo
   │
   ├─ Capa 1: convención F-n en el mensaje o la rama ─────▶ confirmed (method: convention)
   │
   ├─ Capa 2: rama conocida (branch_names de una feature) ▶ confirmed (method: branch)
   │
   ├─ Capa 3: IA por lotes ─ confidence ≥ 0,5 ────────────▶ suggested (method: ai)
   │                       └ confidence < 0,5 ────────────▶ sin atribuir
   │
   └─ Humano: confirmar / rechazar / asignar ─────────────▶ confirmed/rejected (method: manual)
```

## Capa 1 · Convención explícita — `RF-ATR-001` [F3] Aceptado

- Expresión regular: `(?<![A-Za-z0-9])[Ff]-(\d{1,5})(?![0-9A-Za-z])`. Acepta `F-12`, `f-12`, `feat/f-12-login` y `[F-12]`. No acepta `ref-12` ni `F-123a`.
- Dónde se busca, por orden de prioridad:
  1. **Mensaje del commit** (subject + body) o título del PR y nombre de su rama *head*.
  2. **Nombre de la rama** del evento.
- Todas las claves encontradas se guardan en `mentioned_feature_keys`.
- Se atribuye a la **primera clave válida** (una que existe en el equipo y no está `discarded`) según ese orden.
- Las claves que no existen en el equipo se ignoran para atribuir, pero se guardan en `mentioned_feature_keys` y el feed muestra un aviso: "F-99 no existe".
- Resultado: `{method: convention, status: confirmed}`.
- Efecto secundario: si la clave salió del nombre de la rama, esa rama se añade a `feature.branch_names` (`$addToSet`).

## Capa 2 · Rama conocida — `RF-ATR-002` [F3/F5] Aceptado

- Si el evento tiene `branch` y alguna feature del equipo la tiene en `branch_names`, se atribuye a esa feature: `{method: branch, status: confirmed}`.
- Así funciona Claude Code: el CLI envía la rama actual del repo (calculada en local, porque el JSON de los hooks trae `cwd` pero no la rama), y la rama se cruza con las features.
- **Aprendizaje:** cuando un humano confirma o asigna a mano un evento cuya rama no es la por defecto, esa rama se añade a `branch_names` de la feature. Los eventos posteriores de esa rama caen en la capa 2.
- La rama por defecto (`main`/`master`/`repository.default_branch`) **nunca** se aprende ni se usa en la capa 2.
- Si una rama aparece en `branch_names` de dos features, la capa 2 no decide y el evento pasa a la capa 3. El detalle de la feature muestra un aviso para resolver el conflicto.

## Capa 3 · Inferencia con IA — `RF-ATR-003` [F4] Aceptado

- Job por lotes `Attribution::AiSuggestJob`. Corre cada 10 min por cada equipo con eventos sin atribuir de las últimas 24 h, si `settings.ai_attribution_enabled`.
- Entran: eventos sin `attribution` de tipo `commit`, `pr_*`, `cc_turn` y `progress_report`. Máx. 60 eventos por lote, agrupados por (actor, rama, sesión) para ahorrar tokens.
- **Contexto que se envía:** la lista de features activas (clave, título, descripción recortada a 300 caracteres, ramas y asignados) y, por cada grupo: actor, rama, títulos de commits o PRs, rutas de ficheros (máx. 20) y stats. **Nunca diffs ni contenido de ficheros.**
- Salida (JSON estructurado):
  ```json
  { "assignments": [ { "group_id": "g1", "feature_key": "F-12" | null, "confidence": 0.0, "reason": "≤ 200 caracteres" } ] }
  ```
- Reglas de aplicación:
  - Si `feature_key` no existe o está en `rejected_feature_ids` del evento, se ignora.
  - Si `confidence ≥ 0.5`, se guarda `{method: ai, status: suggested}` en todos los eventos del grupo.
  - Si `confidence < 0.5`, el evento sigue sin atribuir. No se vuelve a intentar hasta que llegue un evento nuevo del mismo grupo.
  - **La IA nunca confirma.** [ABIERTO] Estudiar si se autoconfirma con confidence ≥ 0,9 cuando la feature está asignada al propio actor. Hay que medir la precisión en F4 antes de decidirlo.
- Heurística previa que no usa la IA: si el actor solo tiene **una** feature `in_progress` asignada y el evento no está en la rama por defecto, se sugiere esa feature con `confidence: 0.6` y `reason: "única feature en curso del autor"`. Así se ahorran tokens.

## Acción humana — `RF-ATR-004` [F3] Aceptado

| Acción | Efecto |
|--------|--------|
| **Confirmar** una sugerencia | `status: confirmed`, se mantiene `method: ai`, `decided_by`/`decided_at`. Aprende la rama (capa 2) |
| **Rechazar** una sugerencia | `status: rejected` y añade la feature a `rejected_feature_ids`. El evento vuelve a quedar como candidato para la capa 3 |
| **Asignar a…** (o corregir una confirmada) | `{method: manual, status: confirmed}`. Aprende la rama |
| **Desvincular** | `attribution = nil`, y la feature anterior se añade a `rejected_feature_ids` |

- Cualquier miembro puede confirmar o corregir cualquier evento. El cambio queda auditado en `decided_by`.
- Confirmar un evento agrupado (RF-ACT-014) aplica la acción a todo el grupo.
- `RF-ATR-005` [F4]: acciones en bloque sobre hasta 100 eventos.

## Mapeo de actor (quién)

Se describe en [07 · Mapeo de autores](07-integracion-github.md#mapeo-de-autores). Los eventos de Claude Code y MCP llevan el actor implícito en el token de miembro, así que no hace falta inferirlo.

## Métricas de calidad — `RNF-ATR-001` [F4] Aceptado

Se registran por equipo: % de eventos por método, % de sugerencias confirmadas o rechazadas, y tiempo medio hasta la confirmación. Si la tasa de rechazo de la IA supera el 50 % durante una semana, se revisan el prompt y el umbral.

## Consecuencias para la interfaz

- La nomenclatura de ramas se promueve de forma activa: el detalle de la feature sugiere un nombre de rama (RF-FEAT-018) y el CLI puede sugerirlo al crear la rama. [Propuesto]
- Si hay muchos eventos sin atribuir en el feed, aparece un banner: "Usa F-12 en tus ramas para que se asigne solo".
