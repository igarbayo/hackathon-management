import { appendFileSync, existsSync, renameSync, statSync } from "node:fs";
import { ensureConfigDir, paths } from "./paths";

const MAX_LOG_BYTES = 1_000_000;

// RNF-CC-001: hooks never write to stdout or break Claude Code, so any error
// goes here. If even this fails, the error is swallowed: a hook cannot fail
// because it cannot log.
export function log(message: string): void {
  try {
    ensureConfigDir();
    rotateIfNeeded();
    appendFileSync(paths.log(), `${new Date().toISOString()} ${message}\n`);
  } catch {
    // no-op
  }
}

function rotateIfNeeded(): void {
  const file = paths.log();
  if (!existsSync(file)) return;
  if (statSync(file).size < MAX_LOG_BYTES) return;
  renameSync(file, `${file}.bak`);
}
