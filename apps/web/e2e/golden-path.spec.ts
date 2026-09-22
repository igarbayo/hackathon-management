import { expect, test } from "@playwright/test";

// Flujo dorado F1 (10-roadmap.md#fase-1--esqueleto): registro, crear equipo,
// objetivos y features en el kanban, incluido el arrastre entre columnas
// (RF-FEAT-011), contra la API real (no mocks).
test("un usuario nuevo se registra, crea un equipo y gestiona el kanban", async ({ page }) => {
  const uniqueEmail = `e2e-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Nombre").fill("Ada Lovelace");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Contraseña").fill("supersecret123");
  await page.getByRole("button", { name: "Crear cuenta" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Crear equipo").click();

  await page.getByLabel("Nombre del equipo").fill("Los Bytes E2E");
  await page.getByLabel("Nombre del hackathon").fill("HackUSC E2E");
  await page.locator("#ends-at").fill("2026-12-31T23:59");
  await page.getByRole("button", { name: "Crear equipo" }).click();

  await expect(page.getByText(/^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{4}-/)).toBeVisible();
  await page.getByRole("button", { name: "Continuar" }).click();

  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);
  const teamUrl = page.url();
  const teamId = teamUrl.match(/\/t\/([^/]+)\//)?.[1];
  expect(teamId).toBeTruthy();

  // Objetivos
  await page.getByRole("link", { name: "Objetivos" }).click();
  await page.getByPlaceholder("Nuevo objetivo…").fill("Ganar el hackathon");
  await page.getByPlaceholder("Nuevo objetivo…").press("Enter");
  await expect(page.getByText("O-1")).toBeVisible();

  // Features: crea una en "Idea" y otra en "En curso"
  await page.getByRole("link", { name: "Features" }).click();
  await page.getByRole("textbox", { name: "Nueva feature en Idea" }).fill("Login con GitHub");
  await page.getByRole("textbox", { name: "Nueva feature en Idea" }).press("Enter");
  await expect(page.getByText("F-1")).toBeVisible();

  await page.getByRole("textbox", { name: "Nueva feature en En curso" }).fill("Kanban de features");
  await page.getByRole("textbox", { name: "Nueva feature en En curso" }).press("Enter");
  await expect(page.getByText("F-2")).toBeVisible();

  // RF-FEAT-011: arrastrar F-1 de "Idea" a "Hecha"
  // Selectores por data-testid, no por clase de Tailwind (RNF-UI-020): el
  // kanban se puede restilar sin romper este test.
  const card = page.getByTestId("feature-card").filter({ hasText: "F-1" });
  const hechaColumn = page.getByTestId("kanban-column-drop-done");

  const cardBox = await card.boundingBox();
  const targetBox = await hechaColumn.boundingBox();
  if (!cardBox || !targetBox) throw new Error("No se pudo medir la tarjeta o la columna destino");

  await page.mouse.move(cardBox.x + cardBox.width / 2, cardBox.y + cardBox.height / 2);
  await page.mouse.down();
  const steps = 12;
  for (let i = 1; i <= steps; i++) {
    const x = cardBox.x + cardBox.width / 2 + ((targetBox.x + targetBox.width / 2 - cardBox.x) * i) / steps;
    const y = cardBox.y + cardBox.height / 2 + ((targetBox.y + 20 - cardBox.y) * i) / steps;
    await page.mouse.move(x, y);
  }
  await page.mouse.up();

  await expect(page.getByTestId("kanban-column-done").getByText("F-1")).toBeVisible();

  // La posición persiste tras recargar: no es solo el estado optimista.
  await page.reload();
  await expect(page.getByTestId("kanban-column-done").getByText("F-1")).toBeVisible();
  await expect(page.getByTestId("kanban-column-idea").getByText("F-1")).not.toBeVisible();

  // Ajustes: el código del equipo se ve y el usuario es owner
  await page.getByRole("link", { name: "Equipo y ajustes" }).click();
  await expect(page.getByText("Owner", { exact: true }).or(page.getByText("owner"))).toBeVisible();
});
