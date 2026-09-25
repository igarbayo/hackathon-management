import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "@/lib/api-client";
import type { Me } from "@/types/api";

export const meKey = ["me"] as const;

export function useMe(options?: { enabled?: boolean }) {
  return useQuery({
    queryKey: meKey,
    queryFn: () => apiClient.get<Me>("/api/v1/me"),
    retry: false,
    enabled: options?.enabled,
  });
}

export function useSignUp() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { email: string; name: string; password: string }) =>
      apiClient.post<Me>("/api/v1/auth/signup", params),
    onSuccess: (me) => queryClient.setQueryData(meKey, me),
  });
}

export function useLogIn() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { email: string; password: string }) => apiClient.post<Me>("/api/v1/auth/login", params),
    onSuccess: (me) => queryClient.setQueryData(meKey, me),
  });
}

export function useUpdateMe() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { name?: string; password?: string; gemini_api_key?: string; profile_completed?: boolean }) =>
      apiClient.patch<Me>("/api/v1/me", params),
    onSuccess: (me) => queryClient.setQueryData(meKey, me),
  });
}

export function useLogOut() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => apiClient.post("/api/v1/auth/logout"),
    onSuccess: () => queryClient.clear(),
  });
}

// RF-AUTH-007: borra la cuenta y la sesión en el servidor; aquí solo se
// vacía la caché para que nada del usuario quede en memoria.
export function useDeleteMe() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => apiClient.delete("/api/v1/me"),
    onSuccess: () => queryClient.clear(),
  });
}
