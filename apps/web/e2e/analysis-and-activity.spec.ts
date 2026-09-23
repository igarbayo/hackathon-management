import { expect, test } from "@playwright/test";

// Verificación real en navegador de las pantallas de Actividad y Análisis IA
// (spec 05/06), ya que dependen de use(params) + Suspense y no se prestan
// bien a un test de componente aislado con Testing Library.
test("las pantallas de Actividad y Análisis IA cargan sin errores para un equipo nuevo", async ({ page }) => {
  const uniqueEmail = `e2e-analysis-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Nombre").fill("Grace Hopper");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Contraseña", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Crear cuenta" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Crear equipo").click();
  await page.getByLabel("Nombre del equipo").fill("Equipo Análisis");
  await page.getByLabel("Nombre del hackathon").fill("Hack Análisis");
  await page.getByLabel("Fecha de fin").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Crear equipo" }).click();
  await page.getByRole("button", { name: "Continuar" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);

  const consoleErrors: string[] = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });

  await page.getByRole("link", { name: "Actividad" }).click();
  await expect(page.getByText("Todavía no hay actividad que mostrar")).toBeVisible();

  await page.getByRole("link", { name: "Análisis IA" }).click();
  await expect(page.getByText("Todavía no hay ningún análisis")).toBeVisible();
  await expect(page.getByRole("button", { name: "Analizar ahora" })).toBeVisible();

  await page.getByRole("link", { name: "Equipo y ajustes" }).click();
  await expect(page.getByText("Todavía no hay repos vinculados.")).toBeVisible();

  expect(consoleErrors).toEqual([]);
});
