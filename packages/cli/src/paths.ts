import { mkdirSync } from "node:fs";
import { homedir, platform } from "node:os";
import { join } from "node:path";

// ~/.config/hackboard (Windows: %APPDATA%\hackboard), 08-integracion-claude-code.md#flujo-de-init.
export function configDir(): string {
  if (platform() === "win32") {
    return join(process.env.APPDATA ?? join(homedir(), "AppData", "Roaming"), "hackboard");
  }
  return join(homedir(), ".config", "hackboard");
}

export function ensureConfigDir(): string {
  const dir = configDir();
  mkdirSync(dir, { recursive: true });
  return dir;
}

export const paths = {
  credentials: () => join(configDir(), "credentials.json"),
  config: () => join(configDir(), "config.json"),
  queue: () => join(configDir(), "queue.jsonl"),
  log: () => join(configDir(), "hook.log"),
  backoff: () => join(configDir(), "backoff.json"),
  flushLock: () => join(configDir(), "flush.lock"),
  turnsDir: () => join(configDir(), "turns"),
};
