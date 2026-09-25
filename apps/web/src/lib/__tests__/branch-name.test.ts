import { describe, expect, it } from "vitest";
import { suggestedBranchName } from "@/lib/branch-name";

describe("suggestedBranchName", () => {
  it("turns the title into lowercase kebab-case", () => {
    expect(suggestedBranchName("F-12", "Login with GitHub")).toBe("f-12-login-with-github");
  });

  it("removes accents and symbols", () => {
    expect(suggestedBranchName("F-3", "Café résumé: why?")).toBe("f-3-cafe-resume-why");
  });
});
