import { existsSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { ensureConfigDir, paths } from "./paths";

// "Un lock de fichero evita que haya dos flush a la vez" (08-integracion-claude-code.md).
// Basado en la edad del fichero, no en comprobar el PID: es más simple y
// suficiente para el volumen de un CLI de hooks.
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
