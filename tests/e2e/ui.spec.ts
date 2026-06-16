import { test } from '@playwright/test';
import { asRole, openSkillsTab, expect } from './helpers';

// =====================================================================
// Journey J4 (affordances) — every control a user must find should be visible
// and look like a control. Distilled from #42 (invisible Cancel) — the start of
// a broader "no unlabeled / invisible affordance" pass.
// =====================================================================

test('J4.4 the add-skill Cancel is a visible, bordered button (not an invisible ghost) — #42', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/members/m-li');
  await openSkillsTab(page);

  await page.locator('.sc-addrow').click(); // "+ Add a skill"
  const cancel = page.locator('.sc-ghost', { hasText: 'Cancel' });
  await expect(cancel).toBeVisible();

  // the old bug: a transparent ghost with a near-invisible border. It must now
  // have a real border AND a non-transparent text colour.
  const { borderW, color } = await cancel.evaluate((e) => {
    const cs = getComputedStyle(e);
    return { borderW: parseFloat(cs.borderTopWidth || '0'), color: cs.color };
  });
  expect(borderW, 'Cancel must have a visible border').toBeGreaterThan(0);
  expect(color, 'Cancel must have a real text colour').not.toMatch(/rgba\(.*0\)$/);
});
