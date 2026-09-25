import { existsSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { ensureConfigDir, paths } from "./paths";

// "A file lock keeps two flushes from running at once" (08-integracion-claude-code.md).
// Based on the file age, not on checking the PID: it is simpler and enough for the volume
// of a hooks CLI.
const STALE_MS = 5 * 60 * 1000;

export function acquireLock(): boolean {
  const file = paths.flushLock();
  try {
    if (existsSync(file) && Date.now() - statSync(file).mtimeMs < STALE_MS) {
      return false;
    }
    ensureConfigDir();
    writeFileSync(file, String(process.pid));
    return true;
  } catch {
    return true;
  }
}

export function releaseLock(): void {
  try {
    unlinkSync(paths.flushLock());
  } catch {
    // no-op
  }
}
