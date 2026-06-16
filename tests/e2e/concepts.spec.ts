import { test } from '@playwright/test';
import { asRole, expect } from './helpers';

// =====================================================================
// MENTAL-MODEL BRIDGE — the testers are OFFICERS who came from Google Docs. They
// don't carry this system's invented concepts: (a) the STR economy, (b) two kinds
// of group officer (Chapter vs Working-Group), (c) custodial member-cards. Their
// confusion is the mismatch between the old flat-doc model and these abstractions,
// so the UI must explain each WHERE it's first encountered — not only in the guide.
// =====================================================================

test('M1 (economy): STR is explained where it is first seen, not just a bare number', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/projects');
  const str = page.locator('.mast-wallet');
  await expect(str).toBeVisible();
  // an officer who has never heard of "STR" can learn what it is right here
  await expect(str).toHaveAttribute('title', /credit|contribution|guide/i);
});

test('M2 (two officer types): the guide distinguishes Chapter Officer from WG Leader', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/guide');
  // the two foreign roles are separated and named (the #28 rewrite)
  await expect(page.locator('#chapter')).toContainText(/chapter/i);
  await expect(page.locator('#wg')).toContainText(/working group/i);
});

test('M3 (custodial cards): the "card" tag explains the custodial concept', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/people');
  const tag = page.locator('.pc-tag', { hasText: 'card' }).first();
  await expect(tag).toBeVisible();
  // "card" is meaningless to a doc user unless it says what it is
  await expect(tag).toHaveAttribute('title', /claim|manage|behalf|signed up/i);
});
