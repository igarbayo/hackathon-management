import { beforeEach, describe, expect, it, vi } from "vitest";
import { apiClient, ApiError } from "@/lib/api-client";

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

describe("apiClient", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("no pide csrf token para peticiones GET", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ ok: true }));

    await apiClient.get("/api/v1/me");

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [, init] = fetchMock.mock.calls[0];
    expect((init?.headers as Record<string, string>)["X-CSRF-Token"]).toBeUndefined();
  });

  it("obtiene el csrf token una vez y lo reutiliza en peticiones que mutan", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(jsonResponse({ csrf_token: "token-abc" }))
      .mockImplementation(async () => jsonResponse({ ok: true }, 201));

    await apiClient.post("/api/v1/teams", { name: "X" });
    await apiClient.post("/api/v1/teams", { name: "Y" });

    expect(fetchMock).toHaveBeenCalledTimes(3); // 1 csrf + 2 posts
    const secondCallHeaders = fetchMock.mock.calls[1][1]?.headers as Record<string, string>;
    const thirdCallHeaders = fetchMock.mock.calls[2][1]?.headers as Record<string, string>;
    expect(secondCallHeaders["X-CSRF-Token"]).toBe("token-abc");
    expect(thirdCallHeaders["X-CSRF-Token"]).toBe("token-abc");
  });

  it("lanza ApiError con el código y el mensaje del backend", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse({ error: { code: "validation_failed", message: "Título obligatorio" } }, 422),
    );

    await expect(apiClient.get("/api/v1/teams/x")).rejects.toMatchObject(
      new ApiError(422, "Título obligatorio", "validation_failed"),
    );
  });

  it("devuelve undefined en respuestas 204" , async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status: 204 }));

    await expect(apiClient.delete("/api/v1/teams/x/members/1")).resolves.toBeUndefined();
  });
});
