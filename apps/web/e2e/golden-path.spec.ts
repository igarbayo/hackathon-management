import { expect, test } from "@playwright/test";

// F1 golden path (10-roadmap.md#fase-1--esqueleto): sign up, create a team,
// objectives and features on the kanban, including dragging between columns
// (RF-FEAT-011), against the real API (no mocks).
test("a new user signs up, creates a team and manages the kanban", async ({ page }) => {
  const uniqueEmail = `e2e-${Date.now()}@example.com`;

  await page.goto("/signup");
  await page.getByLabel("Name").fill("Ada Lovelace");
  await page.getByLabel("Email").fill(uniqueEmail);
  await page.getByLabel("Password", { exact: true }).fill("supersecret123");
  await page.getByRole("button", { name: "Sign up" }).click();

  await expect(page).toHaveURL(/\/onboarding/);
  await page.getByText("Create team").click();

  await page.getByLabel("Team name").fill("The Bytes E2E");
  await page.getByLabel("Hackathon name").fill("HackUSC E2E");
  await page.getByLabel("End date").click();
  await page.locator("#ends-at-search").fill("2026-12-31T23:59");
  await page.locator("#ends-at-search").press("Enter");
  await page.getByRole("button", { name: "Create team" }).click();

  await expect(page.getByText(/^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{4}-/)).toBeVisible();
  await page.getByRole("button", { name: "Continue" }).click();

  await expect(page).toHaveURL(/\/t\/[^/]+\/home/);
  const teamUrl = page.url();
  const teamId = teamUrl.match(/\/t\/([^/]+)\//)?.[1];
  expect(teamId).toBeTruthy();

  // Objectives
  await page.getByRole("link", { name: "Objectives" }).click();
  await page.getByPlaceholder("New objective…").fill("Win the hackathon");
  await page.getByPlaceholder("New objective…").press("Enter");
  await expect(page.getByText("O-1")).toBeVisible();

  // Features: create one in "Idea" and another in "In progress"
  await page.getByRole("link", { name: "Features" }).click();
  await page.getByRole("textbox", { name: "New feature in Idea" }).fill("Login with GitHub");
  await page.getByRole("textbox", { name: "New feature in Idea" }).press("Enter");
  await expect(page.getByText("F-1")).toBeVisible();

  await page.getByRole("textbox", { name: "New feature in In progress" }).fill("Feature kanban");
  await page.getByRole("textbox", { name: "New feature in In progress" }).press("Enter");
  await expect(page.getByText("F-2")).toBeVisible();

  // RF-FEAT-011: drag F-1 from "Idea" to "Done"
  // Selectors by data-testid, not by Tailwind class (RNF-UI-020): the kanban
  // can be restyled without breaking this test.
  const card = page.getByTestId("feature-card").filter({ hasText: "F-1" });
  const doneColumn = page.getByTestId("kanban-column-drop-done");

  const cardBox = await card.boundingBox();
  const targetBox = await doneColumn.boundingBox();
  if (!cardBox || !targetBox) throw new Error("Could not measure the card or the target column");

  await page.mouse.move(cardBox.x + cardBox.width / 2, cardBox.y + cardBox.height / 2);
  await page.mouse.down();
  const steps = 12;
  for (let i = 1; i <= steps; i++) {
    const x = cardBox.x + cardBox.width / 2 + ((targetBox.x + targetBox.width / 2 - cardBox.x) * i) / steps;
    const y = cardBox.y + cardBox.height / 2 + ((targetBox.y + 20 - cardBox.y) * i) / steps;
    await page.mouse.move(x, y);
  }

  // Before the drop, the card's gap is already in "Done" and not in "Idea":
  // otherwise, on drop it was seen going back to its column and then jumping
  // to the target. (The copy that follows the cursor, the DragOverlay, is
  // outside the columns.)
  await expect(page.getByTestId("kanban-column-done").getByText("F-1")).toBeVisible();
  await expect(page.getByTestId("kanban-column-idea").getByText("F-1")).not.toBeVisible();
  await page.mouse.up();

  await expect(page.getByTestId("kanban-column-done").getByText("F-1")).toBeVisible();

  // The position survives a reload: it is not just the optimistic state.
  await page.reload();
  await expect(page.getByTestId("kanban-column-done").getByText("F-1")).toBeVisible();
  await expect(page.getByTestId("kanban-column-idea").getByText("F-1")).not.toBeVisible();

  // Settings: the team code is shown and the user is an owner
  await page.getByRole("link", { name: "Team and settings" }).click();
  await expect(page.getByText("Owner", { exact: true }).or(page.getByText("owner"))).toBeVisible();
});
