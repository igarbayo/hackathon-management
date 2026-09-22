import { describe, expect, it } from "vitest";
import { DEFAULT_EXCLUDE_GLOBS, isExcluded } from "./exclusions";

describe("isExcluded", () => {
  it("excluye .env y variantes en cualquier carpeta", () => {
    expect(isExcluded(".env", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
    expect(isExcluded(".env.local", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
    expect(isExcluded("apps/api/.env", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
  });

  it("excluye ficheros dentro de cualquier carpeta secrets/", () => {
    expect(isExcluded("apps/api/secrets/master.key", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
    expect(isExcluded("secrets/x", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
  });

  it("excluye .pem, .key y credentials* por extensión/nombre", () => {
    expect(isExcluded("certs/server.pem", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
    expect(isExcluded("config/id.key", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
    expect(isExcluded("config/credentials.json", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
  });

  it("no excluye ficheros normales del repo", () => {
    expect(isExcluded("apps/web/app/login/page.tsx", DEFAULT_EXCLUDE_GLOBS)).toBe(false);
    expect(isExcluded("README.md", DEFAULT_EXCLUDE_GLOBS)).toBe(false);
  });

  it("normaliza separadores de Windows antes de comparar", () => {
    expect(isExcluded("apps\\api\\secrets\\master.key", DEFAULT_EXCLUDE_GLOBS)).toBe(true);
  });
});
