import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { homedir } from "node:os";

// Nombres de hooks tal como los espera Claude Code
// (08-integracion-claude-code.md#hooks-instalados).
export const HOOK_EVENTS = ["SessionStart", "UserPromptSubmit", "PostToolUse", "Stop", "SessionEnd"] as const;
export type HookEvent = (typeof HOOK_EVENTS)[number];

const COMMAND_BY_EVENT: Record<HookEvent, string> = {
  SessionStart: "hackboard hook session-start",
  UserPromptSubmit: "hackboard hook prompt",
  PostToolUse: "hackboard hook tool",
  Stop: "hackboard hook stop",
  SessionEnd: "hackboard hook session-end",
};

interface HookEntry {
  matcher?: string;
  hooks: { type: string; command: string; timeout: number }[];
}

function ownEntry(event: HookEvent): HookEntry {
  const entry: HookEntry = { hooks: [{ type: "command", command: COMMAND_BY_EVENT[event], timeout: 5 }] };
  if (event === "PostToolUse") entry.matcher = "Edit|MultiEdit|Write|NotebookEdit";
  return entry;
}

// Las entradas propias se identifican porque el comando empieza por
// "hackboard hook" (flujo de init, paso 5): así se puede fusionar sin tocar
// lo que ya había, y quitar limpiamente en el uninstall.
function isOwnEntry(entry: unknown): entry is HookEntry {
  const candidate = entry as HookEntry | undefined;
  return Array.isArray(candidate?.hooks) && candidate.hooks.some((h) => typeof h?.command === "string" && h.command.startsWith("hackboard hook"));
}

export function mergeHooksIntoSettings(existing: Record<string, unknown>): Record<string, unknown> {
  const settings = { ...existing };
  const hooks = { ...((settings.hooks as Record<string, unknown> | undefined) ?? {}) };

  for (const event of HOOK_EVENTS) {
    const current = Array.isArray(hooks[event]) ? (hooks[event] as unknown[]) : [];
    const withoutOwn = current.filter((entry) => !isOwnEntry(entry));
    hooks[event] = [...withoutOwn, ownEntry(event)];
  }

  settings.hooks = hooks;
  return settings;
}

export function removeHooksFromSettings(existing: Record<string, unknown>): Record<string, unknown> {
  const settings = { ...existing };
  const hooks = { ...((settings.hooks as Record<string, unknown> | undefined) ?? {}) };

  for (const event of HOOK_EVENTS) {
    if (!Array.isArray(hooks[event])) continue;
    const filtered = (hooks[event] as unknown[]).filter((entry) => !isOwnEntry(entry));
    if (filtered.length > 0) hooks[event] = filtered;
    else delete hooks[event];
  }

  if (Object.keys(hooks).length > 0) settings.hooks = hooks;
  else delete settings.hooks;

  return settings;
}

export function readSettingsFile(path: string): Record<string, unknown> {
  if (!existsSync(path)) return {};
  try {
    return JSON.parse(readFileSync(path, "utf-8")) as Record<string, unknown>;
  } catch {
    return {};
  }
}

// "Si el fichero existe, antes de escribir guarda una copia en .bak"
// (flujo de init, paso 5).
export function writeSettingsFile(path: string, settings: Record<string, unknown>): void {
  if (existsSync(path)) copyFileSync(path, `${path}.bak`);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(settings, null, 2)}\n`);
}

export function settingsPathFor(scope: "local" | "user", cwd: string): string {
  if (scope === "user") return join(homedir(), ".claude", "settings.json");
  return join(cwd, ".claude", "settings.local.json");
}
