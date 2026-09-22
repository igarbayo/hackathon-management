import { useMutation, useQuery } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";

export interface ConsentInfo {
  client: { name: string; client_uri: string | null; logo_uri: string | null; first_party: boolean };
  redirect_uri: string;
  scopes: string[];
}

export function useConsentInfo(requestId: string | undefined) {
  return useQuery({
    queryKey: ["oauth", "consent_info", requestId],
    queryFn: () => apiClient.get<ConsentInfo>(`/oauth/consent_info?request_id=${encodeURIComponent(requestId ?? "")}`),
    enabled: Boolean(requestId),
    retry: false,
  });
}

export function useDecideAuthorization() {
  return useMutation({
    mutationFn: (params: { request_id: string; approve: boolean; team_id?: string; scopes?: string[] }) =>
      apiClient.post<{ redirect_url: string }>("/oauth/authorize/decision", params),
  });
}
