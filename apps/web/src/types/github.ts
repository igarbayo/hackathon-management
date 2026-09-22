export interface GithubRepository {
  id: string;
  github_repo_id: number;
  full_name: string;
  default_branch: string;
  active: boolean;
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
