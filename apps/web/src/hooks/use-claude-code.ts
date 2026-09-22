import { useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { Member } from "@/types/api";

function membersKey(teamId: string) {
  return ["teams", teamId, "members"] as const;
}

export function useUpdateMyClaudeCode(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { privacy_level?: string; paused?: boolean }) =>
      apiClient.patch<Member>(`/api/v1/teams/${teamId}/me/claude_code`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: membersKey(teamId) }),
  });
}

export function useDisconnectMyClaudeCode(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (purge: boolean) => apiClient.delete(`/api/v1/teams/${teamId}/me/claude_code${purge ? "?purge=true" : ""}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: membersKey(teamId) }),
  });
}

export function useApproveDevice(teamId: string) {
  return useMutation({
    mutationFn: (params: { user_code: string; privacy_level: string }) =>
      apiClient.post(`/api/v1/teams/${teamId}/cli/device/approve`, params),
  });
}

export function useDenyDevice(teamId: string) {
  return useMutation({
    mutationFn: (params: { user_code: string }) => apiClient.post(`/api/v1/teams/${teamId}/cli/device/deny`, params),
  });
}
