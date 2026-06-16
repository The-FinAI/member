import { test } from '@playwright/test';
import { asRole, expect } from './helpers';

// =====================================================================
// ROUTE SMOKE — every surface must mount without a runtime crash. A black-box
// explorer found the /wallet page silently dead ("joinStake is not defined"): a
// ReferenceError that aborted the client-side mount and left the OLD page on
// screen. svelte-check flagged it as "Cannot find name" and I'd dismissed it as
// type noise — it was a real crash. The class (undefined-reference on a route)
// had ZERO coverage, because every other test drives a known-good path.
//
// This walks the app the way a user does — CLIENT-SIDE navigation via the nav and
// the account menu (not fresh page.goto, which hides client-render crashes) — and
// the pageerror listener fails on ANY runtime throw. It would have caught
// joinStake / openProject / awardOpen.
// =====================================================================

test('SMOKE: every surface mounts without a runtime crash (client-side nav)', async ({ page }) => {
  const crashes: string[] = [];
  page.on('pageerror', (e) => crashes.push(String(e?.message ?? e)));

  await asRole(page, 'uid-admin'); // President — can see every surface incl. /admin
  await page.goto('/projects');
  await expect(page.locator('h1', { hasText: 'Projects' })).toBeVisible();

  // top-nav surfaces (anchor navigation): URL commits + a route-stable marker renders
  for (const [label, route, marker] of [
    ['PEOPLE', '/people', page.locator('h1', { hasText: 'People' })],
    ['DIRECTORY', '/community', page.locator('h1', { hasText: 'Directory' })],
    ['GUIDE', '/guide', page.locator('.guide nav.toc')],
    ['ADMIN', '/admin', page.locator('h1', { hasText: 'Admin' })]
  ] as const) {
    await page.locator('.sec-link', { hasText: label }).click();
    await expect(page, `${label} navigates`).toHaveURL(new RegExp(route));
    await expect(marker, `${label} must render its own page, not a stale one`).toBeVisible();
  }

  // account-menu surfaces (programmatic goto — where the wallet crash hid)
  for (const [item, route] of [
    ['My tasks', '/my'],
    ['My profile', '/members/'],
    ['Wallet', '/wallet']
  ] as const) {
    await page.locator('.avatar-btn').click();
    await page.locator('.menu-item', { hasText: new RegExp(item, 'i') }).click();
    await expect(page, `${item} navigates`).toHaveURL(new RegExp(route));
    await expect(page.locator('main')).toBeVisible();
  }

  // the wallet specifically must show its OWN content (the exact crash surface) —
  // proves the mount succeeded rather than leaving the prior page on screen
  await expect(page.getByText(/balance and history|Your STR/i).first()).toBeVisible();

  expect(crashes, 'no page threw a runtime error during navigation').toEqual([]);
});
