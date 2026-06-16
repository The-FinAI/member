import { test } from '@playwright/test';
import { asRole, switchRole, trackErrors, openSkillsTab, expect } from './helpers';

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

// WF5 — WG leader ships the paper's tail: advance the project to Under review,
// Finish it (an irreversible, danger-confirmed step), and the settlement opens.
// Crosses the high-risk Finish → Settle surface she hasn't tested.
test('WF5: WG leader finishes a project (danger confirm) → settlement opens', async ({ page }) => {
  const errs = trackErrors(page);
  await asRole(page, 'uid-admin');
  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });

  // 1) advance Active → Under review (confirm gate)
  await page.locator('.pcb-step', { hasText: 'Under review' }).click();
  await expect(page.locator('.cf-modal')).toBeVisible();
  await page.locator('.cf-ok').click();
  await expect(page.locator('.toast')).toContainText(/Status|→/);

  // 2) Finish appears at Under review — it is irreversible, so the confirm is danger
  const finish = page.locator('.pcb-done', { hasText: /Finish/ });
  await expect(finish).toBeVisible();
  await finish.click();
  await expect(page.locator('.cf-ok.danger'), 'Finish must be a danger confirm').toBeVisible();
  await page.locator('.cf-ok').click();
  await expect(page.getByText(/Project finished/i).first()).toBeVisible();

  // 3) the project is finished and the settlement surface opens
  await expect(page.getByText(/Settlement/i).first()).toBeVisible();
  expect(errs(), 'console clean across the close-out').toEqual([]);
});

// WF6 — the BIPARTITE HANDOFF between two DIFFERENT officers (the system's core
// design: chapters hold people, working groups hold projects, they meet at a
// need). The WG leader posts demand; a chapter officer supplies it. Not one
// person wearing two hats — two people handing off at the need.
test('WF6: WG leader posts a need; a chapter officer (different person) staffs it', async ({ page }) => {
  // PART 1 — Wu Jing, the WORKING-GROUP leader, posts an open role on her project
  await asRole(page, 'uid-wg');
  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });
  await page.locator('.np-toggle').first().click(); // "+ Post a role"
  await page.locator('.np select').first().selectOption({ label: 'Annotation' });
  await page.locator('.np-n').first().fill('6');
  await page.locator('.np-go').click();
  await expect(page.getByText(/qualify|Posted/i)).toBeVisible();

  // PART 2 — Chan Min, the CHAPTER officer (a different person), staffs a person
  // from her chapter into that project's open Annotation need.
  await switchRole(page, 'uid-chap');
  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });
  await page.locator('.need-row', { hasText: 'Annotation' }).first().click();
  const cand = page.locator('.cand', { hasText: 'Li Hua' });
  await expect(cand).toBeVisible();
  await cand.locator('.cand-h').fill('5');
  await cand.locator('.assign').click();
  await page.locator('.cf-ok').click(); // assigning confirms (#33)
  await expect(page.locator('.toast')).toContainText(/Assigned/i);

  // the handoff completed: the WG leader's project now has the chapter's person
  await expect(page.locator('.tchip', { hasText: 'Li Hua' })).toBeVisible();
});

// WF8 — onboard a BRAND-NEW person from scratch. Every other test starts from a
// seeded roster, so the officer's literal first action — create a person, then
// set their availability so they can be staffed — was never exercised. (Surfaced
// by a black-box explorer sent to "onboard Wang Lei": the create→equip→persist
// lifecycle had zero coverage.) Real clicks, full round-trip to persistence.
test('WF8: officer creates a new person, sets their hours, and it persists + shows on the roster', async ({ page }) => {
  const errs = trackErrors(page);
  await asRole(page, 'uid-chap'); // Chan Min, Beijing chapter officer
  await page.goto('/people');

  // 1) open the add form and create the newcomer
  const name = 'Wang Lei ' + Date.now();
  await page.locator('.pp-add').click();
  await page.locator('.pp-addform input').first().fill(name);
  await page.locator('.pp-addform input[type="email"]').fill('wanglei@example.com');
  await page.locator('.pp-addform input').nth(2).fill('Tsinghua');
  await page.locator('.pp-go').click();

  // 2) the officer is dropped straight onto the new card to equip them
  await expect(page).toHaveURL(/\/members\/m-/);
  await expect(page.getByText(name).first()).toBeVisible();

  // 3) a brand-new person has NO availability yet — set it and Save (#43 path,
  //    but on a freshly-created card whose monthly_hours started null)
  await openSkillsTab(page);
  await page.locator('.sc-hours').fill('15');
  await page.locator('.sc-save').click();
  await expect(page.locator('.toast')).toContainText('Saved');

  // 4) reload the card — the availability stuck
  await page.reload();
  await openSkillsTab(page);
  await expect(page.locator('.sc-hours')).toHaveValue('15');

  // 5) and the newcomer is now a real row on the roster with that capacity
  await page.goto('/people');
  const row = page.locator('a', { hasText: name });
  await expect(row).toBeVisible();
  await expect(row).toContainText('15');

  expect(errs(), 'console clean across the onboarding').toEqual([]);
});

// WF7 — the handoff reaches the THIRD person. After a chapter officer staffs her,
// the member herself learns she's on a project (the notification). Three distinct
// people across one collaboration: WG leader → chapter officer → member.
test('WF7: a staffed member is notified she joined the project (the third person)', async ({ page }) => {
  // chapter officer staffs Li Hua onto the open Annotation need
  await asRole(page, 'uid-chap');
  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });
  await page.locator('.need-row', { hasText: 'Annotation' }).first().click();
  const cand = page.locator('.cand', { hasText: 'Li Hua' });
  await cand.locator('.cand-h').fill('5');
  await cand.locator('.assign').click();
  await page.locator('.cf-ok').click();
  await expect(page.locator('.toast')).toContainText(/Assigned/i);

  // now SHE logs in — and finds out she was assigned (the notification)
  await switchRole(page, 'uid-member'); // Li Hua
  await page.locator('.ni-bell').click();
  await expect(page.getByText(/assigned to a project/i).first()).toBeVisible();
});
