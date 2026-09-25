// RF-GH-025: result of the last history import.
export interface GithubImport {
  status: "queued" | "running" | "done" | "failed";
  commits?: number;
  branches?: number;
  pull_requests?: number;
  since?: string;
  // "stalled": queued or running past `expires_at`, reported as failed (RF-GH-025).
  reason?: "no_starts_at" | "stalled";
  expires_at?: string;
  finished_at?: string;
}

export interface GithubRepository {
  id: string;
  github_repo_id: number;
  full_name: string;
  default_branch: string;
  active: boolean;
  last_import: GithubImport | null;
}

export interface LinkRepositoryResponse {
  id?: string;
  github_repo_id?: number;
  full_name?: string;
  default_branch?: string;
  active?: boolean;
  needs_install?: boolean;
  install_url?: string;
}
