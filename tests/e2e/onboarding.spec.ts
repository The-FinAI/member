import { test } from '@playwright/test';
import { asRole, expect } from './helpers';

// =====================================================================
// FIRST LOGIN, two officer types, low compliance. The home is the PROJECT
// ledger, but a CHAPTER officer's job is PEOPLE — so the landing must orient
// each officer to THEIR job, or a first-timer (esp. with an empty roster) is
// stranded. (Found by walking the first-login chapter officer; her #45/#44 class.)
// =====================================================================

test('ONB1: a chapter officer\'s landing points to their people-job (not just projects)', async ({ page }) => {
  await asRole(page, 'uid-chap'); // Chan Min — manages people, lands on /projects
  await page.goto('/projects');

  // the "what needs you" strip must give a chapter officer a path to their roster
  const peopleItem = page.locator('.ny-item[href="/people"]');
  await expect(peopleItem, 'a chapter officer needs a path to People from the landing').toBeVisible();
  await expect(peopleItem).toContainText(/chapter|people/i);
});

test('ONB2: a WG leader\'s landing matches their job — start/run projects', async ({ page }) => {
  await asRole(page, 'uid-wg'); // Wu Jing — manages projects; the ledger IS her home
  await page.goto('/projects');
  // her primary action is here and discoverable
  await expect(page.getByRole('button', { name: /Start a project/i })).toBeVisible();
});

// A cold member logs in to find their work, but /my (My tasks) had NO nav entry
// and was absent from the avatar menu (only My profile / Wallet / Sign out) — so
// the member's primary surface was unreachable except via easily-missed cards.
// (Found by a source-blind member explorer: "I can't act on my tasks" — because
// they couldn't FIND the page where the action lives. The control existed; the
// route was orphaned.)
test('ONB3: a member can reach My tasks from the account menu', async ({ page }) => {
  await asRole(page, 'uid-member'); // Li Hua
  await page.goto('/projects');
  await page.locator('.avatar-btn').click();
  const myTasks = page.locator('.menu-item', { hasText: /My tasks/i });
  await expect(myTasks, 'the member needs a discoverable path to their own work').toBeVisible();
  await myTasks.click();
  await expect(page).toHaveURL(/\/my/);
  await expect(page.locator('.mt-lanes')).toBeVisible();
});
