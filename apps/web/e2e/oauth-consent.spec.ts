import { expect, test } from "@playwright/test";
import crypto from "node:crypto";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

function pkcePair() {
  const verifier = crypto.randomBytes(32).toString("base64url");
  const challenge = crypto.createHash("sha256").update(verifier).digest("base64url");
  return { verifier, challenge };
}

// RF-API-012/RF-MCP-020: real OAuth 2.1 consent flow in the browser,
// against the real API. It fakes an external MCP client (dynamic
// registration + PKCE) and uses the web app only for login and the consent
// screen.
test("OAuth consent: approving from the web app leaves a token ready for the client", async ({ page, request }) => {
  const uniqueEmail = `e2e-oauth-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Name").fill("Grace Hopper");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Password", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Sign up" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  // RF-TEAM-014: profile first, with the sign-up name already filled in.
  await page.getByRole("button", { name: "Continue" }).click();
  await page.getByText("Create team").click();
  await page.getByLabel("Team name").fill("OAuth E2E Team");
  await page.getByLabel("Hackathon name").fill("HackUSC OAuth E2E");
  await page.getByLabel("End date").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Create team" }).click();
  await page.getByRole("button", { name: "Skip for now" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);

  // 1. An external client (e.g. claude.ai) registers dynamically.
  const registerResponse = await request.post(`${API_URL}/oauth/register`, {
    data: { redirect_uris: ["https://example-mcp-client.test/callback"], client_name: "E2E Client" },
  });
  expect(registerResponse.ok()).toBeTruthy();
  const { client_id: clientId } = await registerResponse.json();

  // 2. It asks for authorization with PKCE.
  const { verifier, challenge } = pkcePair();
  const authorizeUrl =
    `${API_URL}/oauth/authorize?response_type=code&client_id=${clientId}` +
    `&redirect_uri=${encodeURIComponent("https://example-mcp-client.test/callback")}` +
    `&scope=${encodeURIComponent("read features:write")}&state=teststate123` +
    `&code_challenge=${challenge}&code_challenge_method=S256` +
    `&resource=${encodeURIComponent(`${API_URL}/api/v1/mcp`)}`;

  await page.goto(authorizeUrl);
  await expect(page).toHaveURL(/\/oauth\/consent\?request_id=/);
  await expect(page.getByText("E2E Client wants to access Hackboard")).toBeVisible();
  await expect(page.getByText(/View the team/)).toBeVisible();
  await expect(page.getByText(/Create and edit features/)).toBeVisible();

  // 3. Approving really navigates to the client's redirect_uri (we block it
  // so we do not leave the app's pages, and check the final URL).
  await page.route("https://example-mcp-client.test/**", async (route) => {
    await route.fulfill({ status: 200, body: "ok" });
  });
  await page.getByRole("button", { name: "Approve" }).click();
  await page.waitForURL(/example-mcp-client\.test\/callback/);

  const finalUrl = new URL(page.url());
  expect(finalUrl.searchParams.get("state")).toBe("teststate123");
  const code = finalUrl.searchParams.get("code");
  expect(code).toBeTruthy();

  // 4. The client exchanges the code with PKCE.
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

  // 5. The token really works against the MCP server.
  const mcpResponse = await request.post(`${API_URL}/api/v1/mcp`, {
    headers: { Authorization: `Bearer ${tokenBody.access_token}` },
    data: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "whoami", arguments: {} } },
  });
  const mcpBody = await mcpResponse.json();
  const whoami = JSON.parse(mcpBody.result.content[0].text);
  expect(whoami.kind).toBe("oauth");
});
