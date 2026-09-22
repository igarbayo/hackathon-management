import { readFileSync, writeFileSync } from "node:fs";
import { ensureConfigDir, paths } from "./paths";

export interface CliConfigCache {
  repos: string[];
  exclude_globs: string[];
  fetched_at: string;
}

const REFRESH_INTERVAL_MS = 15 * 60 * 1000;

export function readConfigCache(): CliConfigCache | null {
  try {
    return JSON.parse(readFileSync(paths.config(), "utf-8")) as CliConfigCache;
  } catch {
    return null;
  }
}

export function writeConfigCache(cache: CliConfigCache): void {
  ensureConfigDir();
  writeFileSync(paths.config(), JSON.stringify(cache, null, 2));
}

export function isStale(cache: CliConfigCache | null): boolean {
  if (!cache) return true;
  return Date.now() - Date.parse(cache.fetched_at) > REFRESH_INTERVAL_MS;
}
