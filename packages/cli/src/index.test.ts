import { describe, expect, it } from "vitest";
import { CLI_NAME, CLI_VERSION } from "./index";

describe("cli package metadata", () => {
  it("exposes the package name", () => {
    expect(CLI_NAME).toBe("hackboard");
  });

  it("exposes a semantic version", () => {
    expect(CLI_VERSION).toMatch(/^\d+\.\d+\.\d+/);
  });
});
