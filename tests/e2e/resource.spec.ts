import { test } from '@playwright/test';
import { asRole, expect } from './helpers';

// =====================================================================
// RESOURCE CATALOG round-trip — the President explorer found editing a card's
// GPU resource quota silently reverted: the forge form requires a GPU model, the
// mock seeded none, so the save bailed at validation and update_resource never
// ran. (Same Save-doesn't-persist class as #43, on a different surface — and the
// whole resource flow had ZERO test coverage.) With models now seeded, this is
// the missing round-trip: officer edits a card's resource quota → Save → reload →
// persisted.
// =====================================================================

test('RES1: an officer edits a card resource quota → Save → reload → persisted', async ({ page }) => {
  const errs: string[] = [];
  page.on('pageerror', (e) => errs.push(String(e?.message ?? e)));

  await asRole(page, 'uid-admin'); // President — manage_resources
  await page.goto('/members/m-wang'); // Wang Fang (a card) holds "A100 ×2", quota 200

  // open the Resources section (tabbed, like Skills)
  await page.locator('.detail-nav a[href="#resources"]').click();
  const row = page.locator('tr', { hasText: 'A100' });
  await expect(row).toBeVisible();
  await expect(row).toContainText('200');

  // edit → the forge form loads with the existing quota + its GPU model
  await row.getByRole('button', { name: 'Edit' }).click();
  const quota = page.locator('input[type="number"]').first();
  await expect(quota).toHaveValue('200');
  await quota.fill('250');
  await page.getByRole('button', { name: 'Save changes' }).click();

  // the edit went to review and the table reflects the new number
  await expect(page.locator('tr', { hasText: 'A100' })).toContainText('250');

  // reload → it actually persisted (the bug was: reverted to 200)
  await page.reload();
  await page.locator('.detail-nav a[href="#resources"]').click();
  await expect(page.locator('tr', { hasText: 'A100' }), 'edited quota survives a reload').toContainText('250');

  expect(errs, 'no runtime crash editing a resource').toEqual([]);
});
