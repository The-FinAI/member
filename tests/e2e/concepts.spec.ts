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
  // a VISIBLE "?" affordance sits beside STR (tappable, not hover-only) and opens
  // an explanation — so a scanning / mobile officer can learn what STR is.
  await expect(page.locator('.mast-right .hint .dot')).toBeVisible();
  await page.locator('.mast-right .hint').hover();
  await expect(page.locator('.mast-right .hint .bubble')).toContainText(/credit|accrues|settle/i);
});

test('M2 (two officer types): the guide distinguishes Chapter Officer from WG Leader', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/guide');
  // the two foreign roles are separated and named (the #28 rewrite)
  await expect(page.locator('#chapter')).toContainText(/chapter/i);
  await expect(page.locator('#wg')).toContainText(/working group/i);
});

test('M3 (custodial cards): the "card" concept is explained VISIBLY, not just on hover', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/people');
  // a scanning / mobile user never hovers — the meaning must be on the page.
  // (A black-box explorer, reading the screen, still found "card" unexplained
  // when it was only a title= tooltip.)
  const legend = page.locator('.pp-legend');
  await expect(legend, 'the card concept must be spelled out in visible text').toBeVisible();
  await expect(legend).toContainText(/manage on their behalf|claim/i);
});
