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

// RF-FEAT-011: la interfaz es optimista y revierte si la API responde con error.
export function useMoveFeature(teamId: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (params: { key: string; status: string; before_id?: string; after_id?: string }) =>
      apiClient.post<Feature>(`/api/v1/teams/${teamId}/features/${params.key}/move`, params),
    onMutate: async (params) => {
      await queryClient.cancelQueries({ queryKey: key(teamId) });
      const previous = queryClient.getQueryData<Feature[]>(key(teamId));

      queryClient.setQueryData<Feature[]>(key(teamId), (features) =>
        features?.map((feature) => (feature.key === params.key ? { ...feature, status: params.status as Feature["status"] } : feature)),
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
