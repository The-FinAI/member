import { test } from '@playwright/test';
import { asRole, trackErrors, openSkillsTab, expect } from './helpers';

// =====================================================================
// Journey J1 — Chapter Officer maintains the roster.
// "I change a member's available time / skill, and trust it persists and shows
//  the same everywhere." (Distilled from #10/#14/#26/#43/#44/#41/#40A.)
// Real role · real surface (incl. clicking into the Skills tab, like a user) ·
// interact → control appears → click → RELOAD → persisted → console clean.
// =====================================================================

test('J1.1 officer edits a member\'s available time → Save appears → persists on reload', async ({ page }) => {
  const errs = trackErrors(page);
  await asRole(page, 'uid-chap');
  await page.goto('/members/m-li');
  await openSkillsTab(page);

  const hours = page.locator('.sc-hours');
  await expect(hours).toBeVisible();
  await hours.fill('21');

  // THE regression guard: with the old type=number binding the dirty-check threw
  // and this Save button never rendered. If it isn't here, #43 is back.
  const save = page.locator('.sc-save');
  await expect(save, 'Save must appear after typing a new value (#43)').toBeVisible();
  await save.click();
  await expect(page.locator('.toast')).toContainText('Saved');

  // reload → the value must still be there (her actual complaint: "lost on exit")
  await page.goto('/members/m-li');
  await openSkillsTab(page);
  await expect(page.locator('.sc-hours')).toHaveValue('21');

  expect(errs(), 'console must be clean').toEqual([]);
});

test('J1.2 the edited available time shows the same on the People roster (single source)', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/members/m-li');
  await openSkillsTab(page);
  await page.locator('.sc-hours').fill('21');
  await page.locator('.sc-save').click();
  await expect(page.locator('.toast')).toContainText('Saved');

  await page.goto('/people');
  // Li Hua's card should show the new total (x/21 h/mo) — cross-page consistency
  await expect(page.getByText(/\b\d+\s*\/\s*21\b/).first()).toBeVisible();
});

test('J1.3 officer changes a skill level (one-tap) → persists on reload', async ({ page }) => {
  const errs = trackErrors(page);
  await asRole(page, 'uid-chap');
  await page.goto('/members/m-li');
  await openSkillsTab(page);

  const firstRow = page.locator('.sc-list li').first();
  await expect(firstRow.locator('.sc-seg .seg').first()).toBeVisible();
  await firstRow.locator('.sc-seg .seg', { hasText: 'Lead' }).click();
  await expect(firstRow.locator('.sc-seg .seg.on')).toHaveText('Lead');

  await page.goto('/members/m-li');
  await openSkillsTab(page);
  await expect(page.locator('.sc-list li').first().locator('.sc-seg .seg.on')).toHaveText('Lead');
  expect(errs(), 'console must be clean').toEqual([]);
});

// =====================================================================
// Journey J3 — a member edits their OWN card → it goes to review.
// (Distilled from #40B.) Officer edits apply directly; member edits queue.
// =====================================================================

test('J3.1 a member editing their own hours is told it went to review (not applied directly)', async ({ page }) => {
  await asRole(page, 'uid-member'); // Li Hua editing her own card
  await page.goto('/members/m-li');
  await openSkillsTab(page);
  await expect(page.locator('.sc-head')).toContainText(/review/i); // "changes go to review" cue
  await page.locator('.sc-hours').fill('15');
  await page.locator('.sc-save').click();
  await expect(page.locator('.toast')).toContainText(/review/i); // "Submitted for review"
});
