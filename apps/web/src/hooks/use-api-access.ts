import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";

export interface ApiToken {
  id: string;
  kind: string;
  name: string;
  token_prefix: string;
  scopes: string[];
  membership_id: string | null;
  created_by_id: string | null;
  expires_at: string | null;
  last_used_at: string | null;
  revoked_at: string | null;
}

export interface OutboundWebhook {
  id: string;
  url: string;
  events: string[];
  active: boolean;
  consecutive_failures: number;
  created_by_id: string | null;
  created_at: string;
}

export interface OutboundDelivery {
  id: string;
  event: string;
  status: string;
  attempts: number;
  response_status: number | null;
  duration_ms: number | null;
  next_attempt_at: string | null;
  created_at: string;
}

export interface OAuthConnection {
  id: string;
  client: { id: string | null; name: string | null; first_party: boolean };
  team_id: string;
  scopes: string[];
  last_used_at: string | null;
  created_at: string;
}

export interface TeamOAuthConnection {
  id: string;
  client: { id: string | null; name: string | null; first_party: boolean };
  user: { id: string | null; display_name: string | null };
  scopes: string[];
  last_used_at: string | null;
  created_at: string;
}

function tokensKey(teamId: string) {
  return ["teams", teamId, "tokens"] as const;
}

export function useTokens(teamId: string) {
  return useQuery({
    queryKey: tokensKey(teamId),
    queryFn: () => apiClient.get<{ data: ApiToken[] }>(`/api/v1/teams/${teamId}/tokens`).then((r) => r.data),
  });
}

export function useCreateToken(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { name: string; preset: string }) =>
      apiClient.post<ApiToken & { token: string }>(`/api/v1/teams/${teamId}/tokens`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: tokensKey(teamId) }),
  });
}

export function useRevokeToken(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/api/v1/teams/${teamId}/tokens/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: tokensKey(teamId) }),
  });
}

function integrationsKey(teamId: string) {
  return ["teams", teamId, "integrations"] as const;
}

export function useIntegrations(teamId: string) {
  return useQuery({
    queryKey: integrationsKey(teamId),
    queryFn: () => apiClient.get<{ data: ApiToken[] }>(`/api/v1/teams/${teamId}/integrations`).then((r) => r.data),
  });
}

export function useCreateIntegration(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { name: string; scopes: string[] }) =>
      apiClient.post<ApiToken & { token: string }>(`/api/v1/teams/${teamId}/integrations`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: integrationsKey(teamId) }),
  });
}

export function useRevokeIntegration(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/api/v1/teams/${teamId}/integrations/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: integrationsKey(teamId) }),
  });
}

export function useRotateIntegration(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient.post<ApiToken & { token: string }>(`/api/v1/teams/${teamId}/integrations/${id}/rotate`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: integrationsKey(teamId) }),
  });
}

function webhooksKey(teamId: string) {
  return ["teams", teamId, "webhooks"] as const;
}

export function useWebhooks(teamId: string) {
  return useQuery({
    queryKey: webhooksKey(teamId),
    queryFn: () => apiClient.get<{ data: OutboundWebhook[] }>(`/api/v1/teams/${teamId}/webhooks`).then((r) => r.data),
  });
}

export function useCreateWebhook(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { url: string; events: string[] }) =>
      apiClient.post<OutboundWebhook & { secret: string }>(`/api/v1/teams/${teamId}/webhooks`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: webhooksKey(teamId) }),
  });
}

export function useUpdateWebhook(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...params }: { id: string; active?: boolean; events?: string[] }) =>
      apiClient.patch<OutboundWebhook>(`/api/v1/teams/${teamId}/webhooks/${id}`, params),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: webhooksKey(teamId) }),
  });
}

export function useDeleteWebhook(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/api/v1/teams/${teamId}/webhooks/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: webhooksKey(teamId) }),
  });
}

export function useTestWebhook(teamId: string) {
  return useMutation({
    mutationFn: (id: string) => apiClient.post(`/api/v1/teams/${teamId}/webhooks/${id}/test`),
  });
}

export function useRotateWebhookSecret(teamId: string) {
  return useMutation({
    mutationFn: (id: string) => apiClient.post<OutboundWebhook & { secret: string }>(`/api/v1/teams/${teamId}/webhooks/${id}/rotate_secret`),
  });
}

export function useWebhookDeliveries(teamId: string, webhookId: string | null) {
  return useQuery({
    queryKey: ["teams", teamId, "webhooks", webhookId, "deliveries"],
    queryFn: () => apiClient.get<{ data: OutboundDelivery[] }>(`/api/v1/teams/${teamId}/webhooks/${webhookId}/deliveries`).then((r) => r.data),
    enabled: Boolean(webhookId),
  });
}

export function useRedeliverWebhook(teamId: string) {
  return useMutation({
    mutationFn: ({ webhookId, deliveryId }: { webhookId: string; deliveryId: string }) =>
      apiClient.post(`/api/v1/teams/${teamId}/webhooks/${webhookId}/deliveries/${deliveryId}/redeliver`),
  });
}

const connectionsKey = ["me", "oauth_connections"] as const;

export function useOAuthConnections() {
  return useQuery({
    queryKey: connectionsKey,
    queryFn: () => apiClient.get<{ data: OAuthConnection[] }>("/api/v1/me/oauth_connections").then((r) => r.data),
  });
}

export function useRevokeOAuthConnection() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/api/v1/me/oauth_connections/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: connectionsKey }),
  });
}

function teamOAuthConnectionsKey(teamId: string) {
  return ["teams", teamId, "oauth_connections"] as const;
}

export function useTeamOAuthConnections(teamId: string) {
  return useQuery({
    queryKey: teamOAuthConnectionsKey(teamId),
    queryFn: () => apiClient.get<{ data: TeamOAuthConnection[] }>(`/api/v1/teams/${teamId}/oauth_connections`).then((r) => r.data),
  });
}

export function useRevokeTeamOAuthConnection(teamId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient.delete(`/api/v1/teams/${teamId}/oauth_connections/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: teamOAuthConnectionsKey(teamId) }),
  });
}
