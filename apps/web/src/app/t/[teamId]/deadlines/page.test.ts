import { describe, expect, it } from "vitest";
import { groupTimeline } from "./page";
import type { TimelineItem } from "@/types/api";

function item(overdue: boolean, dueAt: string): TimelineItem {
  return { type: "milestone", id: dueAt, title: "x", kind: "demo", due_at: dueAt, overdue };
}

describe("groupTimeline", () => {
  const now = new Date("2026-01-01T12:00:00Z");

  it("agrupa vencidas, próximas 6h y más adelante" , () => {
    const items = [
      item(true, "2026-01-01T10:00:00Z"),
      item(false, "2026-01-01T15:00:00Z"),
      item(false, "2026-01-03T00:00:00Z"),
    ];

    const { overdue, soon, later } = groupTimeline(items, now);

    expect(overdue).toHaveLength(1);
    expect(soon).toHaveLength(1);
    expect(later).toHaveLength(1);
  });
});
