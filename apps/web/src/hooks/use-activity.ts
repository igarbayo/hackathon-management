import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { ActivityEvent, ClaimResult, UnlinkedAuthor } from "@/types/activity";

interface ActivityPage {
  data: ActivityEvent[];
  next_cursor: string | null;
}

export function useActivity(
  teamId: string | undefined,
  filters: { attribution_status?: string; feature_id?: string; actor_status?: string; branch?: string },
) {
  return useInfiniteQuery({
    queryKey: ["teams", teamId, "activity", filters],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) => {
      const params = new URLSearchParams({ ...filters, ...(pageParam ? { cursor: pageParam } : {}) });
      return apiClient.get<ActivityPage>(`/api/v1/teams/${teamId}/activity?${params.toString()}`);
    },
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.next_cursor ?? undefined,
    enabled: Boolean(teamId),
  });
}

function activityKey(teamId: string) {
  return ["teams", teamId, "activity"];
}

export function useDecideAttribution(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ eventId, action, featureId }: { eventId: string; action: string; featureId?: string }) =>
      apiClient.post(`/api/v1/teams/${teamId}/activity/${eventId}/attribution`, { action, feature_id: featureId }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: activityKey(teamId) }),
  });
}

// RF-ACT-018: unlinked authors and "These are mine" / "Not mine".
export function useUnlinkedAuthors(teamId: string, enabled: boolean) {
  return useQuery({
    queryKey: [...activityKey(teamId), "unlinked-authors"],
    queryFn: () => apiClient.get<{ data: UnlinkedAuthor[] }>(`/api/v1/teams/${teamId}/activity/unlinked_authors`).then((r) => r.data),
    enabled,
  });
}

export interface ClaimInput {
  eventIds?: string[];
  author?: { github_login: string | null; email: string | null };
  membershipId?: string;
  includeFuture: boolean;
}

export function useClaimActivity(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ eventIds, author, membershipId, includeFuture }: ClaimInput) =>
      apiClient.post<ClaimResult>(`/api/v1/teams/${teamId}/activity/claim`, {
        event_ids: eventIds,
        author,
        membership_id: membershipId,
        include_future: includeFuture,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: activityKey(teamId) });
      queryClient.invalidateQueries({ queryKey: ["teams", teamId, "members"] });
    },
  });
}

export function useUnclaimActivity(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (eventIds: string[]) =>
      apiClient.post<ClaimResult>(`/api/v1/teams/${teamId}/activity/unclaim`, { event_ids: eventIds }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: activityKey(teamId) });
      queryClient.invalidateQueries({ queryKey: ["teams", teamId, "members"] });
    },
  });
}
