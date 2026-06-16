import { test } from '@playwright/test';
import { asRole, dismissQuest, expect } from './helpers';

// =====================================================================
// THE WG-LEADER PROJECT LIFECYCLE — the flow that was conceptually wrong AND
// unwired: a project belongs to a working group via org_unit_id, and ONLY a WG's
// officer can post needs / edit a project in their WG (canManage gates on it). So
// a WG leader's real moves are: ADOPT an unassigned project into their WG (or
// CREATE one there) → which unlocks → EDIT / POST NEEDS. None of this had mock
// support or coverage; the seed had no unassigned project and no adopt UI.
// =====================================================================

// 归属 ADOPT — a WG officer takes an unassigned proposal into their working group.
test('WGP1: a WG officer adopts an unassigned project into their group (persists)', async ({ page }) => {
  await asRole(page, 'uid-wg'); // Wu Jing — officer of one working group
  await page.goto('/projects');

  // the unassigned proposal is offered for adoption
  const adoptRow = page.locator('.adopt-row', { hasText: 'fin-Sentiment' });
  await expect(adoptRow, 'an unassigned project is offered to a WG officer').toBeVisible();
  await adoptRow.locator('.adopt-go').click();

  // once adopted it leaves the "looking for a group" list…
  await expect(page.locator('.adopt-row', { hasText: 'fin-Sentiment' })).toHaveCount(0);
  // …and the adoption sticks across a reload
  await page.reload();
  await expect(page.locator('.adopt-row', { hasText: 'fin-Sentiment' })).toHaveCount(0);
});

// 发布 POST NEED after adopting — proves the permission unlock: setting org_unit_id
// to her WG makes canManage/canPostNeed true, so she can now run the board.
test('WGP2: after adopting, the WG officer can edit it and post a need (the unlock)', async ({ page }) => {
  await asRole(page, 'uid-wg');
  await page.goto('/projects');
  await page.locator('.adopt-row', { hasText: 'fin-Sentiment' }).locator('.adopt-go').click();
  await expect(page.locator('.adopt-row', { hasText: 'fin-Sentiment' })).toHaveCount(0);

  // open the now-owned project in the ledger; the manage affordance is present
  const row = page.locator('.lrow', { hasText: 'fin-Sentiment' });
  await row.locator('.lrow-head').click();
  await row.locator('.lrow-body').waitFor({ state: 'visible' });
  // "Post a role" is a WG-officer-only control — its presence proves the unlock
  await expect(row.locator('.np-toggle'), 'posting a need is now permitted').toBeVisible();
  await row.locator('.np-toggle').first().click();
  await row.locator('.np select').first().selectOption({ label: 'Annotation' });
  await row.locator('.np-n').first().fill('4');
  await row.locator('.np-go').click();
  await expect(page.getByText(/qualify|Posted/i)).toBeVisible();
});

// permission negative — a member who officers NO working group never sees adopt.
test('WGP3: a non-WG-officer is not offered project adoption', async ({ page }) => {
  await asRole(page, 'uid-member'); // Li Hua — plain member
  await page.goto('/projects');
  await expect(page.locator('.adopt')).toHaveCount(0);
});

// 新建 CREATE — a WG officer creates a project under their working group.
test('WGP4: a WG officer creates a project under their group', async ({ page }) => {
  await asRole(page, 'uid-wg');
  await page.goto('/projects');
  await dismissQuest(page); // experienced officer; clear the first-run panel
  const name = 'WGP4 Bench ' + Date.now();
  await page.getByRole('button', { name: 'Start a project' }).click();
  const form = page.locator('.card.stack', { hasText: 'Start a project' });
  await form.locator('input[placeholder="Project / paper name"]').fill(name);
  await form.locator('select').first().selectOption({ label: 'Dataset' });      // Type
  await form.locator('input[placeholder="https://…"]').fill('https://example.com/p');
  await form.locator('select').last().selectOption({ index: 1 });                // Working Group
  await form.getByRole('button', { name: 'Create project' }).click();

  // it now exists; find it on the ledger (create may hand off to the officer console first)
  await page.goto('/projects');
  await expect(page.locator('.lrow', { hasText: name })).toBeVisible();
});
