export type Role = "owner" | "member";

export interface Membership {
  team_id: string;
  team_name: string | null;
  role: Role;
}

export interface Me {
  id: string;
  email: string;
  name: string;
  avatar_url: string | null;
  github_login: string | null;
  has_password: boolean;
  gemini_api_key_configured: boolean;
  last_team_id: string | null;
  memberships: Membership[];
}

export interface Hackathon {
  name: string;
  starts_at: string | null;
  ends_at: string | null;
  timezone: string;
  url: string | null;
  challenge_text: string | null;
}

export interface Team {
  id: string;
  name: string;
  code: string;
  formatted_code: string;
  plan: "free" | "pro";
  settings: Record<string, unknown>;
  hackathon: Hackathon | null;
  created_at: string;
}

export interface ClaudeCodeStatus {
  connected: true;
  token_prefix: string;
  privacy_level: string;
  paused: boolean;
  connected_at: string | null;
  last_event_at: string | null;
}

export interface Member {
  id: string;
  user_id: string;
  role: Role;
  display_name: string;
  git_identities: string[];
  claude_code: ClaudeCodeStatus | null;
}

export interface Objective {
  id: string;
  key: string;
  number: number;
  title: string;
  description: string | null;
  priority: "must" | "should" | "could";
  position: number | null;
  archived: boolean;
  feature_count: Record<string, number>;
  created_at: string;
  updated_at: string;
}

export type FeatureStatus = "idea" | "in_progress" | "done" | "discarded";

export interface Feature {
  id: string;
  key: string;
  number: number;
  title: string;
  description: string | null;
  status: FeatureStatus;
  position: number;
  objective_ids: string[];
  assignee_ids: string[];
  deadline: string | null;
  branch_names: string[];
  score: number;
  last_activity_at: string | null;
  status_changed_at: string | null;
  updated_at: string;
  created_at: string;
  arguments?: Argument[];
}

export interface Argument {
  id: string;
  kind: "pro" | "con";
  text: string;
  author_id: string | null;
  votes: number;
  voted_by_me?: boolean;
  created_at?: string;
}

export interface Milestone {
  id: string;
  title: string;
  kind: "checkpoint" | "demo" | "submission" | "custom";
  due_at: string;
  description: string | null;
}

export interface TimelineItem {
  type: "milestone" | "feature";
  id: string;
  key?: string;
  title: string;
  kind?: string;
  due_at: string;
  overdue: boolean;
}
