import { readCredentials } from "./credentials";

export function apiBaseUrl(): string {
  return process.env.HACKBOARD_API_URL || readCredentials()?.api_url || "https://api.hackboard.app";
}

async function parseJson<T>(response: Response): Promise<T> {
  const text = await response.text();
  return (text ? JSON.parse(text) : undefined) as T;
}

export interface DeviceAuthorization {
  device_code: string;
  user_code: string;
  verification_url: string;
  expires_in: number;
  interval: number;
}

export async function createDevice(teamCode?: string): Promise<DeviceAuthorization> {
  const response = await fetch(`${apiBaseUrl()}/api/v1/cli/device`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(teamCode ? { team_code: teamCode } : {}),
  });
  if (!response.ok) throw new Error(`No se ha podido iniciar el device flow (${response.status})`);
  return parseJson<DeviceAuthorization>(response);
}

export type DeviceTokenResult =
  | { ok: true; token: string; team: { id: string; name: string; code: string }; member: { id: string; display_name: string } }
  | { ok: false; error: string };

export async function pollDeviceToken(deviceCode: string): Promise<DeviceTokenResult> {
  const response = await fetch(`${apiBaseUrl()}/api/v1/cli/device/token`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ device_code: deviceCode }),
  });
  const payload = await parseJson<Record<string, unknown>>(response);
  if (response.ok) {
    return { ok: true, ...(payload as { token: string; team: { id: string; name: string; code: string }; member: { id: string; display_name: string } }) };
  }
  return { ok: false, error: (payload?.error as string) ?? "unknown_error" };
}

export interface CliConfigResponse {
  repos: string[];
  exclude_globs: string[];
}

export async function fetchConfig(token: string): Promise<CliConfigResponse> {
  const response = await fetch(`${apiBaseUrl()}/api/v1/cli/config`, { headers: { Authorization: `Bearer ${token}` } });
  if (!response.ok) throw new Error(`No se ha podido descargar /cli/config (${response.status})`);
  return parseJson<CliConfigResponse>(response);
}

export type IngestResult =
  | { ok: true; accepted: number; duplicates: number; rejected: { client_event_id: string; reason: string }[] }
  | { ok: false; revoked: boolean };

export async function ingestBatch(token: string, cliVersion: string, events: Record<string, unknown>[]): Promise<IngestResult> {
  const response = await fetch(`${apiBaseUrl()}/api/v1/ingest/claude_code`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ cli_version: cliVersion, events }),
  });

  if (response.status === 401) return { ok: false, revoked: true };
  if (!response.ok) return { ok: false, revoked: false };

  const payload = await parseJson<{ accepted: number; duplicates: number; rejected: { client_event_id: string; reason: string }[] }>(response);
  return { ok: true, ...payload };
}

export async function updateMyLink(token: string, params: { privacy_level?: string; paused?: boolean }): Promise<void> {
  const response = await fetch(`${apiBaseUrl()}/api/v1/cli/me`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify(params),
  });
  if (!response.ok) throw new Error(`No se ha podido sincronizar con el servidor (${response.status})`);
}

export async function revokeMyLink(token: string, purge: boolean): Promise<void> {
  await fetch(`${apiBaseUrl()}/api/v1/cli/me${purge ? "?purge=true" : ""}`, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${token}` },
  });
}
