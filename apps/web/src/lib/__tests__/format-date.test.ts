import { describe, expect, it } from "vitest";
import { formatInTimezone, relativeTime } from "@/lib/format-date";

describe("formatInTimezone", () => {
  it("incluye la abreviatura de la zona horaria del hackathon", () => {
    const result = formatInTimezone("2026-06-01T10:00:00Z", "Europe/Madrid");
    expect(result).toMatch(/\(GMT\+2\)|\(CEST\)/);
  });

  it("devuelve una cadena vacía sin fecha" , () => {
    expect(formatInTimezone(null, "Europe/Madrid")).toBe("");
  });
});

describe("relativeTime", () => {
  it("expresa minutos en el futuro" , () => {
    const soon = new Date(Date.now() + 5 * 60_000).toISOString();
    expect(relativeTime(soon)).toMatch(/dentro de 5 minutos|en 5 minutos/);
  });
});
