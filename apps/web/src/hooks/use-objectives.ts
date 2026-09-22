import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { Objective } from "@/types/api";

function key(teamId: string | undefined) {
  return ["teams", teamId, "objectives"] as const;
}

export function useObjectives(teamId: string | undefined) {
  return useQuery({
    queryKey: key(teamId),
    queryFn: () => apiClient.get<{ data: Objective[] }>(`/api/v1/teams/${teamId}/objectives`).then((r) => r.data),
    enabled: Boolean(teamId),
  });
}

export function useCreateObjective(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { title: string; description?: string; priority: string }) =>
      apiClient.post<Objective>(`/api/v1/teams/${teamId}/objectives`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}

export function useUpdateObjective(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...params }: { id: string } & Record<string, unknown>) =>
      apiClient.patch<Objective>(`/api/v1/teams/${teamId}/objectives/${id}`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}

export function useDeleteObjective(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/api/v1/teams/${teamId}/objectives/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}
