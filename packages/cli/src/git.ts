import { execFileSync } from "node:child_process";
import { relative, sep } from "node:path";

interface CacheEntry<T> {
  value: T;
  at: number;
}

// The remote is cached per cwd with no explicit TTL ("cached per cwd" in the
// spec): a hook process lives for milliseconds, so it is enough not to call git
// twice in the same run. Branch and HEAD do have a short TTL because they
// change during a single long session.
const remoteCache = new Map<string, CacheEntry<string | null>>();
const branchCache = new Map<string, CacheEntry<string | null>>();
const headCache = new Map<string, CacheEntry<string | null>>();
const SHORT_TTL_MS = 2000;

function run(cwd: string, args: string[]): string | null {
  try {
    const output = execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    return output || null;
  } catch {
    return null;
  }
}

function cached(cache: Map<string, CacheEntry<string | null>>, cwd: string, ttlMs: number, compute: () => string | null): string | null {
  const hit = cache.get(cwd);
  if (hit && Date.now() - hit.at < ttlMs) return hit.value;

  const value = compute();
  cache.set(cwd, { value, at: Date.now() });
  return value;
}

export function isInsideGitRepo(cwd: string): boolean {
  return run(cwd, ["rev-parse", "--is-inside-work-tree"]) === "true";
}

export function getRemote(cwd: string): string | null {
  return cached(remoteCache, cwd, Number.POSITIVE_INFINITY, () => normalizeRemote(run(cwd, ["config", "--get", "remote.origin.url"])));
}

export function getBranch(cwd: string): string | null {
  return cached(branchCache, cwd, SHORT_TTL_MS, () => run(cwd, ["rev-parse", "--abbrev-ref", "HEAD"]));
}

export function getHeadSha(cwd: string): string | null {
  return cached(headCache, cwd, SHORT_TTL_MS, () => run(cwd, ["rev-parse", "HEAD"]));
}

export function getRepoRoot(cwd: string): string | null {
  return run(cwd, ["rev-parse", "--show-toplevel"]);
}

// "https://github.com/org/repo.git", "git@github.com:org/repo.git",
// "ssh://git@github.com/org/repo" -> "github.com/org/repo", the same as
// Github::RepoUrl on the server side (07-integracion-github.md).
export function normalizeRemote(raw: string | null): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();

  const patterns = [/^git@([^:]+):(.+?)(\.git)?\/?$/, /^(?:https?|ssh):\/\/(?:[^@/]+@)?([^/]+)\/(.+?)(\.git)?\/?$/];
  for (const pattern of patterns) {
    const match = trimmed.match(pattern);
    if (match) return `${match[1]}/${match[2].replace(/\.git$/, "")}`;
  }
  return null;
}

export function toRepoRelativePath(cwd: string, absolutePath: string): string | null {
  const root = getRepoRoot(cwd);
  if (!root) return null;

  const rel = relative(root, absolutePath);
  if (rel.startsWith("..") || rel === "") return null;

  return rel.split(sep).join("/");
}
