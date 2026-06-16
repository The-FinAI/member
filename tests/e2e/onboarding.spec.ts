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

// A WG-leader explorer reported that clicking Wallet in the account menu changed
// the URL to /wallet but kept rendering the Profile (a "stale render"). Its
// screenshot tool was broken, so this verifies the real behaviour from a route
// where it's most likely to break (an existing /members/* page): real click →
// the Wallet content must actually render, not just the URL change.
test('ONB4: account-menu navigation actually re-renders (Wallet from a profile page)', async ({ page }) => {
  await asRole(page, 'uid-wg'); // Wu Jing
  await page.goto('/members/m-wg'); // start on a profile, the reported failure origin
  await page.locator('.avatar-btn').click();
  await page.locator('.menu-item', { hasText: /Wallet/i }).click();
  await expect(page).toHaveURL(/\/wallet/);
  // the page CONTENT must be the wallet, not the stale profile
  await expect(page.getByText(/STR balance|balance and history|Your STR/i).first()).toBeVisible();
});

// A President explorer who FINISHED the only project then saw the landing claim
// "0 projects across the community" + "No projects match your filters" — reading
// as "the community is empty / you searched wrong", when in fact every project had
// shipped. The subtitle now counts ACTIVE projects (so 0 is honest) and the empty
// state points to the Hall of Fame instead of a failed-search message.
test('ONB5: when every project has shipped, the landing says so (not "0 projects / no match")', async ({ page }) => {
  await asRole(page, 'uid-admin');
  // finish the only (active) project: advance to Under review, then Finish
  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });
  await page.locator('.pcb-step', { hasText: 'Under review' }).click();
  await page.locator('.cf-ok').click();
  await expect(page.locator('.toast')).toContainText(/Status|→/);
  await page.locator('.pcb-done', { hasText: /Finish/ }).click();
  await page.locator('.cf-ok').click();
  await expect(page.getByText(/Project finished/i).first()).toBeVisible();

  // back on the landing: honest "active" count + an all-shipped message, not "no match"
  await page.goto('/projects');
  await expect(page.locator('h1', { hasText: 'Projects' })).toBeVisible();
  await expect(page.getByText(/0 active projects/i)).toBeVisible();
  await expect(page.getByText(/every project has shipped|Hall of fame/i).first()).toBeVisible();
  await expect(page.getByText('No projects match your filters.')).toHaveCount(0);
  // the "shipped" link jumps to the Hall of Fame anchor
  await expect(page.locator('a[href="#hall-of-fame"]')).toBeVisible();
});

// The game-like first-run quest: a cold officer lands on a data table full of
// jargon and a CTA for the WRONG role. The quest names who they are and walks
// them through their first REAL task, auto-advancing as each action lands.
test('ONB6: a chapter officer gets a role-matched quest that auto-advances when they act', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/projects');

  // the right quest greets the right role (not the generic member one)
  const quest = page.locator('.quest');
  await expect(quest).toBeVisible();
  await expect(quest.locator('.q-head strong')).toContainText(/Onboard your first researcher/i);
  await expect(quest.locator('.q-grip-tx')).toContainText('1/3');

  // do the real first step — add a person — and the quest advances on its own
  await page.goto('/people');
  await page.locator('.pp-add').click();
  await page.locator('.pp-addform input').first().fill('Quest Newcomer ' + Date.now());
  await page.locator('.pp-addform input[type="email"]').fill('newcomer@example.com');
  await page.locator('.pp-go').click();
  await expect(page).toHaveURL(/\/members\/m-/);
  // auto-advanced to step 2 (set their hours) without the user touching the panel
  await expect(page.locator('.quest .q-grip-tx')).toContainText('2/3');
});

test('ONB7: a member gets the "find your work" quest and can skip it', async ({ page }) => {
  await asRole(page, 'uid-member'); // Li Hua — no officer role
  await page.goto('/projects');
  const quest = page.locator('.quest');
  await expect(quest.locator('.q-head strong')).toContainText(/Find your work/i);
  // manual advance works for non-auto quests
  await quest.getByRole('button', { name: /Done/i }).click();
  await expect(quest.locator('.q-grip-tx')).toContainText('2/3');
  // and it can be dismissed, never to nag again
  await quest.getByRole('button', { name: /Skip/i }).click();
  await expect(page.locator('.quest')).toHaveCount(0);
});
