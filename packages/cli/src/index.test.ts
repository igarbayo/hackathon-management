import { describe, expect, it } from "vitest";
import { CLI_NAME, CLI_VERSION } from "./index";

describe("cli package metadata", () => {
  it("expone el nombre del paquete", () => {
    expect(CLI_NAME).toBe("hackboard");
  });

  it("expone una versión semántica", () => {
    expect(CLI_VERSION).toMatch(/^\d+\.\d+\.\d+/);
  });
});
