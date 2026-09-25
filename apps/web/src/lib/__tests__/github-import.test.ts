import { describe, expect, it } from "vitest";
import { importSummary, isImporting } from "@/lib/github-import";

describe("importSummary (RF-GH-025)", () => {
  it("says nothing if it was never imported", () => {
    expect(importSummary(null)).toBeNull();
  });

  it("warns while importing", () => {
    expect(isImporting({ status: "queued" })).toBe(true);
    expect(importSummary({ status: "running" })).toBe("Importing history…");
  });

  it("counts commits and PRs with the start date", () => {
    const summary = importSummary({ status: "done", commits: 87, pull_requests: 1, since: "2026-04-25T09:00:00Z" });
    expect(summary).toMatch(/^87 commits since Apr 25, 2026 and 1 open PR\.$/);
  });

  it("says how many branches they come from (RF-GH-026)", () => {
    const summary = importSummary({ status: "done", commits: 12, branches: 3, pull_requests: 2, since: "2026-04-25T09:00:00Z" });
    expect(summary).toMatch(/^12 commits from 3 branches since Apr 25, 2026 and 2 open PRs\.$/);
  });

  it("explains that without a start date there are no commits", () => {
    expect(importSummary({ status: "done", commits: 0, pull_requests: 0, reason: "no_starts_at" })).toBe(
      "The hackathon has no start date, so no commits were imported. 0 open PRs.",
    );
  });

  it("warns if it failed", () => {
    expect(importSummary({ status: "failed" })).toMatch(/Could not import/);
  });

  it("says a stuck import did not finish and suggests resyncing", () => {
    expect(isImporting({ status: "failed", reason: "stalled" })).toBe(false);
    expect(importSummary({ status: "failed", reason: "stalled" })).toMatch(/got stuck.*Try resyncing\.$/);
  });
});
