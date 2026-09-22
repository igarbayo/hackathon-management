import { expect, test } from "@playwright/test";

// RF-API-001/RF-API-011/RF-API-009: crear un PAT, una integración y un
// webhook desde Ajustes, contra la API real, y comprobar que el valor en
// claro (y el comando de claude mcp add) se muestra una sola vez.
test("Ajustes: crear un PAT muestra el token y el comando de claude mcp add una sola vez", async ({ page }) => {
  const uniqueEmail = `e2e-api-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Nombre").fill("Ada Lovelace");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Contraseña").fill("supersecret123");
  await page.getByRole("button", { name: "Crear cuenta" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Crear equipo").click();
  await page.getByLabel("Nombre del equipo").fill("Equipo API E2E");
  await page.getByLabel("Nombre del hackathon").fill("HackUSC API E2E");
  await page.getByLabel("Fecha de fin").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Crear equipo" }).click();
  await page.getByRole("button", { name: "Continuar" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);

  await page.getByRole("link", { name: "Equipo y ajustes" }).click();

  // PAT
  await page.getByPlaceholder("Nombre (p. ej. Claude Code portátil)").fill("Mi CLI");
  await page.getByRole("button", { name: "Crear token" }).click();

  await expect(page.getByText("Token: apúntalo ahora")).toBeVisible();
  const tokenCode = page.locator("code").filter({ hasText: /^hb_pat_/ });
  await expect(tokenCode).toBeVisible();
  const mcpCommand = page.locator("code").filter({ hasText: "claude mcp add" });
  await expect(mcpCommand).toContainText("--transport http");
  const tokenText = await tokenCode.textContent();
  expect(tokenText).toBeTruthy();
  await expect(mcpCommand).toContainText(tokenText as string);

  await page.getByRole("button", { name: "Ya lo he guardado" }).click();
  await expect(page.getByText("Token: apúntalo ahora")).not.toBeVisible();
  await expect(page.getByText("Mi CLI")).toBeVisible();

  // Integración (el usuario es owner por haber creado el equipo)
  await page.getByPlaceholder("Nombre (p. ej. Bot de Slack)").fill("Bot de Slack");
  await page.getByRole("button", { name: "Crear integración" }).click();
  await expect(page.getByText("Token de integración: apúntalo ahora")).toBeVisible();
  await expect(page.locator("code").filter({ hasText: /^hb_it_/ })).toBeVisible();
  await page.getByRole("button", { name: "Ya lo he guardado" }).click();
  await expect(page.getByText("Bot de Slack")).toBeVisible();

  // Webhook
  await page.getByPlaceholder("https://…").fill("https://example.com/hook");
  await page.getByText("feature.created", { exact: true }).click();
  await page.getByRole("button", { name: "Crear webhook" }).click();
  await expect(page.getByText("Secreto de firma: apúntalo ahora")).toBeVisible();
  await page.getByRole("button", { name: "Ya lo he guardado" }).click();
  await expect(page.getByText("https://example.com/hook")).toBeVisible();
});
