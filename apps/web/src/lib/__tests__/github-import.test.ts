import { describe, expect, it } from "vitest";
import { importSummary, isImporting } from "@/lib/github-import";

describe("importSummary (RF-GH-025)", () => {
  it("no dice nada si nunca se ha importado", () => {
    expect(importSummary(null)).toBeNull();
  });

  it("avisa mientras se importa", () => {
    expect(isImporting({ status: "queued" })).toBe(true);
    expect(importSummary({ status: "running" })).toBe("Importando el histórico…");
  });

  it("cuenta commits y PRs con la fecha de inicio", () => {
    const summary = importSummary({ status: "done", commits: 87, pull_requests: 1, since: "2026-04-25T09:00:00Z" });
    expect(summary).toMatch(/^87 commits desde el 25 abr 2026 y 1 PR abierto\.$/);
  });

  it("explica que sin fecha de inicio no hay commits", () => {
    expect(importSummary({ status: "done", commits: 0, pull_requests: 0, reason: "no_starts_at" })).toBe(
      "El hackathon no tiene fecha de inicio, así que no se han importado commits. 0 PRs abiertos.",
    );
  });

  it("avisa si ha fallado", () => {
    expect(importSummary({ status: "failed" })).toMatch(/No se ha podido importar/);
  });
});
