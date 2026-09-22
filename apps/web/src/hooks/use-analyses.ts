import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { AiAnalysis, LatestAnalysisResponse } from "@/types/analysis";

function key(teamId: string | undefined) {
  return ["teams", teamId, "analyses"] as const;
}

export function useLatestAnalysis(teamId: string | undefined) {
  return useQuery({
    queryKey: [...key(teamId), "latest"],
    queryFn: () => apiClient.get<LatestAnalysisResponse>(`/api/v1/teams/${teamId}/analyses/latest`),
    enabled: Boolean(teamId),
    refetchInterval: 15_000,
  });
}

export function useAnalysisHistory(teamId: string | undefined) {
  return useQuery({
    queryKey: key(teamId),
    queryFn: () => apiClient.get<{ data: AiAnalysis[] }>(`/api/v1/teams/${teamId}/analyses`).then((r) => r.data),
    enabled: Boolean(teamId),
  });
}

export function useRunAnalysis(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => apiClient.post<AiAnalysis>(`/api/v1/teams/${teamId}/analyses`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}
