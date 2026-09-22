import { readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { ensureConfigDir, paths } from "./paths";

// Backoff exponencial 1s -> 5min entre reintentos de flush
// (08-integracion-claude-code.md#envío-flush). Persiste entre invocaciones
// porque cada `hackboard flush` es un proceso nuevo.
const INITIAL_MS = 1000;
const MAX_MS = 5 * 60 * 1000;

interface BackoffState {
  attempt: number;
  next_retry_at: string;
}

function read(): BackoffState | null {
  try {
    return JSON.parse(readFileSync(paths.backoff(), "utf-8")) as BackoffState;
  } catch {
    return null;
  }
}

export function shouldSkip(): boolean {
  const state = read();
  if (!state) return false;
  return Date.now() < Date.parse(state.next_retry_at);
}

export function recordFailure(): void {
  const attempt = (read()?.attempt ?? 0) + 1;
  const delay = Math.min(MAX_MS, INITIAL_MS * 2 ** (attempt - 1));
  ensureConfigDir();
  writeFileSync(paths.backoff(), JSON.stringify({ attempt, next_retry_at: new Date(Date.now() + delay).toISOString() }));
}

export function recordSuccess(): void {
  try {
    unlinkSync(paths.backoff());
  } catch {
    // no-op: puede que no hubiera fallos previos
  }
}
