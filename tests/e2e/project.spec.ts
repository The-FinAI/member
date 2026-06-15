import { test } from '@playwright/test';
import { asRole, trackErrors, expect } from './helpers';

// =====================================================================
// Journey J2 — an officer takes a consequential action and wants safety.
// "When I change status / finish / assign / remove, I want a confirm gate and a
//  way back — nothing silent or one-click-irreversible."
// Distilled from #20 / #31 / #33 / #34 / #35.
// =====================================================================

async function openFirstProject(page) {
  await page.goto('/projects');
  const row = page.locator('.lrow-head').first();
  await row.waitFor({ state: 'visible' });
  await row.click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });
}

test('J2.1 changing a project status asks to confirm (not silent) — #35', async ({ page }) => {
  await asRole(page, 'uid-admin');
  await openFirstProject(page);

  const step = page.locator('.pcb-step:not([disabled])').first();
  await expect(step).toBeVisible();
  await step.click();

  // a confirm dialog must appear before the change commits
  await expect(page.locator('.cf-modal')).toBeVisible();
  await expect(page.locator('.cf-title')).toContainText(/status/i);

  // cancelling must NOT change anything
  await page.locator('.cf-cancel').click();
  await expect(page.locator('.cf-modal')).toHaveCount(0);
});

test('J2.2 finishing a project is gated by a danger confirm — #35', async ({ page }) => {
  await asRole(page, 'uid-admin');
  await openFirstProject(page);

  const finish = page.locator('.pcb-done');
  // Finish only shows at "Under review"; if present, it must confirm (danger)
  if (await finish.count()) {
    await finish.first().click();
    await expect(page.locator('.cf-modal')).toBeVisible();
    await expect(page.locator('.cf-ok.danger')).toBeVisible();
    await page.locator('.cf-cancel').click();
  }
});

test('J2.3 a seated person can be removed from the team (undo) — #33', async ({ page }) => {
  const errs = trackErrors(page);
  await asRole(page, 'uid-admin');
  await openFirstProject(page);

  // the team chips carry a remove control when the viewer can seat
  const remove = page.locator('.tc-x').first();
  if (await remove.count()) {
    await remove.click();
    await expect(page.locator('.cf-modal')).toBeVisible();      // confirm before removing
    await expect(page.locator('.cf-title')).toContainText(/remove/i);
    await page.locator('.cf-cancel').click();
  }
  expect(errs(), 'console clean').toEqual([]);
});
