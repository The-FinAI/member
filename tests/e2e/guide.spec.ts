import { test } from '@playwright/test';
import { asRole, expect } from './helpers';

// =====================================================================
// Journey J5 (guide ↔ UI) — the guide must not point at surfaces that don't
// exist / don't reach. Distilled from #29 ("keep the guide in sync with the UI").
// =====================================================================

test('J5.4 every guide "Your pages" link reaches a real surface — #29', async ({ page }) => {
  await asRole(page, 'uid-admin');
  await page.goto('/guide');
  await page.locator('.pages a').first().waitFor({ state: 'visible' });

  const links = await page.locator('.pages a').evaluateAll((as) =>
    as.map((a) => (a as HTMLAnchorElement).getAttribute('href') || '')
  );
  expect(links.length, 'the guide lists pages').toBeGreaterThan(0);

  for (const href of links) {
    await page.goto(href);
    await expect(page, `guide link ${href} should not bounce to login`).not.toHaveURL(/\/login/);
    await expect(
      page.locator('main, body').first(),
      `guide link ${href} should reach a real page (no 404 / "no such")`
    ).not.toContainText(/No such|404|not found|Page not found/i);
  }
});
