import { describe, expect, it } from "vitest";
import { normalizeRemote } from "./git";

describe("normalizeRemote", () => {
  it("normalizes HTTPS with .git", () => {
    expect(normalizeRemote("https://github.com/org/repo.git")).toBe("github.com/org/repo");
  });

  it("normalizes SSH (git@)", () => {
    expect(normalizeRemote("git@github.com:org/repo.git")).toBe("github.com/org/repo");
  });

  it("normalizes ssh:// with a user", () => {
    expect(normalizeRemote("ssh://git@github.com/org/repo.git")).toBe("github.com/org/repo");
  });

  it("normalizes HTTPS without .git", () => {
    expect(normalizeRemote("https://github.com/org/repo")).toBe("github.com/org/repo");
  });

  it("returns null if there is no remote", () => {
    expect(normalizeRemote(null)).toBeNull();
  });

  it("returns null if the format is not recognized", () => {
    expect(normalizeRemote("not-a-url")).toBeNull();
  });
});
