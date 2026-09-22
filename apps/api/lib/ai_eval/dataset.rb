# Dataset de evaluación del prompt de cobertura (RNF-AI-002,
# 06-analisis-ia.md#evaluación--rnf-ai-002-f4-aceptado). Cada caso trae el
# `context` con la misma forma que genera Analysis::BuildContext y el
# `expected["coverage"]` que un humano esperaría para ese caso.
#
# No usa la base de datos: son fixtures de texto plano, más simples de leer
# y de ampliar que crear equipos/features reales para cada caso.
module AiEval
  DATASET = [
    {
      "name" => "objetivo cubierto por una feature done con actividad",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-22T12:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 24.0, "challenge_text" => "Construir una app de gestión de hackathons." },
        "milestones" => [],
        "objectives" => [ { "key" => "O-1", "title" => "Login con GitHub", "description" => "Los usuarios entran con su cuenta de GitHub.", "priority" => "must" } ],
        "features" => [ {
          "key" => "F-1", "title" => "OAuth con GitHub", "description" => "Implementa el flujo OAuth completo con GitHub.",
          "status" => "done", "objective_keys" => [ "O-1" ], "assignee_count" => 1, "deadline" => nil, "score" => 8,
          "activity" => { "last_6h" => { "event_count" => 3, "people" => [ "Ada" ] }, "total" => { "event_count" => 10, "last_activity_at" => "2026-09-22T11:00:00Z", "titles" => [ "Implementa callback de OAuth" ], "files" => [ "app/controllers/auth.rb" ] } }
        } ],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "covered" } ] }
    },
    {
      "name" => "objetivo sin ninguna feature vinculada",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-22T12:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 24.0, "challenge_text" => nil },
        "milestones" => [],
        "objectives" => [ { "key" => "O-1", "title" => "Notificaciones por email", "description" => "Avisar a los usuarios de cambios importantes.", "priority" => "should" } ],
        "features" => [],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "uncovered" } ] }
    },
    {
      "name" => "feature en idea, sin actividad: cobertura parcial o nula, nunca covered",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-22T12:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 24.0, "challenge_text" => nil },
        "milestones" => [],
        "objectives" => [ { "key" => "O-1", "title" => "Exportar a PDF", "description" => "Poder descargar un informe en PDF.", "priority" => "could" } ],
        "features" => [ {
          "key" => "F-1", "title" => "Exportación PDF", "description" => "Botón para exportar el informe.",
          "status" => "idea", "objective_keys" => [ "O-1" ], "assignee_count" => 0, "deadline" => nil, "score" => 1,
          "activity" => { "last_6h" => { "event_count" => 0, "people" => [] }, "total" => { "event_count" => 0, "last_activity_at" => nil, "titles" => [], "files" => [] } }
        } ],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "uncovered" } ] }
    },
    {
      "name" => "feature discarded no cuenta como cobertura",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-22T12:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 24.0, "challenge_text" => nil },
        "milestones" => [],
        "objectives" => [ { "key" => "O-1", "title" => "Modo oscuro", "description" => "Tema oscuro para toda la app.", "priority" => "could" } ],
        "features" => [ { "key" => "F-1", "title" => "Modo oscuro", "status" => "discarded" } ],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "uncovered" } ] }
    },
    {
      "name" => "trabajo en curso con actividad reciente: parcial",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-22T12:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 24.0, "challenge_text" => nil },
        "milestones" => [],
        "objectives" => [ { "key" => "O-1", "title" => "Kanban de features", "description" => "Tablero con arrastrar y soltar.", "priority" => "must" } ],
        "features" => [ {
          "key" => "F-1", "title" => "Kanban básico", "description" => "Columnas idea/en curso/hecha, sin drag and drop todavía.",
          "status" => "in_progress", "objective_keys" => [ "O-1" ], "assignee_count" => 1, "deadline" => nil, "score" => 4,
          "activity" => { "last_6h" => { "event_count" => 2, "people" => [ "Grace" ] }, "total" => { "event_count" => 4, "last_activity_at" => "2026-09-22T11:30:00Z", "titles" => [ "Añade columnas del kanban" ], "files" => [ "app/features/board.tsx" ] } }
        } ],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "partial" } ] }
    },
    {
      "name" => "varios objetivos, cobertura mixta",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-23T09:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 3.0, "challenge_text" => nil },
        "milestones" => [],
        "objectives" => [
          { "key" => "O-1", "title" => "Autenticación", "description" => "Entrar con email y contraseña.", "priority" => "must" },
          { "key" => "O-2", "title" => "Analítica de uso", "description" => "Saber qué features se usan más.", "priority" => "could" }
        ],
        "features" => [ {
          "key" => "F-1", "title" => "Login con email", "description" => "Formulario de login con email y contraseña, ya en producción.",
          "status" => "done", "objective_keys" => [ "O-1" ], "assignee_count" => 1, "deadline" => nil, "score" => 9,
          "activity" => { "last_6h" => { "event_count" => 1, "people" => [ "Ada" ] }, "total" => { "event_count" => 8, "last_activity_at" => "2026-09-23T08:00:00Z", "titles" => [ "Login con email" ], "files" => [ "app/auth/login.rb" ] } }
        } ],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "covered" }, { "objective_key" => "O-2", "status" => "uncovered" } ] }
    }
  ].freeze
end
