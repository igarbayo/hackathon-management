import { useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { Argument } from "@/types/api";

function featureKey(teamId: string, key: string) {
  return ["teams", teamId, "features", key] as const;
}

export function useCreateArgument(teamId: string, key: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { kind: "pro" | "con"; text: string }) =>
      apiClient.post<Argument>(`/api/v1/teams/${teamId}/features/${key}/arguments`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: featureKey(teamId, key) }),
  });
}

export function useVoteArgument(teamId: string, key: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ argumentId, voted }: { argumentId: string; voted: boolean }) =>
      voted
        ? apiClient.delete<Argument>(`/api/v1/teams/${teamId}/features/${key}/arguments/${argumentId}/vote`)
        : apiClient.put<Argument>(`/api/v1/teams/${teamId}/features/${key}/arguments/${argumentId}/vote`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: featureKey(teamId, key) }),
  });
}

export function useDeleteArgument(teamId: string, key: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (argumentId: string) => apiClient.delete(`/api/v1/teams/${teamId}/features/${key}/arguments/${argumentId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: featureKey(teamId, key) }),
  });
}
