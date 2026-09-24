export interface Attribution {
  feature_id: string | null;
  method: "convention" | "branch" | "ai" | "manual";
  status: "confirmed" | "suggested" | "rejected";
  confidence: number | null;
  reason: string | null;
  decided_by_id: string | null;
  decided_at: string | null;
}

export interface ActivityEvent {
  id: string;
  source: "github" | "claude_code" | "mcp" | "system";
  kind: string;
  occurred_at: string;
  actor: {
    user_id?: string | null;
    membership_id?: string | null;
    display?: string;
    github_login?: string | null;
    author_name?: string | null;
    mapped_by?: "auto" | "manual" | null;
  };
  repository_id: string | null;
  branch: string | null;
  sha: string | null;
  pr_number: number | null;
  url: string | null;
  title: string | null;
  summary: string | null;
  stats: { files_changed?: number; additions?: number; deletions?: number };
  mentioned_feature_keys: string[];
  attribution: Attribution | null;
  via: { channel: string; client?: string } | null;
}

// RF-ACT-018: autor de eventos de GitHub sin usuario en el equipo.
export interface UnlinkedAuthor {
  github_login: string | null;
  email: string | null;
  author_name: string | null;
  event_count: number;
  last_event_at: string;
}

export interface ClaimResult {
  data: ActivityEvent[];
  skipped: number;
}
