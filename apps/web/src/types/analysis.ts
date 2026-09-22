export interface CoverageEntry {
  objective_key: string;
  status: "covered" | "partial" | "uncovered";
  feature_keys: string[];
  rationale: string;
}

export interface OrphanFeature {
  feature_key: string;
  rationale: string;
  recommendation: "discard" | "link_objective" | "keep";
  suggested_objective_key: string | null;
}

export interface Gap {
  objective_key: string | null;
  description: string;
  suggested_feature_title: string;
}

export interface Risk {
  severity: "low" | "medium" | "high";
  kind: string;
  description: string;
  related_keys: string[];
}

export interface AnalysisResult {
  summary: string;
  coverage: CoverageEntry[];
  orphan_features: OrphanFeature[];
  gaps: Gap[];
  risks: Risk[];
}

export interface DeterministicAlert {
  code: string;
  severity: "low" | "medium" | "high";
  related_keys: string[];
  [key: string]: unknown;
}

export interface AiAnalysis {
  id: string;
  trigger: "scheduled" | "manual";
  status: "queued" | "running" | "succeeded" | "failed" | "skipped";
  skip_reason: string | null;
  provider: string | null;
  model: string | null;
  prompt_version: string | null;
  context_stats: Record<string, number>;
  deterministic_alerts: DeterministicAlert[];
  usage: Record<string, number>;
  error: string | null;
  started_at: string | null;
  finished_at: string | null;
  created_at: string;
  result?: AnalysisResult;
}

export interface LatestAnalysisResponse {
  analysis: AiAnalysis | null;
  deterministic_alerts: DeterministicAlert[];
}
