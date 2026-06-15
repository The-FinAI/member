import { test } from '@playwright/test';
import { asRole, switchRole, openSkillsTab, expect } from './helpers';

// =====================================================================
// Journey J3 (end to end) — a member edits their own card, an officer reviews,
// and on approval the value ACTUALLY changes. (Distilled from #40B.)
// This is the gap the old process missed: it checked "the panel cleared", never
// "the value applied". Now asserted end-to-end.
// =====================================================================

test('J3.2 member submits hours → officer approves → the member\'s hours actually change', async ({ page }) => {
  // 1. member submits a change to their own available time
  await asRole(page, 'uid-member'); // Li Hua
  await page.goto('/members/m-li');
  await openSkillsTab(page);
  await expect(page.locator('.sc-head')).toContainText(/review/i);
  await page.locator('.sc-hours').fill('14');
  await page.locator('.sc-save').click();
  await expect(page.locator('.toast')).toContainText(/review/i);

  // 2. an officer of her chapter sees it pending and approves
  await switchRole(page, 'uid-chap'); // Chan Min
  await page.goto('/members/m-li');
  await expect(page.getByText(/Changes awaiting your review/i)).toBeVisible();
  await expect(page.getByText(/Available time → 14 h\/mo/i)).toBeVisible();
  await page.getByRole('button', { name: 'Approve' }).first().click();
  await expect(page.locator('.toast')).toContainText(/approved/i);

  // 3. the change is now applied — reload and the value is 14, no longer pending
  await page.goto('/members/m-li');
  await openSkillsTab(page);
  await expect(page.locator('.sc-hours')).toHaveValue('14');
  await expect(page.getByText(/Changes awaiting your review/i)).toHaveCount(0);
});
