import { describe, expect, it } from "vitest";
import { DEFAULT_EXCLUDE_GLOBS, isExcluded } from "./exclusions";

describe("isExcluded", () => {
  it("excludes .env and its variants in any folder", () => {
    expect(isExcluded(".env", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
    expect(isExcluded(".env.local", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
    expect(isExcluded("apps/api/.env", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
  });

  it("excludes files inside any secrets/ folder", () => {
    expect(isExcluded("apps/api/secrets/master.key", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
    expect(isExcluded("secrets/x", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
  });

  it("excludes .pem, .key and credentials* by extension/name", () => {
    expect(isExcluded("certs/server.pem", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
    expect(isExcluded("config/id.key", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
    expect(isExcluded("config/credentials.json", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
  });

  it("does not exclude normal repo files", () => {
    expect(isExcluded("apps/web/app/login/page.tsx", DEFAULT_EXCLUDE_GLOBS)).toBe(false);
    expect(isExcluded("README.md", DEFAULT_EXCLUDE_GLOBS)).toBe(false);
  });

  it("normalizes Windows separators before comparing", () => {
    expect(isExcluded("apps\\api\\secrets\\master.key", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
  });
});
