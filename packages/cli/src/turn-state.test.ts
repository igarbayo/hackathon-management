import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

let dir: string;

vi.mock("./paths", () => ({
  paths: { turnsDir: () => dir },
}));

describe("turn-state", () => {
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "hackboard-turns-"));
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
    vi.resetModules();
  });

  it("collects files and counts tools until the turn closes", async () => {
    const { openTurn, addToolUse, closeTurn } = await import("./turn-state");

    openTurn("s1", 42);
    addToolUse("s1", { path: "a.rb", tool: "Edit" });
    addToolUse("s1", null); // tool with no file (or excluded): counted but not listed
    addToolUse("s1", { path: "b.rb", tool: "Write" });

    const turn = closeTurn("s1");

    expect(turn?.prompt_chars).toBe(42);
    expect(turn?.tool_uses).toBe(3);
    expect(turn?.files).toEqual([
      { path: "a.rb", tool: "Edit" },
      { path: "b.rb", tool: "Write" },
    ]);
  });

  it("closeTurn deletes the state: a second close finds nothing", async () => {
    const { openTurn, closeTurn } = await import("./turn-state");

    openTurn("s2", 1);
    closeTurn("s2");

    expect(closeTurn("s2")).toBeNull();
  });

  it("Stop with no earlier UserPromptSubmit does not blow up (empty turn)", async () => {
    const { closeTurn } = await import("./turn-state");

    expect(closeTurn("never-opened")).toBeNull();
  });
});
