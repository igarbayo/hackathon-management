import { useInfiniteQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { ActivityEvent } from "@/types/activity";

interface ActivityPage {
  data: ActivityEvent[];
  next_cursor: string | null;
}

export function useActivity(teamId: string | undefined, filters: { attribution_status?: string; feature_id?: string }) {
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
