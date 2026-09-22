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

// Nunca se guarda dentro del repo (flujo de init, paso 3): siempre en
// ~/.config/hackboard, con permisos 0600.
export function writeCredentials(creds: Credentials): void {
  ensureConfigDir();
  const file = paths.credentials();
  writeFileSync(file, JSON.stringify(creds, null, 2), { mode: 0o600 });
  try {
    chmodSync(file, 0o600);
  } catch {
    // Windows no tiene permisos POSIX; no pasa nada.
  }
}

export function clearCredentials(): void {
  try {
    if (existsSync(paths.credentials())) unlinkSync(paths.credentials());
  } catch {
    // no-op
  }
}

// 401 del servidor (token revocado): se deja de encolar y `status` lo avisa.
export function markDisconnected(): void {
  const creds = readCredentials();
  if (!creds) return;
  writeCredentials({ ...creds, connected: false });
}
