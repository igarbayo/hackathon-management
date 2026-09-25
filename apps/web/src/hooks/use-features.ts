import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { Feature } from "@/types/api";

function key(teamId: string | undefined) {
  return ["teams", teamId, "features"] as const;
}

export function useFeatures(teamId: string | undefined) {
  return useQuery({
    queryKey: key(teamId),
    queryFn: () => apiClient.get<{ data: Feature[] }>(`/api/v1/teams/${teamId}/features`).then((r) => r.data),
    enabled: Boolean(teamId),
  });
}

export function useFeature(teamId: string | undefined, featureKey: string | undefined) {
  return useQuery({
    queryKey: ["teams", teamId, "features", featureKey],
    queryFn: () => apiClient.get<Feature>(`/api/v1/teams/${teamId}/features/${featureKey}`),
    enabled: Boolean(teamId) && Boolean(featureKey),
  });
}

export function useCreateFeature(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { title: string; status?: string }) =>
      apiClient.post<Feature>(`/api/v1/teams/${teamId}/features`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}

export function useUpdateFeature(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ key: featureKey, ...params }: { key: string } & Record<string, unknown>) =>
      apiClient.patch<Feature>(`/api/v1/teams/${teamId}/features/${featureKey}`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}

export function useDeleteFeature(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (featureKey: string) => apiClient.delete(`/api/v1/teams/${teamId}/features/${featureKey}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}

type MoveFeatureParams = {
  key: string;
  status: Feature["status"];
  before_id?: string;
  after_id?: string;
  position?: number;
};

// RF-FEAT-011: the UI is optimistic and rolls back if the API returns an error.
// `position` is only for the optimistic update (the caller works it out with the
// same rule as Features::Move); it is not sent to the api.
export function useMoveFeature(teamId: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ key: featureKey, status, before_id, after_id }: MoveFeatureParams) =>
      apiClient.post<Feature>(`/api/v1/teams/${teamId}/features/${featureKey}/move`, { key: featureKey, status, before_id, after_id }),
    onMutate: async (params) => {
      await queryClient.cancelQueries({ queryKey: key(teamId) });
      const previous = queryClient.getQueryData<Feature[]>(key(teamId));

      queryClient.setQueryData<Feature[]>(key(teamId), (features) =>
        features?.map((feature) =>
          feature.key === params.key
            ? { ...feature, status: params.status, position: params.position ?? feature.position }
            : feature,
        ),
      );

      return { previous };
    },
    onError: (_err, _params, context) => {
      if (context?.previous) {
        queryClient.setQueryData(key(teamId), context.previous);
      }
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: key(teamId) }),
  });
}
