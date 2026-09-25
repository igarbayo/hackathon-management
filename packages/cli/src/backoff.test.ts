import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

let dir: string;

vi.mock("./paths", () => ({
  ensureConfigDir: () => dir,
  paths: { backoff: () => join(dir, "backoff.json") },
}));

describe("backoff", () => {
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "hackboard-backoff-"));
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
    vi.resetModules();
  });

  it("skips nothing if it has never failed", async () => {
    const { shouldSkip } = await import("./backoff");
    expect(shouldSkip()).toBe(false);
  });

  it("after a failure, skips until the initial 1s delay has passed", async () => {
    const { recordFailure, shouldSkip } = await import("./backoff");

    recordFailure();

    expect(shouldSkip()).toBe(true);
  });

  it("recordSuccess clears the backoff state", async () => {
    const { recordFailure, recordSuccess, shouldSkip } = await import("./backoff");

    recordFailure();
    recordSuccess();

    expect(shouldSkip()).toBe(false);
  });

  it("each failure in a row doubles the delay up to the 5 minute cap", async () => {
    const { recordFailure } = await import("./backoff");
    const { readFileSync } = await import("node:fs");

    for (let i = 0; i < 20; i++) recordFailure();

    const state = JSON.parse(readFileSync(join(dir, "backoff.json"), "utf-8"));
    const delayMs = Date.parse(state.next_retry_at) - Date.now();

    expect(delayMs).toBeLessThanOrEqual(5 * 60 * 1000);
    expect(delayMs).toBeGreaterThan(4 * 60 * 1000);
  });
});
