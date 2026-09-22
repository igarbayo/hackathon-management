import { expect, test } from "@playwright/test";
import crypto from "node:crypto";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

function pkcePair() {
  const verifier = crypto.randomBytes(32).toString("base64url");
  const challenge = crypto.createHash("sha256").update(verifier).digest("base64url");
  return { verifier, challenge };
}

// RF-API-012/RF-MCP-020: flujo de consentimiento OAuth 2.1 real en el
// navegador, contra la API real. Simula un cliente MCP externo (registro
// dinámico + PKCE) y usa la web solo para el login y la pantalla de
// consentimiento.
test("consentimiento OAuth: aprobar desde la web deja un token listo para el cliente", async ({ page, request }) => {
  const uniqueEmail = `e2e-oauth-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Nombre").fill("Grace Hopper");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Contraseña").fill("supersecret123");
  await page.getByRole("button", { name: "Crear cuenta" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Crear equipo").click();
  await page.getByLabel("Nombre del equipo").fill("Equipo OAuth E2E");
  await page.getByLabel("Nombre del hackathon").fill("HackUSC OAuth E2E");
  await page.getByLabel("Fecha de fin").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Crear equipo" }).click();
  await page.getByRole("button", { name: "Continuar" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);

  // 1. Un cliente externo (p. ej. claude.ai) se registra dinámicamente.
  const registerResponse = await request.post(`${API_URL}/oauth/register`, {
    data: { redirect_uris: ["https://example-mcp-client.test/callback"], client_name: "Cliente E2E" },
  });
  expect(registerResponse.ok()).toBeTruthy();
  const { client_id: clientId } = await registerResponse.json();

  // 2. Pide autorización con PKCE.
  const { verifier, challenge } = pkcePair();
  const authorizeUrl =
    `${API_URL}/oauth/authorize?response_type=code&client_id=${clientId}` +
    `&redirect_uri=${encodeURIComponent("https://example-mcp-client.test/callback")}` +
    `&scope=${encodeURIComponent("read features:write")}&state=teststate123` +
    `&code_challenge=${challenge}&code_challenge_method=S256` +
    `&resource=${encodeURIComponent(`${API_URL}/api/v1/mcp`)}`;

  await page.goto(authorizeUrl);
  await expect(page).toHaveURL(/\/oauth\/consent\?request_id=/);
  await expect(page.getByText("Cliente E2E quiere acceder a Hackboard")).toBeVisible();
  await expect(page.getByText(/Ver el equipo/)).toBeVisible();
  await expect(page.getByText(/Crear y editar features/)).toBeVisible();

  // 3. Aprobar navega de verdad al redirect_uri del cliente (lo bloqueamos
  // para no salir de las páginas de la app, y comprobamos la URL final).
  await page.route("https://example-mcp-client.test/**", async (route) => {
    await route.fulfill({ status: 200, body: "ok" });
  });
  await page.getByRole("button", { name: "Aprobar" }).click();
  await page.waitForURL(/example-mcp-client\.test\/callback/);

  const finalUrl = new URL(page.url());
  expect(finalUrl.searchParams.get("state")).toBe("teststate123");
  const code = finalUrl.searchParams.get("code");
  expect(code).toBeTruthy();

  // 4. El cliente canjea el código con PKCE.
  const tokenResponse = await request.post(`${API_URL}/oauth/token`, {
    data: {
      grant_type: "authorization_code", code, redirect_uri: "https://example-mcp-client.test/callback",
      client_id: clientId, code_verifier: verifier,
    },
  });
  expect(tokenResponse.ok()).toBeTruthy();
  const tokenBody = await tokenResponse.json();
  expect(tokenBody.access_token).toMatch(/^hb_oat_/);
  expect(tokenBody.refresh_token).toMatch(/^hb_ort_/);

  // 5. El token sirve de verdad contra el servidor MCP.
  const mcpResponse = await request.post(`${API_URL}/api/v1/mcp`, {
    headers: { Authorization: `Bearer ${tokenBody.access_token}` },
    data: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "whoami", arguments: {} } },
  });
  const mcpBody = await mcpResponse.json();
  const whoami = JSON.parse(mcpBody.result.content[0].text);
  expect(whoami.kind).toBe("oauth");
});
