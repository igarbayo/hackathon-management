import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import { isImporting } from "@/lib/github-import";
import type { GithubRepository, LinkRepositoryResponse } from "@/types/github";

export function repositoriesKey(teamId: string | undefined) {
  return ["teams", teamId, "repositories"] as const;
}

export function useRepositories(teamId: string | undefined) {
  return useQuery({
    queryKey: repositoriesKey(teamId),
    queryFn: () => apiClient.get<{ data: GithubRepository[] }>(`/api/v1/teams/${teamId}/repositories`).then((r) => r.data),
    enabled: Boolean(teamId),
    // RF-GH-025: while the history is being imported, poll every 3 s to show
    // the result as soon as it finishes.
    refetchInterval: (query) => (query.state.data?.some((repo) => isImporting(repo.last_import)) ? 3000 : false),
  });
}

export function useLinkRepository(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    // The backend takes both "org/repo" and a full URL in `url`
    // (Github::RepoUrl.parse), so there is no need to tell them apart here.
    // `returnTo: "onboarding"` makes GitHub go back to the onboarding instead
    // of settings if the App has to be installed (RF-TEAM-014).
    mutationFn: ({ url, returnTo }: { url: string; returnTo?: "settings" | "onboarding" }) =>
      apiClient.post<LinkRepositoryResponse>(`/api/v1/teams/${teamId}/repositories`, { url, return_to: returnTo }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: repositoriesKey(teamId) }),
  });
}

export function useResyncRepository(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (repositoryId: string) => apiClient.post(`/api/v1/teams/${teamId}/repositories/${repositoryId}/resync`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: repositoriesKey(teamId) }),
  });
}

export function useUnlinkRepository(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (repositoryId: string) => apiClient.delete(`/api/v1/teams/${teamId}/repositories/${repositoryId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: repositoriesKey(teamId) }),
  });
}
