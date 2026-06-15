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
