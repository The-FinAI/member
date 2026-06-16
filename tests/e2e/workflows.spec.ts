import { test } from '@playwright/test';
import { asRole, trackErrors, openSkillsTab, expect } from './helpers';

// =====================================================================
// WORKFLOWS — she tests by walking a real role's job END TO END, not by probing
// one control. Bugs surface where the workflow breaks mid-stream. So each test
// is the whole sequence a role actually performs.
// =====================================================================

// WF1 — Chapter Officer: keep a person's record current, then staff them onto a
// project need, and confirm they landed on the team. (This is literally the flow
// behind #10/#14/#26/#43/#44: manage availability → match → staff.)
test('WF1: officer updates a member, staffs them onto a need, sees them on the team', async ({ page }) => {
  const errs = trackErrors(page);
  await asRole(page, 'uid-chap'); // Chan Min, Beijing chapter officer

  // 1) start from the roster (where she lives)
  await page.goto('/people');
  await page.getByText('Li Hua').first().click();
  await expect(page).toHaveURL(/\/members\/m-li/);

  // 2) set her available time and SAVE (the step that used to silently fail)
  await openSkillsTab(page);
  await page.locator('.sc-hours').fill('12');
  await page.locator('.sc-save').click();
  await expect(page.locator('.toast')).toContainText('Saved');

  // 3) go to the project and open the Annotation need in the matcher
  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });
  await page.locator('.need-row', { hasText: 'Annotation' }).first().click();

  // 4) Li Hua qualifies (Annotation @ Independent) — assign her 8h
  const liCand = page.locator('.cand', { hasText: 'Li Hua' });
  await expect(liCand).toBeVisible();
  await liCand.locator('.cand-h').fill('8');
  await liCand.locator('.assign').click();

  // assigning a role confirms first (#33) — confirm it
  await expect(page.locator('.cf-modal')).toBeVisible();
  await page.locator('.cf-ok').click();
  await expect(page.locator('.toast')).toContainText(/Assigned/i);

  // 5) she now appears on the project team — and survives a reload
  await expect(page.locator('.tchip', { hasText: 'Li Hua' })).toBeVisible();
  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await expect(page.locator('.tchip', { hasText: 'Li Hua' })).toBeVisible();

  expect(errs(), 'console clean across the whole workflow').toEqual([]);
});

// WF2 — Working-Group Leader runs the project record: open the project, add a
// task to the board, then advance the project's status (which must confirm).
// The daily "keep the living record alive + move the project" flow.
test('WF2: WG leader adds a task and advances project status (with a confirm gate)', async ({ page }) => {
  const errs = trackErrors(page);
  await asRole(page, 'uid-admin'); // can edit the project + change status

  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });

  // 1) add a task to the board
  const taskName = 'WF2 collect filings ' + Date.now();
  await page.locator('.tb-addrow').first().click();
  await page.locator('.tb-add input.cell').first().fill(taskName);
  await page.locator('.tb-go').first().click();
  await expect
    .poll(async () => {
      const rows = page.locator('.tb-table tr').filter({ has: page.locator('.tb-x') });
      const n = await rows.count();
      for (let i = 0; i < n; i++) if ((await rows.nth(i).locator('input.cell').first().inputValue()) === taskName) return true;
      return false;
    })
    .toBe(true);

  // 2) advance the status — must ask to confirm, not commit silently (#35)
  await page.locator('.pcb-step:not([disabled])').first().click();
  await expect(page.locator('.cf-modal')).toBeVisible();
  await expect(page.locator('.cf-title')).toContainText(/status/i);
  await page.locator('.cf-ok').click();
  await expect(page.locator('.toast')).toContainText(/Status|→/);

  expect(errs(), 'console clean').toEqual([]);
});

// WF3 — a member does their own work: open My tasks, find the task assigned to
// them, change its state, and have it persist. (The member's daily flow.)
test('WF3: a member reopens their own task on My tasks, and it persists', async ({ page }) => {
  await asRole(page, 'uid-member'); // Li Hua — owns the "EN / 3 taxonomies" task (done)
  await page.goto('/my');

  const card = page.locator('.mt-lanes .card', { hasText: '3 taxonomies' });
  await expect(card, 'her task shows on My tasks').toBeVisible();

  // it's in the done lane → reopen it (the undo control)
  await card.locator('button[title="Reopen"]').click();
  // now it's an open task → it gains the "Start" control
  await expect(card.locator('button[title="Start"]')).toBeVisible();

  // reload → the state change persisted (still open, still has Start)
  await page.goto('/my');
  const card2 = page.locator('.mt-lanes .card', { hasText: '3 taxonomies' });
  await expect(card2.locator('button[title="Start"]'), 'reopened state persists').toBeVisible();
});

// WF4 — joining: a researcher browses a working group they're not in, reads what
// it is, and applies; the request goes pending. (The #47 join flow, end to end.)
test('WF4: a member browses a working group and applies → request goes pending', async ({ page }) => {
  await asRole(page, 'uid-member'); // Li Hua — in Beijing chapter, not the WG
  await page.goto('/community?tab=wgroups');

  const card = page.locator('.card-grid > *').first();
  await card.waitFor({ state: 'visible' });
  await card.click();

  // she can read what it is (context) and apply
  await expect(page.locator('.ud-desc')).toBeVisible();
  const apply = page.locator('button', { hasText: 'Apply to join' });
  await expect(apply).toBeVisible();
  await apply.click();

  // the request is now pending (button reflects it)
  await expect(page.getByText(/Application pending/i)).toBeVisible();
});
