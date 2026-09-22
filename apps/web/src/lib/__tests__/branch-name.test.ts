import { describe, expect, it } from "vitest";
import { suggestedBranchName } from "@/lib/branch-name";

describe("suggestedBranchName", () => {
  it("pasa el título a kebab-case en minúsculas" , () => {
    expect(suggestedBranchName("F-12", "Login con GitHub")).toBe("f-12-login-con-github");
  });

  it("quita acentos y símbolos" , () => {
    expect(suggestedBranchName("F-3", "Análisis básico: ¿por qué?")).toBe("f-3-analisis-basico-por-que");
  });
});
