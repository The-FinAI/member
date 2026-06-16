import { test } from '@playwright/test';
import { asRole, openSkillsTab, expect } from './helpers';

// =====================================================================
// Journey J1 (permission matrix) — who may edit a member card.
// Distilled from #44 / #41. Model: an officer of the member's chapter (or an
// admin) edits directly; everyone else is read-only; the member self-edits via
// review. m-li (Li Hua) lives in the Beijing chapter (U_CHAP).
// =====================================================================

test('J1.5a a chapter officer of her chapter CAN edit (direct) — #44', async ({ page }) => {
  await asRole(page, 'uid-chap'); // Chan Min — officer of Beijing
  await page.goto('/members/m-li');
  await openSkillsTab(page);
  await expect(page.locator('.sc-hours'), 'officer gets the editable field').toBeVisible();
  await expect(page.locator('.sc-head')).toContainText(/editable/i);
});

test('J1.5b a non-officer of her chapter CANNOT edit (read-only)', async ({ page }) => {
  await asRole(page, 'uid-wg'); // Wu Jing — a working-group officer, not Beijing's chapter officer
  await page.goto('/members/m-li');
  await openSkillsTab(page);
  // read-only: the editable hours input is absent; the read value is shown instead
  await expect(page.locator('.sc-hours')).toHaveCount(0);
  await expect(page.locator('.sc-capval')).toBeVisible();
});

test('J1.5c an admin CAN edit anyone — #44', async ({ page }) => {
  await asRole(page, 'uid-admin'); // Sai Tan — President
  await page.goto('/members/m-li');
  await openSkillsTab(page);
  await expect(page.locator('.sc-hours')).toBeVisible();
});

// A black-box President explorer found the Permissions tab rendered NO capability
// chips ("toggle a chip to grant" with nothing to toggle) — the mock seeded no
// `capability` catalogue and the position_capability field was misnamed, so the
// approver couldn't see or reason about what any role is allowed to do.
test('PERM1: the Permissions panel renders capability chips, with the President\'s grants on', async ({ page }) => {
  await asRole(page, 'uid-admin');
  await page.goto('/admin/access');
  // wait for the console to hydrate before reaching for a tab
  await expect(page.locator('.tab', { hasText: 'Permissions' })).toBeVisible();
  await page.locator('.tab', { hasText: 'Permissions' }).click();
  // chips exist (the catalogue) and several are shown as granted to the President
  await expect(page.locator('.cap').first()).toBeVisible();
  expect(await page.locator('.cap').count(), 'capability chips render').toBeGreaterThan(3);
  expect(await page.locator('.cap.on').count(), 'the President\'s granted capabilities show as on').toBeGreaterThan(3);
});
