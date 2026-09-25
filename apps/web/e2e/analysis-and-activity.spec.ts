import { expect, test } from "@playwright/test";

// Real browser check of the Activity and AI analysis screens (spec 05/06),
// since they depend on use(params) + Suspense and do not suit an isolated
// component test with Testing Library.
test("the Activity and AI analysis screens load with no errors for a new team", async ({ page }) => {
  const uniqueEmail = `e2e-analysis-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Name").fill("Grace Hopper");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Password", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Sign up" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  // RF-TEAM-014: profile first, with the sign-up name already filled in.
  await page.getByRole("button", { name: "Continue" }).click();
  await page.getByText("Create team").click();
  await page.getByLabel("Team name").fill("Analysis Team");
  await page.getByLabel("Hackathon name").fill("Analysis Hack");
  await page.getByLabel("End date").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Create team" }).click();
  await page.getByRole("button", { name: "Skip for now" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);

  const consoleErrors: string[] = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });

  await page.getByRole("link", { name: "Activity" }).click();
  await expect(page.getByText("No activity to show yet")).toBeVisible();

  await page.getByRole("link", { name: "AI analysis" }).click();
  await expect(page.getByText("No analyses yet")).toBeVisible();
  await expect(page.getByRole("button", { name: "Analyze now" })).toBeVisible();

  await page.getByRole("link", { name: "Team and settings" }).click();
  await expect(page.getByText("No linked repos yet.")).toBeVisible();

  expect(consoleErrors).toEqual([]);
});
