import { chmodSync, existsSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { ensureConfigDir, paths } from "./paths";

export interface Credentials {
  token: string;
  api_url: string;
  team_id: string;
  team_name: string;
  member_id: string;
  connected: boolean;
  paused: boolean;
  privacy_level: string;
}

export function readCredentials(): Credentials | null {
  try {
    return JSON.parse(readFileSync(paths.credentials(), "utf-8")) as Credentials;
  } catch {
    return null;
  }
}

// It is never stored inside the repo (init flow, step 3): always in
// ~/.config/hackboard, with 0600 permissions.
export function writeCredentials(creds: Credentials): void {
  ensureConfigDir();
  const file = paths.credentials();
  writeFileSync(file, JSON.stringify(creds, null, 2), { mode: 0o600 });
  try {
    chmodSync(file, 0o600);
  } catch {
    // Windows has no POSIX permissions; that is fine.
  }
}

export function clearCredentials(): void {
  try {
    if (existsSync(paths.credentials())) unlinkSync(paths.credentials());
  } catch {
    // no-op
  }
}

// 401 from the server (token revoked): queuing stops and `status` reports it.
export function markDisconnected(): void {
  const creds = readCredentials();
  if (!creds) return;
  writeCredentials({ ...creds, connected: false });
}
