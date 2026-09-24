import { expect, test } from "@playwright/test";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

// RF-CC-001/002: device flow completo contra la API real, sin mocks. Simula
// el CLI con fetch directo a la API (no tiene UI) y usa la web solo para la
// pantalla de aprobación y el ajuste personal de Claude Code.
test("device flow: aprobar desde la web deja el token listo para el CLI", async ({ page, request }) => {
  const uniqueEmail = `e2e-cc-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Nombre").fill("Grace Hopper");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Contraseña", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Crear cuenta" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Crear equipo").click();
  await page.getByLabel("Nombre del equipo").fill("Equipo Device Flow");
  await page.getByLabel("Nombre del hackathon").fill("HackUSC Device Flow");
  await page.getByLabel("Fecha de fin").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Crear equipo" }).click();
  await page.getByRole("button", { name: "Continuar" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);
  const homeUrl = page.url();

  // 1. El CLI pide un device_code (sin sesión).
  const deviceResponse = await request.post(`${API_URL}/api/v1/cli/device`);
  expect(deviceResponse.ok()).toBeTruthy();
  const { device_code: deviceCode, user_code: userCode } = await deviceResponse.json();

  // 2. La persona lo aprueba desde la web, ya con sesión.
  await page.goto(`/cli/device?user_code=${userCode}`);
  await expect(page.getByText("Conectar Claude Code")).toBeVisible();
  await expect(page.getByLabel("Código")).toHaveValue(userCode);
  await page.getByRole("button", { name: "Aprobar" }).click();
  await expect(page.getByText("Dispositivo aprobado")).toBeVisible();

  // 3. El CLI canjea el device_code por el token de miembro.
  const tokenResponse = await request.post(`${API_URL}/api/v1/cli/device/token`, { data: { device_code: deviceCode } });
  expect(tokenResponse.ok()).toBeTruthy();
  const { token } = await tokenResponse.json();
  expect(token).toMatch(/^hb_mt_/);

  // 4. Un segundo canje del mismo device_code falla (un solo uso).
  const secondTry = await request.post(`${API_URL}/api/v1/cli/device/token`, { data: { device_code: deviceCode } });
  expect(secondTry.status()).toBe(400);

  // 5. La sección personal de ajustes lo refleja.
  await page.goto(homeUrl);
  await page.getByRole("link", { name: "Equipo y ajustes" }).click();
  await expect(page.getByText("Claude Code (personal)")).toBeVisible();
  await expect(page.getByText("Conectado", { exact: true })).toBeVisible();
});
