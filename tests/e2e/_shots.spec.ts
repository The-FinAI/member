import { test } from '@playwright/test';
import { asRole, dismissQuest } from './helpers';

// Not a check — a screenshot run for documentation/announcements. Mock data only:
// these images get served publicly, so no real member names or hours.
test.use({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });

test('shots: meeting view', async ({ page }) => {
  test.skip(!process.env.SHOTS, 'documentation screenshots — run with SHOTS=1');
  await asRole(page, 'uid-chap');
  await page.addInitScript(() => {
    for (const mid of ['m-me', 'm-li', 'm-wang', 'm-zhao', 'm-wg', 'm-chap', 'm-admin'])
      try { localStorage.setItem(`onboarding_v1_${mid}`, JSON.stringify({ questId: '', step: 0, status: 'skipped', baseline: {} })); } catch { /* ignore */ }
  });
  await page.goto('/market');
  await dismissQuest(page);
  await page.getByRole('button', { name: 'Meeting' }).click();
  const mt = page.locator('.mt');
  await mt.waitFor();
  await page.waitForTimeout(400);
  await page.screenshot({ path: 'static/meeting/board.png', fullPage: true });

  // working-group lane
  await mt.locator('.gname', { hasText: 'Multilingual' }).click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'static/meeting/agenda.png', clip: { x: 0, y: 0, width: 1440, height: 400 } });
  await mt.locator('.row').first().click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'static/meeting/project.png', clip: { x: 0, y: 0, width: 1440, height: 560 } });

  // chapter lane
  await mt.locator('.crumbs button', { hasText: 'Board' }).click();
  await mt.locator('.card', { hasText: 'Beijing Chapter' }).click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'static/meeting/roster.png', clip: { x: 0, y: 0, width: 1440, height: 560 } });

  // person screen, with capacity + a skill filled in so the match shows
  await mt.locator('.row', { hasText: 'Pei Lan' }).click();
  await mt.locator('input.cap').fill('12');
  await mt.locator('input.cap').blur();
  await page.waitForTimeout(400);
  await mt.locator('details.add > summary').click();
  await mt.locator('.addrow').nth(0).locator('select').first().selectOption({ label: 'Annotation' });
  await mt.locator('.addrow').nth(0).getByRole('button', { name: 'Add' }).click();
  await page.waitForTimeout(500);
  await mt.locator('details.add > summary').click(); // collapse the adder again
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'static/meeting/person.png', clip: { x: 0, y: 0, width: 1440, height: 580 } });
});
