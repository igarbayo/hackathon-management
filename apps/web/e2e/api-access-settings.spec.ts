import { expect, test } from "@playwright/test";

// RF-API-001/RF-API-011/RF-API-009: create a PAT, an integration and a
// webhook from Settings, against the real API, and check that the plain
// text value (and the claude mcp add command) is shown only once.
test("Settings: creating a PAT shows the token and the claude mcp add command only once", async ({ page }) => {
  const uniqueEmail = `e2e-api-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Name").fill("Ada Lovelace");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Password", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Sign up" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Create team").click();
  await page.getByLabel("Team name").fill("API E2E Team");
  await page.getByLabel("Hackathon name").fill("HackUSC API E2E");
  await page.getByLabel("End date").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Create team" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);

  await page.getByRole("link", { name: "Team and settings" }).click();

  // PAT
  await page.getByPlaceholder("Name (e.g. Claude Code laptop)").fill("My CLI");
  await page.getByRole("button", { name: "Create token" }).click();

  await expect(page.getByText("Token: copy it now")).toBeVisible();
  const tokenCode = page.locator("code").filter({ hasText: /^hb_pat_/ });
  await expect(tokenCode).toBeVisible();
  const mcpCommand = page.locator("code").filter({ hasText: "claude mcp add" });
  await expect(mcpCommand).toContainText("--transport http");
  const tokenText = await tokenCode.textContent();
  expect(tokenText).toBeTruthy();
  await expect(mcpCommand).toContainText(tokenText as string);

  await page.getByRole("button", { name: "I have saved it" }).click();
  await expect(page.getByText("Token: copy it now")).not.toBeVisible();
  await expect(page.getByText("My CLI")).toBeVisible();

  // Integration (the user is an owner because they created the team)
  await page.getByPlaceholder("Name (e.g. Slack bot)").fill("Slack bot");
  await page.getByRole("button", { name: "Create integration" }).click();
  await expect(page.getByText("Integration token: copy it now")).toBeVisible();
  await expect(page.locator("code").filter({ hasText: /^hb_it_/ })).toBeVisible();
  await page.getByRole("button", { name: "I have saved it" }).click();
  await expect(page.getByText("Slack bot")).toBeVisible();

  // Webhook
  await page.getByPlaceholder("https://…").fill("https://example.com/hook");
  await page.getByText("feature.created", { exact: true }).click();
  await page.getByRole("button", { name: "Create webhook" }).click();
  await expect(page.getByText("Signing secret: copy it now")).toBeVisible();
  await page.getByRole("button", { name: "I have saved it" }).click();
  await expect(page.getByText("https://example.com/hook")).toBeVisible();
});
