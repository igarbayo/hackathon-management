import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import { meKey } from "@/hooks/use-me";
import type { Member, Team } from "@/types/api";

export function useCreateTeam() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: {
      name: string;
      hackathon: { name: string; starts_at?: string; ends_at: string; timezone: string };
    }) => apiClient.post<Team>("/api/v1/teams", params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: meKey }),
  });
}

export function useJoinTeam() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (code: string) => apiClient.post<{ team_id: string; role: string }>("/api/v1/teams/join", { code }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: meKey }),
  });
}

export function useTeam(teamId: string | undefined) {
  return useQuery({
    queryKey: ["teams", teamId],
    queryFn: () => apiClient.get<Team>(`/api/v1/teams/${teamId}`),
    enabled: Boolean(teamId),
  });
}

export function useUpdateTeam(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: Record<string, unknown>) => apiClient.patch<Team>(`/api/v1/teams/${teamId}`, params),
    onSuccess: (team) => queryClient.setQueryData(["teams", teamId], team),
  });
}

export function useRotateTeamCode(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => apiClient.post<Team>(`/api/v1/teams/${teamId}/code/rotate`),
    onSuccess: (team) => queryClient.setQueryData(["teams", teamId], team),
  });
}

export function useMembers(teamId: string | undefined) {
  return useQuery({
    queryKey: ["teams", teamId, "members"],
    queryFn: () => apiClient.get<{ data: Member[] }>(`/api/v1/teams/${teamId}/members`).then((r) => r.data),
    enabled: Boolean(teamId),
  });
}

export function useUpdateMember(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ memberId, ...params }: { memberId: string } & Record<string, unknown>) =>
      apiClient.patch<Member>(`/api/v1/teams/${teamId}/members/${memberId}`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["teams", teamId, "members"] }),
  });
}

export function useRemoveMember(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (memberId: string) => apiClient.delete(`/api/v1/teams/${teamId}/members/${memberId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["teams", teamId, "members"] }),
  });
}
