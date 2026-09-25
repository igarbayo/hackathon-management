import Ajv from "ajv";
import addFormats from "ajv-formats";
import { describe, expect, it } from "vitest";
import { getSchema, listSchemaNames } from "./index";

describe("shared-schemas loader", () => {
  it("lists the available schemas", () => {
    expect(listSchemaNames()).toContain("coverage-analysis");
  });

  it("throws a readable error if a schema that does not exist is requested", () => {
    expect(() => getSchema("does-not-exist")).toThrowError(/There is no schema/);
  });

  it("coverage-analysis is a valid JSON Schema that compiles with ajv", () => {
    const schema = getSchema("coverage-analysis");
    const ajv = new Ajv();

    expect(() => ajv.compile(schema)).not.toThrow();
  });

  it("coverage-analysis validates a sample output that follows the schema in 06-analisis-ia.md", () => {
    const schema = getSchema("coverage-analysis");
    const ajv = new Ajv();
    const validate = ajv.compile(schema);

    const sample = {
      summary: "You are on time, O-2 is still not covered.",
      coverage: [
        { objective_key: "O-1", status: "covered", feature_keys: ["F-3"], rationale: "F-3 is done" },
        { objective_key: "O-2", status: "uncovered", feature_keys: [], rationale: "no evaluado" },
      ],
      orphan_features: [
        { feature_key: "F-9", rationale: "no vinculada", recommendation: "link_objective", suggested_objective_key: "O-1" },
      ],
      gaps: [{ objective_key: "O-2", description: "login is missing", suggested_feature_title: "Login with GitHub" }],
      risks: [{ severity: "high", kind: "deadline", description: "F-3 vence en 1h", related_keys: ["F-3"] }],
    };

    expect(validate(sample)).toBe(true);
  });

  it("ingest-claude-code validates a sample batch that follows 08-integracion-claude-code.md", () => {
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

  it("ingest-claude-code rejects an unknown kind", () => {
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
