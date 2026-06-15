import { test } from '@playwright/test';
import { asRole, expect } from './helpers';

// =====================================================================
// Journey J4 — a newcomer navigates and understands.
// "Where am I, what does this mean, how do I get back / join?"
// Distilled from #24 / #22 / #47 / #45 / #46.
// =====================================================================

test('J4.1 root redirects to the projects ledger, and Back doesn\'t bounce — #24', async ({ page }) => {
  await asRole(page, 'uid-admin');
  // root → projects (the landing)
  await page.goto('/');
  await expect(page).toHaveURL(/\/projects$/);

  // go deeper, then Back must return to /projects (not bounce through '/')
  await page.goto('/people');
  await expect(page).toHaveURL(/\/people$/);
  await page.goBack();
  await expect(page, 'Back returns to projects, not a redirect loop').toHaveURL(/\/projects$/);
});

test('J4.2 a non-officer sees what a chapter is + that joining is reviewed — #47', async ({ page }) => {
  await asRole(page, 'uid-member');
  await page.goto('/community?tab=chapters');
  const card = page.locator('.card-grid > *').first();
  await card.waitFor({ state: 'visible' });
  await card.click();

  // description shown to a visitor + a note about what joining means / review
  await expect(page.locator('.ud-desc')).toBeVisible();
  await expect(page.locator('.ud-note')).toContainText(/join|review|officer/i);
});

test('J4.3 People is the roster; matching is not bolted onto it — #22', async ({ page }) => {
  await asRole(page, 'uid-admin');
  await page.goto('/people');
  // the roster renders people; the old in-page "Match people to needs" board is gone
  await expect(page.getByText(/Add a person/i).first()).toBeVisible();
  await expect(page.getByText('Match people to needs')).toHaveCount(0);
});
