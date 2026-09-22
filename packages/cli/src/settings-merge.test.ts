import { describe, expect, it } from "vitest";
import { mergeHooksIntoSettings, removeHooksFromSettings } from "./settings-merge";

describe("mergeHooksIntoSettings", () => {
  it("añade los 5 hooks propios sin tocar ajustes existentes que no son hooks", () => {
    const result = mergeHooksIntoSettings({ someOtherSetting: true });

    expect(result.someOtherSetting).toBe(true);
    const hooks = result.hooks as Record<string, unknown[]>;
    expect(Object.keys(hooks).sort()).toEqual(["PostToolUse", "SessionEnd", "SessionStart", "Stop", "UserPromptSubmit"].sort());
  });

  it("conserva hooks de terceros ya presentes en el mismo evento", () => {
    const existing = {
      hooks: {
        Stop: [{ hooks: [{ type: "command", command: "otra-herramienta --flag" }] }],
      },
    };

    const result = mergeHooksIntoSettings(existing);
    const stopHooks = (result.hooks as Record<string, unknown[]>).Stop;

    expect(stopHooks).toHaveLength(2);
  });

  it("es idempotente: aplicarlo dos veces no duplica la entrada propia", () => {
    const once = mergeHooksIntoSettings({});
    const twice = mergeHooksIntoSettings(once);

    const stopHooks = (twice.hooks as Record<string, unknown[]>).Stop;
    expect(stopHooks).toHaveLength(1);
  });

  it("el PostToolUse propio lleva el matcher de edición", () => {
    const result = mergeHooksIntoSettings({});
    const postToolUse = (result.hooks as Record<string, { matcher?: string }[]>).PostToolUse;

    expect(postToolUse[0].matcher).toBe("Edit|MultiEdit|Write|NotebookEdit");
  });
});

describe("removeHooksFromSettings", () => {
  it("quita solo las entradas propias y deja las de terceros", () => {
    const existing = mergeHooksIntoSettings({
      hooks: { Stop: [{ hooks: [{ type: "command", command: "otra-herramienta --flag" }] }] },
    });

    const result = removeHooksFromSettings(existing);
    const stopHooks = (result.hooks as Record<string, unknown[]>).Stop;

    expect(stopHooks).toHaveLength(1);
  });

  it("borra la clave hooks entera si no queda nada de terceros", () => {
    const existing = mergeHooksIntoSettings({});

    const result = removeHooksFromSettings(existing);

    expect(result.hooks).toBeUndefined();
  });

  it("deja el resto de ajustes exactamente como estaban (RF-CC-023)", () => {
    const existing = mergeHooksIntoSettings({ theme: "dark" });

    const result = removeHooksFromSettings(existing);

    expect(result.theme).toBe("dark");
  });
});
