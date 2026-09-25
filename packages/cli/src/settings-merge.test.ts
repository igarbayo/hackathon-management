import { describe, expect, it } from "vitest";
import { mergeHooksIntoSettings, removeHooksFromSettings } from "./settings-merge";

describe("mergeHooksIntoSettings", () => {
  it("adds our 5 hooks without touching existing settings that are not hooks", () => {
    const result = mergeHooksIntoSettings({ someOtherSetting: true });

    expect(result.someOtherSetting).toBe(true);
    const hooks = result.hooks as Record<string, unknown[]>;
    expect(Object.keys(hooks).sort()).toEqual(["PostToolUse", "SessionEnd", "SessionStart", "Stop", "UserPromptSubmit"].sort());
  });

  it("keeps third-party hooks already present on the same event", () => {
    const existing = {
      hooks: {
        Stop: [{ hooks: [{ type: "command", command: "other-tool --flag" }] }],
      },
    };

    const result = mergeHooksIntoSettings(existing);
    const stopHooks = (result.hooks as Record<string, unknown[]>).Stop;

    expect(stopHooks).toHaveLength(2);
  });

  it("is idempotent: applying it twice does not duplicate our entry", () => {
    const once = mergeHooksIntoSettings({});
    const twice = mergeHooksIntoSettings(once);

    const stopHooks = (twice.hooks as Record<string, unknown[]>).Stop;
    expect(stopHooks).toHaveLength(1);
  });

  it("our PostToolUse entry has the edit matcher", () => {
    const result = mergeHooksIntoSettings({});
    const postToolUse = (result.hooks as Record<string, { matcher?: string }[]>).PostToolUse;

    expect(postToolUse[0].matcher).toBe("Edit|MultiEdit|Write|NotebookEdit");
  });
});

describe("removeHooksFromSettings", () => {
  it("removes only our entries and leaves third-party ones", () => {
    const existing = mergeHooksIntoSettings({
      hooks: { Stop: [{ hooks: [{ type: "command", command: "other-tool --flag" }] }] },
    });

    const result = removeHooksFromSettings(existing);
    const stopHooks = (result.hooks as Record<string, unknown[]>).Stop;

    expect(stopHooks).toHaveLength(1);
  });

  it("deletes the whole hooks key if no third-party entries are left", () => {
    const existing = mergeHooksIntoSettings({});

    const result = removeHooksFromSettings(existing);

    expect(result.hooks).toBeUndefined();
  });

  it("leaves the other settings exactly as they were (RF-CC-023)", () => {
    const existing = mergeHooksIntoSettings({ theme: "dark" });

    const result = removeHooksFromSettings(existing);

    expect(result.theme).toBe("dark");
  });
});
