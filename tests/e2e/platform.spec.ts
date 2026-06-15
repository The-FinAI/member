import { test } from '@playwright/test';
import { asRole, openSkillsTab, trackErrors, expect } from './helpers';

// =====================================================================
// Journey J5 — consistency & platform.
// "One skill scale, one capacity number, mobile/dark just work."
// Distilled from #21 / #36 / #17 / #40A.
// =====================================================================

test('J5.1 one skill scale on the profile — no legacy guild badges — #21', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/members/m-li');
  await openSkillsTab(page);

  // the current scale is present…
  await expect(page.locator('.sc-seg .seg', { hasText: 'Lead' }).first()).toBeVisible();
  // …and the retired guild system is gone (no Medal, no "Certified badges", no Badges KPI)
  await expect(page.locator('.medal')).toHaveCount(0);
  await expect(page.getByText(/Certified badges/i)).toHaveCount(0);
  await expect(page.getByText(/Apprentice|Journeyman|Craftsman|Master/)).toHaveCount(0);
});

test('J5.2 mobile: project row — status badge does NOT overlap the title, no h-scroll — #36', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await asRole(page, 'uid-admin');
  await page.goto('/projects');

  const row = page.locator('.lrow-head').first();
  await row.waitFor({ state: 'visible' });
  const title = row.locator('.lr-title');
  const badge = row.locator('.badge, .status').first();

  const tb = await title.boundingBox();
  const bb = await badge.boundingBox();
  expect(tb && bb).toBeTruthy();
  // they must not overlap: badge sits to the right of, or below, the title — not on top of it
  const overlaps = tb && bb &&
    tb!.x < bb!.x + bb!.width && bb!.x < tb!.x + tb!.width &&
    tb!.y < bb!.y + bb!.height && bb!.y < tb!.y + tb!.height;
  expect(overlaps, 'status badge must not overlap the project title').toBeFalsy();

  // no horizontal scroll at phone width
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow, 'no horizontal overflow at 375px').toBeLessThanOrEqual(1);
});

test('J5.3 dark edition renders cleanly — #17', async ({ page }) => {
  const errs = trackErrors(page);
  await asRole(page, 'uid-admin');
  await page.goto('/projects');
  // flip to the dark edition via the masthead theme toggle
  await page.getByRole('button', { name: /Toggle theme/i }).click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  // text colour should be the light-ink token, not black-on-black
  const textColor = await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--text').trim());
  expect(textColor.toLowerCase()).not.toBe('');
  expect(errs(), 'console clean in dark mode').toEqual([]);
});
