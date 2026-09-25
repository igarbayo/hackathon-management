import { expect, test } from "@playwright/test";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

// RF-CC-001/002: full device flow against the real API, no mocks. It fakes
// the CLI with direct fetches to the API (it has no UI) and uses the web app
// only for the approval screen and the personal Claude Code setting.
test("device flow: approving from the web app leaves the token ready for the CLI", async ({ page, request }) => {
  const uniqueEmail = `e2e-cc-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Name").fill("Grace Hopper");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Password", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Sign up" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  // RF-TEAM-014: profile first, with the sign-up name already filled in.
  await page.getByRole("button", { name: "Continue" }).click();
  await page.getByText("Create team").click();
  await page.getByLabel("Team name").fill("Device Flow Team");
  await page.getByLabel("Hackathon name").fill("HackUSC Device Flow");
  await page.getByLabel("End date").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Create team" }).click();
  await page.getByRole("button", { name: "Skip for now" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);
  const homeUrl = page.url();

  // 1. The CLI asks for a device_code (with no session).
  const deviceResponse = await request.post(`${API_URL}/api/v1/cli/device`);
  expect(deviceResponse.ok()).toBeTruthy();
  const { device_code: deviceCode, user_code: userCode } = await deviceResponse.json();

  // 2. The person approves it from the web app, already logged in.
  await page.goto(`/cli/device?user_code=${userCode}`);
  await expect(page.getByText("Connect Claude Code")).toBeVisible();
  await expect(page.getByLabel("Code")).toHaveValue(userCode);
  await page.getByRole("button", { name: "Approve" }).click();
  await expect(page.getByText("Device approved")).toBeVisible();

  // 3. The CLI exchanges the device_code for the member token.
  const tokenResponse = await request.post(`${API_URL}/api/v1/cli/device/token`, { data: { device_code: deviceCode } });
  expect(tokenResponse.ok()).toBeTruthy();
  const { token } = await tokenResponse.json();
  expect(token).toMatch(/^hb_mt_/);

  // 4. A second exchange of the same device_code fails (single use).
  const secondTry = await request.post(`${API_URL}/api/v1/cli/device/token`, { data: { device_code: deviceCode } });
  expect(secondTry.status()).toBe(400);

  // 5. The personal settings section shows it.
  await page.goto(homeUrl);
  await page.getByRole("link", { name: "Team and settings" }).click();
  await expect(page.getByText("Claude Code (personal)")).toBeVisible();
  await expect(page.getByText("Connected", { exact: true })).toBeVisible();
});
