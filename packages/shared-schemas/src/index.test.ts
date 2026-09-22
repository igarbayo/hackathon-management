import Ajv from "ajv";
import addFormats from "ajv-formats";
import { describe, expect, it } from "vitest";
import { getSchema, listSchemaNames } from "./index";

describe("shared-schemas loader", () => {
  it("lista los schemas disponibles" , () => {
    expect(listSchemaNames()).toContain("coverage-analysis");
  });

  it("lanza un error legible si se pide un schema que no existe", () => {
    expect(() => getSchema("no-existe")).toThrowError(/No existe el schema/);
  });

  it("coverage-analysis es un JSON Schema válido que compila con ajv", () => {
    const schema = getSchema("coverage-analysis");
    const ajv = new Ajv();

    expect(() => ajv.compile(schema)).not.toThrow();
  });

  it("coverage-analysis valida una salida de ejemplo conforme al esquema de 06-analisis-ia.md", () => {
    const schema = getSchema("coverage-analysis");
    const ajv = new Ajv();
    const validate = ajv.compile(schema);

    const sample = {
      summary: "Vais bien de tiempo, falta cubrir O-2.",
      coverage: [
        { objective_key: "O-1", status: "covered", feature_keys: ["F-3"], rationale: "F-3 está done" },
        { objective_key: "O-2", status: "uncovered", feature_keys: [], rationale: "no evaluado" },
      ],
      orphan_features: [
        { feature_key: "F-9", rationale: "no vinculada", recommendation: "link_objective", suggested_objective_key: "O-1" },
      ],
      gaps: [{ objective_key: "O-2", description: "falta login", suggested_feature_title: "Login con GitHub" }],
      risks: [{ severity: "high", kind: "deadline", description: "F-3 vence en 1h", related_keys: ["F-3"] }],
    };

    expect(validate(sample)).toBe(true);
  });

  it("ingest-claude-code valida un lote de ejemplo conforme a 08-integracion-claude-code.md", () => {
    const schema = getSchema("ingest-claude-code");
    const ajv = new Ajv(); addFormats(ajv);
    const validate = ajv.compile(schema);

    const sample = {
      cli_version: "0.3.1",
      events: [
        {
          client_event_id: "01J9Z000000000000000000000",
          kind: "cc_turn",
          occurred_at: "2026-09-21T18:03:11Z",
          session_ref: "a1b2c3d4e5f60718",
          repo: { remote: "github.com/org/repo", branch: "f-12-login", head_sha: "9f2c" },
          data: { files: [{ path: "apps/web/app/login/page.tsx", tool: "Edit" }], tool_uses: 7, prompt_chars: 342, duration_ms: 81234 },
        },
      ],
    };

    expect(validate(sample)).toBe(true);
  });

  it("ingest-claude-code rechaza un kind desconocido" , () => {
    const schema = getSchema("ingest-claude-code");
    const ajv = new Ajv();
    addFormats(ajv);
    const validate = ajv.compile(schema);

    const sample = {
      cli_version: "0.3.1",
      events: [
        { client_event_id: "x", kind: "cc_prompt", occurred_at: "2026-09-21T18:03:11Z", session_ref: "s", repo: { remote: "r" }, data: {} },
      ],
    };

    expect(validate(sample)).toBe(false);
  });
});
