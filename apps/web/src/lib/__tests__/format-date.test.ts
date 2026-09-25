import { describe, expect, it } from "vitest";
import { formatInTimezone, relativeTime } from "@/lib/format-date";

describe("formatInTimezone", () => {
  it("includes the abbreviation of the hackathon time zone", () => {
    const result = formatInTimezone("2026-06-01T10:00:00Z", "Europe/Madrid");
    expect(result).toMatch(/\(GMT\+2\)|\(CEST\)/);
  });

  it("returns an empty string with no date", () => {
    expect(formatInTimezone(null, "Europe/Madrid")).toBe("");
  });
});

describe("relativeTime", () => {
  it("expresses minutes in the future", () => {
    const soon = new Date(Date.now() + 5 * 60_000).toISOString();
    expect(relativeTime(soon)).toBe("in 5 minutes");
  });
});
