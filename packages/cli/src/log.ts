import { appendFileSync, existsSync, renameSync, statSync } from "node:fs";
import { ensureConfigDir, paths } from "./paths";

const MAX_LOG_BYTES = 1_000_000;

// RNF-CC-001: los hooks nunca escriben en stdout ni rompen Claude Code, así
// que cualquier error va aquí. Si ni siquiera esto funciona, se traga el
// error: un hook no puede fallar por no poder loguear.
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
