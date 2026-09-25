import { describe, expect, it } from "vitest";
import { progressByStatus } from "./page";
import type { Feature } from "@/types/api";

function feature(status: Feature["status"]): Feature {
  return {
    id: status + Math.random(),
    key: "F-1",
    number: 1,
    title: "x",
    description: null,
    status,
    position: 0,
    objective_ids: [],
    assignee_ids: [],
    deadline: null,
    branch_names: [],
    score: 0,
    last_activity_at: null,
    status_changed_at: null,
    updated_at: "",
    created_at: "",
  };
}

describe("progressByStatus", () => {
  it("does not count discarded in the total", () => {
    const result = progressByStatus([feature("done"), feature("discarded")]);
    expect(result.total).toBe(1);
    expect(result.donePercent).toBe(100);
  });

  it("returns 0% with no countable features", () => {
    const result = progressByStatus([feature("discarded")]);
    expect(result.donePercent).toBe(0);
    expect(result.total).toBe(0);
  });

  it("works out the rounded percentage", () => {
    const result = progressByStatus([feature("done"), feature("in_progress"), feature("idea")]);
    expect(result.donePercent).toBe(33);
  });
});
