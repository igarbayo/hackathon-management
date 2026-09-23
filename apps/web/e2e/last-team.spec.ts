import { expect, test } from "@playwright/test";

// RF-TEAM-013: al volver a entrar, el usuario aterriza en el último equipo
// que visitó en vez de que se le pida crear o unirse a otro (bug reportado
// en producción: `last_team_id` nunca se escribía).
test("tras cerrar sesión y volver a entrar, aterriza en su equipo sin pasar por onboarding", async ({ page }) => {
  const uniqueEmail = `e2e-lt-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Nombre").fill("Katherine Johnson");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Contraseña", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Crear cuenta" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Crear equipo").click();
  await page.getByLabel("Nombre del equipo").fill("Equipo Last Team");
  await page.getByLabel("Nombre del hackathon").fill("HackUSC Last Team");
  await page.getByLabel("Fecha de fin").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Crear equipo" }).click();
  await page.getByRole("button", { name: "Continuar" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);
  const teamUrl = page.url();

  await page.getByLabel("Menú de usuario").click();
  await page.getByText("Cerrar sesión").click();
  await expect(page).toHaveURL(/\/login/);

  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Contraseña", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Entrar" }).click();

  await expect(page).toHaveURL(teamUrl);
});

// Un usuario con más de un equipo, sin equipo previo registrado, elige a
// cuál entrar en vez de solo poder crear o unirse a otro nuevo.
test("con varios equipos y sin last_team_id, onboarding deja elegir a cuál entrar", async ({ page }) => {
  const uniqueEmail = `e2e-lt2-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Nombre").fill("Margaret Hamilton");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Contraseña", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Crear cuenta" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Crear equipo").click();
  await page.getByLabel("Nombre del equipo").fill("Primer equipo");
  await page.getByLabel("Nombre del hackathon").fill("HackUSC Uno");
  await page.getByLabel("Fecha de fin").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Crear equipo" }).click();
  await page.getByRole("button", { name: "Continuar" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);

  // Crea un segundo equipo desde el propio onboarding (vuelve a pasar por
  // ahí a propósito, como haría alguien que quiere montar otro más).
  await page.goto("/onboarding");
  await page.getByText("Crear equipo").click();
  await page.getByLabel("Nombre del equipo").fill("Segundo equipo");
  await page.getByLabel("Nombre del hackathon").fill("HackUSC Dos");
  await page.getByLabel("Fecha de fin").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Crear equipo" }).click();
  await page.getByRole("button", { name: "Continuar" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);

  await page.goto("/onboarding");
  await expect(page.getByText("Elige un equipo")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Primer equipo" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Segundo equipo" })).toBeVisible();

  await page.getByRole("heading", { name: "Primer equipo" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);
});
