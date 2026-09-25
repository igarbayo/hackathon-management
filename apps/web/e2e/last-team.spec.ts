import { expect, test } from "@playwright/test";

// RF-TEAM-013: when logging back in, the user lands on the last team they
// visited instead of being asked to create or join another one (bug reported
// in production: `last_team_id` was never written).
test("after logging out and back in, the user lands on their team without going through onboarding", async ({ page }) => {
  const uniqueEmail = `e2e-lt-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Name").fill("Katherine Johnson");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Password", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Sign up" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Create team").click();
  await page.getByLabel("Team name").fill("Last Team Team");
  await page.getByLabel("Hackathon name").fill("HackUSC Last Team");
  await page.getByLabel("End date").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Create team" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);
  const teamUrl = page.url();

  await page.getByLabel("User menu").click();
  await page.getByText("Log out").click();
  await expect(page).toHaveURL(/\/login/);

  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Password", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Log in" }).click();

  await expect(page).toHaveURL(teamUrl);
});

// A user with more than one team, and no previous team recorded, chooses
// which one to enter instead of only being able to create or join a new one.
test("with several teams and no last_team_id, onboarding lets the user choose which one to enter", async ({ page }) => {
  const uniqueEmail = `e2e-lt2-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Name").fill("Margaret Hamilton");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Password", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Sign up" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Create team").click();
  await page.getByLabel("Team name").fill("First team");
  await page.getByLabel("Hackathon name").fill("HackUSC One");
  await page.getByLabel("End date").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Create team" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);

  // Creates a second team from onboarding itself (going back there on
  // purpose, as someone who wants to set up another one would).
  await page.goto("/onboarding");
  await page.getByText("Create team").click();
  await page.getByLabel("Team name").fill("Second team");
  await page.getByLabel("Hackathon name").fill("HackUSC Two");
  await page.getByLabel("End date").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Create team" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);

  await page.goto("/onboarding");
  await expect(page.getByText("Choose a team")).toBeVisible();
  await expect(page.getByRole("heading", { name: "First team" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Second team" })).toBeVisible();

  await page.getByRole("heading", { name: "First team" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);
});
