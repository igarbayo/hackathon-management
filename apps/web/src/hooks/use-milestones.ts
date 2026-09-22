import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { Milestone, TimelineItem } from "@/types/api";

function key(teamId: string | undefined) {
  return ["teams", teamId, "milestones"] as const;
}

export function useMilestones(teamId: string | undefined) {
  return useQuery({
    queryKey: key(teamId),
    queryFn: () => apiClient.get<{ data: Milestone[] }>(`/api/v1/teams/${teamId}/milestones`).then((r) => r.data),
    enabled: Boolean(teamId),
  });
}

export function useCreateMilestone(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { title: string; kind: string; due_at: string; description?: string }) =>
      apiClient.post<Milestone>(`/api/v1/teams/${teamId}/milestones`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}

export function useDeleteMilestone(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/api/v1/teams/${teamId}/milestones/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}

export function useTimeline(teamId: string | undefined) {
  return useQuery({
    queryKey: ["teams", teamId, "timeline"],
    queryFn: () => apiClient.get<{ data: TimelineItem[] }>(`/api/v1/teams/${teamId}/timeline`).then((r) => r.data),
    enabled: Boolean(teamId),
  });
}
