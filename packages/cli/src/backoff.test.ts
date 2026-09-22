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

  it("no salta nada si nunca ha fallado", async () => {
    const { shouldSkip } = await import("./backoff");
    expect(shouldSkip()).toBe(false);
  });

  it("tras un fallo, salta hasta que pasa el delay inicial de 1s", async () => {
    const { recordFailure, shouldSkip } = await import("./backoff");

    recordFailure();

    expect(shouldSkip()).toBe(true);
  });

  it("recordSuccess limpia el estado de backoff", async () => {
    const { recordFailure, recordSuccess, shouldSkip } = await import("./backoff");

    recordFailure();
    recordSuccess();

    expect(shouldSkip()).toBe(false);
  });

  it("cada fallo consecutivo dobla el delay hasta el tope de 5 minutos", async () => {
    const { recordFailure } = await import("./backoff");
    const { readFileSync } = await import("node:fs");

    for (let i = 0; i < 20; i++) recordFailure();

    const state = JSON.parse(readFileSync(join(dir, "backoff.json"), "utf-8"));
    const delayMs = Date.parse(state.next_retry_at) - Date.now();

    expect(delayMs).toBeLessThanOrEqual(5 * 60 * 1000);
    expect(delayMs).toBeGreaterThan(4 * 60 * 1000);
  });
});
