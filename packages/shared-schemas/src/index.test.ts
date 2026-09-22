import Ajv from "ajv";
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
});
