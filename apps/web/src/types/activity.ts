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
  actor: { user_id?: string; membership_id?: string; display?: string; github_login?: string };
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
