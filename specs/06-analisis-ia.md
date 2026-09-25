# 06 · Análisis con IA (Gemini)

> **Estado de implementación:** Implementada · **Última actualización:** 2026-09-25

## Proveedor

- La IA de la app se consume mediante la interfaz `Ai::Provider`:
  ```ruby
  # Devuelve { data: Hash (validado contra el schema), usage: {input_tokens:, output_tokens:}, model: String }
  Ai::Provider#generate_json(system:, prompt:, schema:, temperature: 0.2, max_output_tokens:)
  ```
- Implementación por defecto: `Ai::Gemini`. Usa la API de Gemini con salida estructurada (`responseMimeType: "application/json"` + `responseSchema`). El modelo se configura con `GEMINI_MODEL`. [ABIERTO] Qué modelo concreto usar por defecto (familia Flash por coste o Pro por calidad). Hay que decidirlo con una evaluación en F4.
- La respuesta **siempre** se valida en el servidor contra el JSON Schema de `packages/shared-schemas`, aunque el proveedor garantice el formato. Si no valida, se reintenta 1 vez y después se marca `failed`.
- Ver [ADR-0003](decisiones.md#adr-0003) y [ADR-0014](decisiones.md#adr-0014).

### Clave de API — `RF-AI-021` [F4] Aceptado

- **No hay una clave de Gemini compartida del servidor.** Cada persona pone la suya en su perfil (`Equipo y ajustes → IA (Gemini)`), cifrada en reposo (`GeminiApiKeyCipher`, AES-256-GCM con `GEMINI_API_KEY_ENCRYPTION_KEY`). Nunca se vuelve a mostrar en claro; la API solo informa de si está configurada (`gemini_api_key_configured`).
- **Qué clave se usa en cada llamada** (`Ai::KeyOwner`):
  - Acciones que dispara una persona (botón "Analizar ahora", la herramienta MCP `run_analysis`, la API): la clave de quien lo pide (`AiAnalysis.requested_by_id`). Si no la tiene puesta, la petición falla en el momento con `422 missing_gemini_api_key` (API) o un error de herramienta (MCP), sin llegar a encolarse.
  - Lo automático, sin un actor que lo dispare (el cron de análisis programado y la sugerencia de atribución de la capa 3, [05](05-atribucion.md#capa-3)): la clave del **owner** del equipo.
  - Si la clave que corresponde no está puesta, no se llama a la IA: el análisis programado se guarda como `AiAnalysis` con `status: skipped, skip_reason: no_api_key` (igual que `no_changes`) y la sugerencia de atribución simplemente no se intenta ese ciclo (se reintentará en el siguiente, como si la IA hubiera fallado).
  - No hay fallback a ninguna clave compartida del servidor: si nadie la ha puesto, la IA de ese equipo no funciona hasta que alguien la configure.
- `rake ai:eval` (RNF-AI-002) es la única excepción: sigue leyendo `GEMINI_API_KEY` del entorno de quien lo ejecuta, porque es una herramienta de desarrollador que corre en local, no una petición de la app en producción.

## Usos de la IA

| Uso | Req | Fase |
|-----|-----|------|
| Análisis de cobertura (este documento) | RF-AI-030 | F4 |
| Atribución sugerida | RF-ATR-003 ([05](05-atribucion.md)) | F4 |
| Importar objetivos desde el texto del reto | RF-OBJ-013 | F4 |
| Sugerir pros y contras | RF-PC-014 | F4 (Propuesto) |

## Análisis de cobertura — `RF-AI-030` [F4] Aceptado

### Disparo

- **Programado:** con `sidekiq-cron` cada minuto se buscan los equipos cuyo último análisis tiene más de `settings.analysis_interval_min` minutos **y** que han cambiado desde entonces (el `input_hash` difiere). Si no han cambiado, se crea el `AiAnalysis` con `status: skipped, skip_reason: no_changes`, y no se muestra en el historial.
- **Solo durante el hackathon:** entre `starts_at − 12 h` y `ends_at + 1 h`. Fuera de esa ventana, solo se lanza bajo demanda.
- **Bajo demanda:** botón "Analizar ahora" (RF-AI-004), sujeto a cuota.
- Como mucho **un** análisis en curso por equipo (lock en Redis con TTL de 5 min).

### Cuotas

| Plan | Intervalo mínimo programado | Manuales | Tope de tokens diario |
|------|-----------------------------|----------|-----------------------|
| free | 60 min | 5 al día | [ABIERTO] a calibrar en F4 |
| pro | 15 min | 30 al día | [ABIERTO] |

Al superar la cuota se responde `429` con `retry_after`, y la interfaz muestra cuándo vuelve a estar disponible.

### Construcción del contexto (`Analysis::BuildContext`)

Se envía solo texto y metadatos. **Nunca diffs, contenido de ficheros ni prompts.**

1. **Hackathon:** nombre, `ahora`, `ends_at`, horas restantes y `challenge_text` (recortado a 6000 caracteres).
2. **Milestones:** título, tipo, `due_at` y horas restantes.
3. **Objetivos** (no archivados): clave, título, descripción (recortada a 500 caracteres) y prioridad.
4. **Features** (no descartadas; las descartadas solo con clave y título): clave, título, descripción (400 caracteres), estado, objetivos vinculados, asignados, deadline y score de pros y contras.
5. **Actividad por feature** en las últimas 6 h y en total: número de eventos, última actividad, personas, hasta 5 títulos de commits o PRs y hasta 15 rutas de ficheros más tocadas.
6. **Actividad sin atribuir:** el recuento y hasta 10 títulos.
7. **Alertas deterministas** ya calculadas, para que el modelo no las repita y las matice.

Límite total: ~30.000 caracteres. Si se supera, se recorta en este orden: títulos de actividad, rutas de ficheros, descripciones de features.

`input_hash` = SHA-256 del contexto sin el campo `ahora`, redondeando las horas restantes a la hora.

### Prompt

- Plantilla versionada en `apps/api/app/lib/ai/prompts/coverage_v<N>.md`. Cada cambio sube `N` y se refleja en `AiAnalysis.prompt_version` y en el [CHANGELOG](CHANGELOG.md).
- Instrucciones clave del system prompt:
  - "Eres el analista de un equipo de hackathon. Evalúa si las features cubren los objetivos."
  - "Una feature solo cubre un objetivo si su descripción o su actividad lo justifican. Estar vinculada no basta."
  - "`covered` = hay features `done` o con actividad sustancial que lo satisfacen. `partial` = hay trabajo pero incompleto o solo `idea`. `uncovered` = nada relevante."
  - "Usa solo claves (`O-n`, `F-n`) que aparezcan en el contexto."
  - "Ten en cuenta el tiempo restante: con menos de 6 h, prioriza recortar alcance antes que añadir."
  - "Answer in English, even if the team's data is in another language." Inglés por defecto desde `coverage_v2` (y `attribution_v2` para el `reason` de la atribución), igual que la interfaz (RNF-UI-013). Las plantillas están escritas en inglés. [ABIERTO] Idioma por equipo.

### Esquema de salida

```json
{
  "summary": "string, ≤ 600 caracteres. Estado general en 2-3 frases",
  "coverage": [
    {
      "objective_key": "O-1",
      "status": "covered | partial | uncovered",
      "feature_keys": ["F-3", "F-7"],
      "rationale": "≤ 300 caracteres"
    }
  ],
  "orphan_features": [
    {
      "feature_key": "F-9",
      "rationale": "≤ 300 caracteres",
      "recommendation": "discard | link_objective | keep",
      "suggested_objective_key": "O-2 | null"
    }
  ],
  "gaps": [
    {
      "objective_key": "O-4 | null",
      "description": "≤ 300 caracteres",
      "suggested_feature_title": "≤ 120 caracteres"
    }
  ],
  "risks": [
    {
      "severity": "low | medium | high",
      "kind": "deadline | scope | unassigned | inactivity | quality | other",
      "description": "≤ 300 caracteres",
      "related_keys": ["O-3", "F-12"]
    }
  ]
}
```

Posvalidación en el servidor:
- `coverage` debe traer **exactamente un** elemento por cada objetivo activo. Los que falten se añaden como `uncovered` con `rationale: "no evaluado"`, y los duplicados se descartan.
- Se eliminan las claves inexistentes de `feature_keys`, `related_keys`, etc.
- `orphan_features` solo puede incluir features no descartadas.

### Alertas deterministas

Se calculan en cada petición a `analyses/latest` sin llamar a la IA, y se guardan también en el snapshot:

| Código | Regla | Severidad |
|--------|-------|-----------|
| `objective_without_features` | Objetivo `must` o `should` sin features activas vinculadas | high si `must`, medium si `should` |
| `objective_without_features_near_end` | Lo anterior con menos de 6 h para `ends_at` | high |
| `feature_overdue` | `deadline < ahora` y estado ≠ `done`/`discarded` | high |
| `feature_unassigned_in_progress` | `in_progress` sin asignados | medium |
| `feature_stale` | `in_progress` sin actividad en 3 h (durante el hackathon) | medium |
| `milestone_soon` | Un milestone en menos de 1 h con features vinculadas a objetivos `must` sin terminar | high |
| `member_idle` | Miembro sin actividad en 4 h durante el hackathon | low. Solo visible para owners. [ABIERTO] ¿se muestra? Puede sentirse como vigilancia |

### Almacenamiento y evolución

- Cada ejecución crea un `AiAnalysis` ([02](02-modelo-datos.md#aianalysis)). Nunca se sobrescribe.
- RF-AI-015: la evolución se calcula a partir de `result.coverage` de los snapshots `succeeded`.

## Coste y observabilidad — `RNF-AI-001` [F4] Aceptado

- Los tokens de entrada y salida se registran en cada llamada (`usage`), junto con la latencia y el resultado.
- Hay un panel interno (o un log agregado) de tokens por equipo y día.
- Timeout de 60 s por llamada.
- **Datos enviados a Gemini:** solo el contexto descrito arriba. Queda documentado en [09](09-privacidad-seguridad.md#terceros) y lo pueden consultar los usuarios.

## Evaluación — `RNF-AI-002` [F4] Aceptado

- Hay un dataset de 5–10 equipos sintéticos (fixtures) con la respuesta esperada de cobertura y huecos.
- Hay un test (`rake ai:eval`) que ejecuta el prompt actual contra el dataset e informa de la concordancia. Se ejecuta **antes** de subir `prompt_version`.
