# Evaluation dataset for the coverage prompt (RNF-AI-002,
# 06-analisis-ia.md#evaluación--rnf-ai-002-f4-aceptado). Each case has a
# `context` with the same shape Analysis::BuildContext produces and the
# `expected["coverage"]` a human would expect for that case.
#
# It does not use the database: they are plain text fixtures, simpler to read
# and extend than creating real teams/features for each case.
module AiEval
  DATASET = [
    {
      "name" => "objective covered by a done feature with activity",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-22T12:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 24.0, "challenge_text" => "Build a hackathon management app." },
        "milestones" => [],
        "objectives" => [ { "key" => "O-1", "title" => "Login with GitHub", "description" => "Users log in with their GitHub account.", "priority" => "must" } ],
        "features" => [ {
          "key" => "F-1", "title" => "GitHub OAuth", "description" => "Implements the full OAuth flow with GitHub.",
          "status" => "done", "objective_keys" => [ "O-1" ], "assignee_count" => 1, "deadline" => nil, "score" => 8,
          "activity" => { "last_6h" => { "event_count" => 3, "people" => [ "Ada" ] }, "total" => { "event_count" => 10, "last_activity_at" => "2026-09-22T11:00:00Z", "titles" => [ "Implement the OAuth callback" ], "files" => [ "app/controllers/auth.rb" ] } }
        } ],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "covered" } ] }
    },
    {
      "name" => "objective with no linked feature",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-22T12:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 24.0, "challenge_text" => nil },
        "milestones" => [],
        "objectives" => [ { "key" => "O-1", "title" => "Email notifications", "description" => "Tell users about important changes.", "priority" => "should" } ],
        "features" => [],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "uncovered" } ] }
    },
    {
      "name" => "feature in idea, no activity: partial or no coverage, never covered",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-22T12:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 24.0, "challenge_text" => nil },
        "milestones" => [],
        "objectives" => [ { "key" => "O-1", "title" => "Export to PDF", "description" => "Download a report as a PDF.", "priority" => "could" } ],
        "features" => [ {
          "key" => "F-1", "title" => "PDF export", "description" => "Button to export the report.",
          "status" => "idea", "objective_keys" => [ "O-1" ], "assignee_count" => 0, "deadline" => nil, "score" => 1,
          "activity" => { "last_6h" => { "event_count" => 0, "people" => [] }, "total" => { "event_count" => 0, "last_activity_at" => nil, "titles" => [], "files" => [] } }
        } ],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "uncovered" } ] }
    },
    {
      "name" => "a discarded feature does not count as coverage",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-22T12:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 24.0, "challenge_text" => nil },
        "milestones" => [],
        "objectives" => [ { "key" => "O-1", "title" => "Dark mode", "description" => "Dark theme for the whole app.", "priority" => "could" } ],
        "features" => [ { "key" => "F-1", "title" => "Dark mode", "status" => "discarded" } ],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "uncovered" } ] }
    },
    {
      "name" => "work in progress with recent activity: partial",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-22T12:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 24.0, "challenge_text" => nil },
        "milestones" => [],
        "objectives" => [ { "key" => "O-1", "title" => "Feature kanban", "description" => "Board with drag and drop.", "priority" => "must" } ],
        "features" => [ {
          "key" => "F-1", "title" => "Basic kanban", "description" => "Idea/in progress/done columns, no drag and drop yet.",
          "status" => "in_progress", "objective_keys" => [ "O-1" ], "assignee_count" => 1, "deadline" => nil, "score" => 4,
          "activity" => { "last_6h" => { "event_count" => 2, "people" => [ "Grace" ] }, "total" => { "event_count" => 4, "last_activity_at" => "2026-09-22T11:30:00Z", "titles" => [ "Add the kanban columns" ], "files" => [ "app/features/board.tsx" ] } }
        } ],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "partial" } ] }
    },
    {
      "name" => "several objectives, mixed coverage",
      "context" => {
        "hackathon" => { "name" => "HackUSC", "now" => "2026-09-23T09:00:00Z", "ends_at" => "2026-09-23T12:00:00Z", "hours_remaining" => 3.0, "challenge_text" => nil },
        "milestones" => [],
        "objectives" => [
          { "key" => "O-1", "title" => "Authentication", "description" => "Log in with email and password.", "priority" => "must" },
          { "key" => "O-2", "title" => "Usage analytics", "description" => "Know which features are used most.", "priority" => "could" }
        ],
        "features" => [ {
          "key" => "F-1", "title" => "Email login", "description" => "Login form with email and password, already in production.",
          "status" => "done", "objective_keys" => [ "O-1" ], "assignee_count" => 1, "deadline" => nil, "score" => 9,
          "activity" => { "last_6h" => { "event_count" => 1, "people" => [ "Ada" ] }, "total" => { "event_count" => 8, "last_activity_at" => "2026-09-23T08:00:00Z", "titles" => [ "Email login" ], "files" => [ "app/auth/login.rb" ] } }
        } ],
        "unattributed" => { "count" => 0, "titles" => [] },
        "deterministic_alerts" => []
      },
      "expected" => { "coverage" => [ { "objective_key" => "O-1", "status" => "covered" }, { "objective_key" => "O-2", "status" => "uncovered" } ] }
    }
  ].freeze
end
