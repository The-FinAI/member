import { test } from '@playwright/test';
import { asRole, switchRole, dismissQuest, expect } from './helpers';

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

// #51 (@yankai-chen): "Normal users can not create new projects." The creation
// actually SUCCEEDED — but the project landed unattributed (org_unit_id null)
// and a prior change hid unassigned projects from the ledger, so it vanished
// for its own creator with no error: indistinguishable from "can't create".
// Regression guard: a plain member creates an unattributed proposal and SEES it.
test('WGP5 (#51): a plain member creates a project and can still see it afterwards', async ({ page }) => {
  await asRole(page, 'uid-member'); // Li Hua — no officer role anywhere
  await page.goto('/projects');
  await dismissQuest(page);
  const name = 'WGP5 Proposal ' + Date.now();
  await page.getByRole('button', { name: 'Start a project' }).click();
  const form = page.locator('.card.stack', { hasText: 'Start a project' }).first();
  await form.locator('input[placeholder="Project / paper name"]').fill(name);
  await form.locator('select').first().selectOption({ label: 'Dataset' });
  await form.locator('input[placeholder="https://…"]').fill('https://example.com/wgp5');
  await form.getByRole('button', { name: 'Create project' }).click();

  // her proposal is on the ledger, flagged as needing a working group
  const row = page.locator('.lrow', { hasText: name });
  await expect(row, 'the creator can see their own new project').toBeVisible();
  await expect(row.locator('.badge', { hasText: /needs a working group/i })).toBeVisible();

  // and it survives a reload
  await page.goto('/projects');
  await expect(page.locator('.lrow', { hasText: name }), 'still there after reload').toBeVisible();
});

// #52 (audit I-4): the create form offered EVERY working group to any member —
// the backend rejects non-officers only after the whole form was filled. Now the
// dropdown lists only WGs the creator may attribute to; a plain member gets none
// (their proposal starts unattributed) plus a line saying who picks it up.
test('WGP6 (#52): the WG dropdown only offers groups the creator can actually use', async ({ page }) => {
  // plain member → no WG dropdown, just the "starts unattributed" explanation
  await asRole(page, 'uid-member');
  await page.goto('/projects');
  await dismissQuest(page);
  await page.getByRole('button', { name: 'Start a project' }).click();
  const form = page.locator('.card.stack', { hasText: 'Start a project' }).first();
  await expect(form.getByText(/starts unattributed/i)).toBeVisible();
  await expect(form.locator('select')).toHaveCount(2); // Type + Venue only

  // WG officer → sees exactly her own group as an option
  await switchRole(page, 'uid-wg');
  await dismissQuest(page);
  await page.getByRole('button', { name: 'Start a project' }).click();
  const form2 = page.locator('.card.stack', { hasText: 'Start a project' }).first();
  await expect(form2.locator('select')).toHaveCount(3);
  await expect(form2.locator('select').last().locator('option', { hasText: 'Multilingual' })).toHaveCount(1);
});

// #53 decision A (strict bipartite): staffing is the member's home-chapter
// officer's job. A WG leader still SEES who fits (transparency) but gets a
// routing cue instead of an Assign button the backend would reject. (Before:
// any officer saw Assign; assign()+work_seat() had contradictory gates and the
// effective rule rejected BOTH officer types on claimed members — cards worked,
// people didn't: intermittent, unexplained rejections.)
test('WGP7 (#53-A): a WG leader sees candidates but Assign is routed to the chapter officer', async ({ page }) => {
  await asRole(page, 'uid-wg'); // Wu Jing — WG officer, no chapter seat
  await page.goto('/projects');
  await dismissQuest(page);
  const row = page.locator('.lrow', { hasText: 'ml-Tagging' });
  await row.locator('.lrow-head').click();
  await row.locator('.lrow-body').waitFor({ state: 'visible' });
  await row.locator('.need-row', { hasText: 'Annotation' }).first().click();

  // candidates are visible (she can SEE who fits her need)…
  await expect(page.locator('.cand').first()).toBeVisible();
  // …but she cannot assign — the cue routes her to the chapter officer
  await expect(page.locator('.cand .assign')).toHaveCount(0);
  await expect(page.locator('.cand-route').first()).toContainText(/chapter officer/i);

  // and the chapter officer still CAN (the positive path, unchanged)
  await switchRole(page, 'uid-chap');
  const row2 = page.locator('.lrow', { hasText: 'ml-Tagging' });
  await row2.locator('.lrow-head').click();
  await row2.locator('.lrow-body').waitFor({ state: 'visible' });
  await row2.locator('.need-row', { hasText: 'Annotation' }).first().click();
  await expect(page.locator('.cand .assign').first()).toBeVisible();
});
