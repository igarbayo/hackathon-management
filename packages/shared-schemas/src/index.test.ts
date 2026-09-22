import { describe, expect, it } from "vitest";
import { getSchema, listSchemaNames } from "./index";

describe("shared-schemas loader", () => {
  it("lista los schemas disponibles sin fallar cuando no hay ninguno todavía", () => {
    expect(listSchemaNames()).toEqual(expect.any(Array));
  });

  it("lanza un error legible si se pide un schema que no existe", () => {
    expect(() => getSchema("no-existe")).toThrowError(/No existe el schema/);
  });
});
