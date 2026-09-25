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
    // RF-GH-025: mientras se importa el histórico, se consulta cada 3 s para
    // mostrar el resultado en cuanto acaba.
    refetchInterval: (query) => (query.state.data?.some((repo) => isImporting(repo.last_import)) ? 3000 : false),
  });
}

export function useLinkRepository(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    // El backend acepta tanto "org/repo" como una URL completa en `url`
    // (Github::RepoUrl.parse), así que no hace falta distinguir aquí.
    // `returnTo: "onboarding"` hace que, si hay que instalar la App, GitHub
    // devuelva al onboarding y no a ajustes (RF-TEAM-014).
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
