import { describe, expect, it } from "vitest";
import { normalizeRemote } from "./git";

describe("normalizeRemote", () => {
  it("normaliza HTTPS con .git", () => {
    expect(normalizeRemote("https://github.com/org/repo.git")).toBe("github.com/org/repo");
  });

  it("normaliza SSH (git@)", () => {
    expect(normalizeRemote("git@github.com:org/repo.git")).toBe("github.com/org/repo");
  });

  it("normaliza ssh:// con usuario", () => {
    expect(normalizeRemote("ssh://git@github.com/org/repo.git")).toBe("github.com/org/repo");
  });

  it("normaliza HTTPS sin .git", () => {
    expect(normalizeRemote("https://github.com/org/repo")).toBe("github.com/org/repo");
  });

  it("devuelve null si no hay remote", () => {
    expect(normalizeRemote(null)).toBeNull();
  });

  it("devuelve null si el formato no se reconoce", () => {
    expect(normalizeRemote("no-es-una-url")).toBeNull();
  });
});
