import { useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { Argument, Feature } from "@/types/api";

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
    // RF-PC-011: the thumb fills (or empties) right away, before the API
    // answers; if it fails, the previous state comes back.
    onMutate: async ({ argumentId, voted }) => {
      await queryClient.cancelQueries({ queryKey: featureKey(teamId, key) });
      const previous = queryClient.getQueryData<Feature>(featureKey(teamId, key));
      queryClient.setQueryData<Feature>(featureKey(teamId, key), (feature) =>
        feature && {
          ...feature,
          arguments: feature.arguments?.map((argument) =>
            argument.id === argumentId
              ? { ...argument, voted_by_me: !voted, votes: argument.votes + (voted ? -1 : 1) }
              : argument,
          ),
        },
      );
      return { previous };
    },
    onError: (_err, _vars, context) => {
      if (context?.previous) queryClient.setQueryData(featureKey(teamId, key), context.previous);
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: featureKey(teamId, key) }),
  });
}

export function useDeleteArgument(teamId: string, key: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (argumentId: string) => apiClient.delete(`/api/v1/teams/${teamId}/features/${key}/arguments/${argumentId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: featureKey(teamId, key) }),
  });
}
