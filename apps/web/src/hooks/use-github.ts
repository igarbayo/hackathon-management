import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { GithubRepository, LinkRepositoryResponse } from "@/types/github";

function key(teamId: string | undefined) {
  return ["teams", teamId, "repositories"] as const;
}

export function useRepositories(teamId: string | undefined) {
  return useQuery({
    queryKey: key(teamId),
    queryFn: () => apiClient.get<{ data: GithubRepository[] }>(`/api/v1/teams/${teamId}/repositories`).then((r) => r.data),
    enabled: Boolean(teamId),
  });
}

export function useLinkRepository(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    // El backend acepta tanto "org/repo" como una URL completa en `url`
    // (Github::RepoUrl.parse), así que no hace falta distinguir aquí.
    mutationFn: (urlOrFullName: string) =>
      apiClient.post<LinkRepositoryResponse>(`/api/v1/teams/${teamId}/repositories`, { url: urlOrFullName }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}

export function useResyncRepository(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (repositoryId: string) => apiClient.post(`/api/v1/teams/${teamId}/repositories/${repositoryId}/resync`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}

export function useUnlinkRepository(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (repositoryId: string) => apiClient.delete(`/api/v1/teams/${teamId}/repositories/${repositoryId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}
