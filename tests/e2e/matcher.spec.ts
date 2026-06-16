import { test } from '@playwright/test';
import { asRole, expect } from './helpers';

// =====================================================================
// Journey J1 (matching) — staffing a need.
// "When I look at candidates, I can see who qualifies and WHY someone doesn't —
//  the missing skill level is named, not a blank 'doesn't meet requirements'."
// Distilled from #31 / #32. Seed: the Annotation need wants Independent; Zhao Lei
// holds Annotation at Learning (under-qualified); Wang Fang holds it at Lead.
// =====================================================================

async function openMatcherNeed(page, needText: string) {
  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });
  const need = page.locator('.need-row', { hasText: needText });
  await need.first().waitFor({ state: 'visible' });
  await need.first().click();
}

test('J1.4 the matcher names the missing level for an under-qualified candidate — #32', async ({ page }) => {
  await asRole(page, 'uid-admin'); // can seat
  await openMatcherNeed(page, 'Annotation');

  // Zhao Lei (Annotation @ Learning) must show as not-fitting, with the reason
  // naming the required level — not a blank rejection.
  const zhao = page.locator('.cand', { hasText: 'Zhao Lei' });
  await expect(zhao).toBeVisible();
  await expect(zhao.locator('.cand-reason')).toContainText(/independent/i);

  // a qualified candidate (Wang Fang @ Lead) is NOT flagged with a reason
  const wang = page.locator('.cand', { hasText: 'Wang Fang' });
  await expect(wang).toBeVisible();
  await expect(wang.locator('.cand-reason')).toHaveCount(0);
});
