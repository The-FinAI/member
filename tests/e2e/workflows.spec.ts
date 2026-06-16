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
