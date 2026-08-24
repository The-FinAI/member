import { test } from '@playwright/test';
import { asRole, trackErrors, dismissQuest, resetDb, expect } from './helpers';

// 市场 Market (v49 落地, governance v0.3 无权限期) — Definition of Done:
// real role · real surface · interact → control appears → reload → persisted ·
// console clean. Settlement/minting stay President-gated and are NOT here.


// a row can collapse when a background reload lands between our isVisible
// check and the next action — retry open until the body is really there
async function ensureOpen(row: import('@playwright/test').Locator) {
  await expect(async () => {
    if (!(await row.locator('.pbody').isVisible())) await row.locator('> summary').click({ force: true });
    expect(await row.locator('.pbody').isVisible()).toBeTruthy();
  }).toPass({ timeout: 10_000 });
}

test.describe('market — officer single page', () => {
  test.beforeEach(async ({ page }) => {
    resetDb(); // real-DB lane: fresh world per test (no-op on mock)
    await asRole(page, 'uid-chap'); // Chan Min: chapter officer (no admin caps)
    // pre-complete the onboarding quest for every persona so its fixed panel
    // never intercepts market clicks (quests have their own spec)
    await page.addInitScript(() => {
      for (const mid of ['m-me', 'm-li', 'm-wang', 'm-zhao', 'm-wg', 'm-chap', 'm-admin'])
        try { localStorage.setItem(`onboarding_v1_${mid}`, JSON.stringify({ questId: '', step: 0, status: 'skipped', baseline: {} })); } catch { /* ignore */ }
    });
  });

  test('M1: strbar renders dual-track totals + three boards', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    await expect(page.locator('.strbar')).toContainText('Nominal (in pool)');
    await expect(page.locator('.strbar')).toContainText('Settled');
    await expect(page.locator('.lbrow')).toHaveCount(3);
    // real seeded numbers: Chen Wei 34h → 340 nominal; settled balance 120
    await expect(page.locator('.strbar')).toContainText('Chen Wei');
    expect(errs()).toEqual([]);
  });

  test('M2: assign a member into the first-author seat → persists', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const row = page.locator('.prow', { hasText: 'ml-Tagging' });
    await row.locator('> summary').click();
    const lead = row.locator('details.seat', { hasText: 'First author' });
    await lead.locator('> summary').click();
    // OpenReview/Notion-style search pick instead of the radio quick-pick
    await lead.locator('.ppick input').fill('fang');
    await lead.locator('.pp-row', { hasText: 'Wang Fang' }).click();
    await lead.locator('input[type=number]').fill('10');
    await lead.getByRole('button', { name: 'Assign' }).click();
    const seated = row.locator('.seat', { has: page.locator('.an', { hasText: 'Wang Fang' }) });
    await expect(seated).toContainText('100 STR');
    await page.reload();
    await dismissQuest(page);
    const row2 = page.locator('.prow', { hasText: 'ml-Tagging' });
    await row2.locator('> summary').click();
    await expect(row2.locator('.seat', { has: page.locator('.an', { hasText: 'Wang Fang' }) })).toBeVisible();
    // leader seat filled → the open first-author row is gone
    await expect(row2.locator('details.seat', { hasText: 'Lead · open' })).toHaveCount(0);
    // U of CRUD: edit the seated hours inline → nominal STR recomputes
    const seat2 = row2.locator('.seat', { has: page.locator('.an', { hasText: 'Wang Fang' }) });
    await seat2.locator('.ghours').fill('8');
    await seat2.locator('.ghours').blur();
    await expect(row2.locator('.seat', { has: page.locator('.an', { hasText: 'Wang Fang' }) })).toContainText('80 STR');
    // D: remove the seated member → the first-author seat reopens
    await row2.locator('.seat', { has: page.locator('.an', { hasText: 'Wang Fang' }) }).locator('.rel').click({ force: true });
    await expect(row2.locator('details.seat', { hasText: 'First author' })).toBeVisible();
    expect(errs()).toEqual([]);
  });

  test('M3: add an opening with an author role (forge_need)', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    // ml-Tagging is stage Active in the seed — the hire box shows directly
    const row = page.locator('.prow', { hasText: 'ml-Tagging' });
    await row.locator('> summary').click();
    const hire = row.locator('details.hire');
    await hire.locator('> summary').click();
    await hire.locator('select').first().selectOption('corresponding');
    await hire.locator('input[type=number]').fill('6');
    await hire.getByRole('button', { name: 'Add' }).click();
    await expect(row.locator('.seat', { hasText: 'Co-corresponding' })).toBeVisible();
    await page.reload();
    await dismissQuest(page);
    const row3 = page.locator('.prow', { hasText: 'ml-Tagging' });
    await ensureOpen(row3);
    await expect(row3.locator('.seat', { hasText: 'Co-corresponding' })).toBeVisible();
    // D: close the opening
    await row3.locator('details.seat', { hasText: 'Co-corresponding' }).locator('.rel').click({ force: true });
    await expect(row3.locator('.seat', { hasText: 'Co-corresponding' })).toHaveCount(0);
    expect(errs()).toEqual([]);
  });

  test('M4: member row — edit hours, then remove with confirm', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const mrow = page.locator('.p', { has: page.locator('.pname', { hasText: 'Zhao Lei' }) }).first();
    await mrow.locator('> summary').click();
    await mrow.locator('.pf label', { hasText: 'Monthly' }).locator('input').fill('12');
    await mrow.locator('.pf label', { hasText: 'Monthly' }).locator('input').blur();
    await page.reload();
    await dismissQuest(page);
    const mrow2 = page.locator('.p', { has: page.locator('.pname', { hasText: 'Zhao Lei' }) }).first();
    await mrow2.locator('> summary').click();
    await expect(mrow2.locator('.pf label', { hasText: 'Monthly' }).locator('input')).toHaveValue('12');
    // remove (recoverable): inline dz confirm + app confirm dialog
    await mrow2.locator('.dz > summary').click();
    await mrow2.locator('.dz').getByRole('button', { name: 'Confirm' }).click();
    await expect(page.locator('.p', { has: page.locator('.pname', { hasText: 'Zhao Lei' }) })).toHaveCount(0);
    expect(errs()).toEqual([]);
  });

  test('M5: plain member can act too (v0.3 permissions suspended)', async ({ page }) => {
    await asRole(page, 'uid-member'); // Li Hua — no officer role
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const row = page.locator('.prow', { hasText: 'ml-Tagging' });
    await row.locator('> summary').click();
    const lead = row.locator('details.seat', { hasText: 'First author' });
    await lead.locator('> summary').click();
    await lead.locator('.cd', { hasText: 'Wang Fang' }).locator('input[type=radio]').check();
    await lead.getByRole('button', { name: 'Assign' }).click();
    await expect(row.locator('.seat', { has: page.locator('.an', { hasText: 'Wang Fang' }) })).toBeVisible();
    expect(errs()).toEqual([]);
  });

  test('M6: orphan account row links to an unlinked member', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const orow = page.locator('.p.orphan', { hasText: 'orphan@' });
    await orow.locator('> summary').click();
    await orow.locator('.ppick input').fill('wang');
    await orow.locator('.pp-row', { hasText: 'Wang Fang' }).click();
    await orow.getByRole('button', { name: 'Link' }).click();
    await expect(page.locator('.p.orphan')).toHaveCount(0);
    await page.reload();
    await dismissQuest(page);
    await expect(page.locator('.p.orphan')).toHaveCount(0);
    // Wang Fang now shows the linked dot
    const wrow = page.locator('.p', { hasText: 'Wang Fang' }).first();
    await expect(wrow.locator('.regd.on')).toBeVisible();
    expect(errs()).toEqual([]);
  });

  test('M9: member skills & resources are full CRUD', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const wrow = page.locator('.p', { has: page.locator('.pname', { hasText: 'Wang Fang' }) }).first();
    await wrow.locator('> summary').click();
    // U: edit the GPU resource quota inline
    await wrow.locator('.chip.rs .ghours').fill('150');
    await wrow.locator('.chip.rs .ghours').blur();
    await expect(wrow.locator('.chip.rs .ghours')).toHaveValue('150');
    // U2: change a skill's level inline on its chip
    await wrow.locator('.chip', { hasText: 'Annotation' }).locator('.lvlsel').selectOption('learning');
    await expect(wrow.locator('.chip', { hasText: 'Annotation' }).locator('.lvlsel')).toHaveValue('learning');
    // D: delete the Annotation skill chip
    await wrow.locator('.chip', { hasText: 'Annotation' }).locator('.chipx').click({ force: true });
    await expect(wrow.locator('.chip', { hasText: 'Annotation' })).toHaveCount(0);
    // C: add a skill via the collapsed adder
    await wrow.locator('details.sub2', { hasText: 'Add skill / resource' }).locator('> summary').click();
    const skRow = wrow.locator('.addrow').nth(0);
    await skRow.locator('select').first().selectOption({ label: 'Writing' });
    await skRow.getByRole('button', { name: 'Add' }).click();
    await expect(wrow.locator('.chip', { hasText: 'Writing' })).toBeVisible();
    // C: add another resource via the collapsed adder
    if (!(await wrow.locator('.addrow').nth(1).isVisible())) await wrow.locator('details.sub2', { hasText: 'Add skill / resource' }).locator('> summary').click();
    const resRow = wrow.locator('.addrow').nth(1);
    await resRow.locator('select').first().selectOption({ index: 1 });
    await resRow.locator('input[type=number]').fill('50');
    await resRow.getByRole('button', { name: 'Add' }).click();
    await expect(wrow.locator('.chip.rs')).toHaveCount(2);
    await page.reload();
    await dismissQuest(page);
    const wrow2 = page.locator('.p', { has: page.locator('.pname', { hasText: 'Wang Fang' }) }).first();
    await wrow2.locator('> summary').click();
    await expect(wrow2.locator('.chip.rs')).toHaveCount(2);
    await expect(wrow2.locator('.chip', { hasText: 'Annotation' })).toHaveCount(0);
    expect(errs()).toEqual([]);
  });

  test('M10: project edit — rename + change venue shows on the row', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const row = page.locator('.prow', { hasText: 'ml-Tagging' });
    await row.locator('> summary').click();
    const edit = row.locator('details.sub2', { hasText: 'Edit' });
    await edit.locator('> summary').click();
    await edit.locator('label', { hasText: 'Name' }).locator('input').fill('ml-Tagging-v2');
    await edit.locator('label', { hasText: 'Venue' }).locator('select').selectOption({ label: 'ARR' });
    await edit.getByRole('button', { name: 'Save' }).click();
    const row2 = page.locator('.prow', { hasText: 'ml-Tagging-v2' });
    await expect(row2.locator('> summary .ddl')).toContainText('ARR');
    await page.reload();
    await dismissQuest(page);
    const row3 = page.locator('.prow', { hasText: 'ml-Tagging-v2' });
    await expect(row3).toBeVisible();
    await expect(row3.locator('> summary .ddl')).toContainText('ARR');
    // U: transfer the project to another working group
    await ensureOpen(row3);
    const edit3 = row3.locator('details.sub2', { hasText: 'Edit' });
    await edit3.locator('> summary').click();
    await edit3.locator('label', { hasText: 'Group' }).locator('select').selectOption({ label: 'Proposal (no group)' });
    await edit3.getByRole('button', { name: 'Save' }).click();
    const row4 = page.locator('.prow', { hasText: 'ml-Tagging-v2' });
    await expect(row4.locator('> summary .unitc2')).toContainText('Proposal');
    expect(errs()).toEqual([]);
  });

  test('M11: stage dropdown goes backward and to Hold, persists', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const row = page.locator('.prow', { hasText: 'ml-Tagging' });
    await row.locator('> summary').click();
    const sel = row.locator('.stsel select').first();
    await sel.selectOption({ label: 'Hold' });
    await expect(page.locator('.prow.st-dorm', { hasText: 'ml-Tagging' })).toBeVisible();
    // backward: Hold → Proposal (a reversal, not just forward)
    const row2 = page.locator('.prow', { hasText: 'ml-Tagging' });
    await ensureOpen(row2);
    await row2.locator('.stsel select').first().selectOption({ label: 'Proposal' });
    await expect(page.locator('.prow.st-seed', { hasText: 'ml-Tagging' })).toBeVisible();
    await page.reload();
    await dismissQuest(page);
    await expect(page.locator('.prow.st-seed', { hasText: 'ml-Tagging' })).toBeVisible();
    expect(errs()).toEqual([]);
  });

  test('M12: review sets a result date; Finished locks with the outcome chip', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const row = page.locator('.prow', { hasText: 'ml-Tagging' });
    await row.locator('> summary').click();
    await row.locator('.stsel select').first().selectOption({ label: 'Under review' });
    const row2 = page.locator('.prow', { hasText: 'ml-Tagging' });
    await ensureOpen(row2);
    await row2.locator('input[type=date]').fill('2027-01-15');
    await row2.locator('input[type=date]').blur();
    await expect(row2.locator('> summary .ddl')).toContainText('result in');
    await ensureOpen(row2);
    await row2.locator('.stsel select').first().selectOption({ label: 'Finished' });
    // Finished rows live only in the Accepted pool now
    await page.locator('.arcpool > summary').click();
    const row3 = page.locator('.prow', { hasText: 'ml-Tagging' });
    await ensureOpen(row3);
    // U: type the outcome once → green locked chip, edit menu hidden
    await row3.locator('input[placeholder="main / findings"]').fill('main');
    await row3.locator('input[placeholder="main / findings"]').blur();
    const row4 = page.locator('.prow', { hasText: 'ml-Tagging' });
    await expect(row4.locator('> summary .ddl.acc')).toContainText('main');
    await ensureOpen(row4);
    await expect(row4.locator('details.sub2', { hasText: 'Edit' })).toHaveCount(0);
    await expect(row4.locator('input[placeholder="main / findings"]')).toHaveCount(0);
    expect(errs()).toEqual([]);
  });

  test('M13: Finished archives into the Accepted pool and restores', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const row = page.locator('.prow', { hasText: 'ml-Tagging' });
    await row.locator('> summary').click();
    await row.locator('.stsel select').first().selectOption({ label: 'Finished' });
    const pool = page.locator('.arcpool');
    await pool.locator('> summary').click();
    const row2 = pool.locator('.prow', { hasText: 'ml-Tagging' });
    await ensureOpen(row2);
    await row2.getByRole('button', { name: 'Archive' }).click();
    await expect(pool.locator('.arow', { hasText: 'ml-Tagging' })).toBeVisible();
    await expect(page.locator('.prow', { hasText: 'ml-Tagging' })).toHaveCount(0);
    await page.reload();
    await dismissQuest(page);
    const pool2 = page.locator('.arcpool');
    await pool2.locator('> summary').click();
    await pool2.locator('.arow', { hasText: 'ml-Tagging' }).getByRole('button', { name: 'Restore' }).click();
    await expect(page.locator('.prow', { hasText: 'ml-Tagging' })).toBeVisible();
    expect(errs()).toEqual([]);
  });

  test('M14: + New creates a working group and a chapter, usable at once', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    await page.locator('.newmenu > summary').click();
    const wgBox = page.locator('.newmenu .sub2', { hasText: 'Working group' });
    await wgBox.locator('> summary').click();
    await wgBox.locator('input').fill('mk-NewWG');
    await wgBox.getByRole('button', { name: 'Create' }).click();
    // the new WG is immediately offered when creating a project
    await page.locator('.newmenu > summary').click({ force: true });
    const pBox = page.locator('.newmenu .sub2', { hasText: 'Project' }).first();
    await pBox.locator('> summary').click({ force: true });
    await expect(pBox.locator('select option', { hasText: 'mk-NewWG' })).toHaveCount(1);
    // chapter
    await page.locator('.newmenu > summary').click({ force: true });
    const chBox = page.locator('.newmenu .sub2', { hasText: 'Chapter' });
    await chBox.locator('> summary').click({ force: true });
    await chBox.locator('input').fill('mk-NewChapter');
    await chBox.getByRole('button', { name: 'Create' }).click();
    const addBox = page.locator('.newbox');
    await addBox.locator('> summary').click();
    await expect(addBox.locator('select option', { hasText: 'mk-NewChapter' })).toHaveCount(1);
    await page.reload();
    await dismissQuest(page);
    const addBox2 = page.locator('.newbox');
    await addBox2.locator('> summary').click();
    await expect(addBox2.locator('select option', { hasText: 'mk-NewChapter' })).toHaveCount(1);
    expect(errs()).toEqual([]);
  });

  test('M15: add a member card, then move them to a new chapter', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    // C: + Member creates a card (no email is sent)
    const addBox = page.locator('.newbox');
    await addBox.locator('> summary').click();
    await addBox.locator('input').first().fill('Xu Lan');
    await addBox.locator('input').nth(1).fill('xu@test');
    await addBox.getByRole('button', { name: 'Add' }).click();
    await expect(page.locator('.p', { has: page.locator('.pname', { hasText: 'Xu Lan' }) })).toBeVisible();
    // U: create a chapter and move the member there
    await page.locator('.newmenu > summary').click({ force: true });
    const chBox = page.locator('.newmenu .sub2', { hasText: 'Chapter' });
    await chBox.locator('> summary').click({ force: true });
    await chBox.locator('input').fill('mk-Chapter2');
    await chBox.getByRole('button', { name: 'Create' }).click();
    const mrow = page.locator('.p', { has: page.locator('.pname', { hasText: 'Xu Lan' }) }).first();
    await mrow.locator('> summary').click();
    await mrow.locator('.pf label', { hasText: 'Chapter' }).locator('select').selectOption({ label: 'mk-Chapter2' });
    await expect(page.locator('.sh', { hasText: 'mk-Chapter2' })).toBeVisible();
    await page.reload();
    await dismissQuest(page);
    await expect(page.locator('.sh', { hasText: 'mk-Chapter2' })).toBeVisible();
    expect(errs()).toEqual([]);
  });

  test('M16: create a venue; it is immediately offered in project editing', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    await page.locator('.newmenu > summary').click({ force: true });
    const vBox = page.locator('.newmenu .sub2', { hasText: 'New venue' });
    await vBox.locator('> summary').click({ force: true });
    await vBox.locator('input').first().fill('EMNLP');
    await vBox.locator('input[type=date]').fill('2027-05-20');
    await vBox.getByRole('button', { name: 'Create' }).click();
    const row = page.locator('.prow', { hasText: 'ml-Tagging' });
    await row.locator('> summary').click();
    const edit = row.locator('details.sub2', { hasText: 'Edit' });
    await edit.locator('> summary').click();
    await edit.locator('label', { hasText: 'Venue' }).locator('select').selectOption({ label: 'EMNLP 2027' });
    await edit.getByRole('button', { name: 'Save' }).click();
    await expect(page.locator('.prow', { hasText: 'ml-Tagging' }).locator('> summary .ddl')).toContainText('EMNLP 2027');
    await page.reload();
    await dismissQuest(page);
    await expect(page.locator('.prow', { hasText: 'ml-Tagging' }).locator('> summary .ddl')).toContainText('EMNLP 2027');
    expect(errs()).toEqual([]);
  });

  test('M17: a removed member lands in the Removed pool and restores', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const mrow = page.locator('.p', { has: page.locator('.pname', { hasText: 'Zhao Lei' }) }).first();
    await mrow.locator('> summary').click();
    await mrow.locator('.dz > summary').click();
    await mrow.locator('.dz').getByRole('button', { name: 'Confirm' }).click();
    await expect(page.locator('.p', { has: page.locator('.pname', { hasText: 'Zhao Lei' }) })).toHaveCount(0);
    const pool = page.locator('.arcpool', { hasText: 'Removed' });
    await pool.locator('> summary').click();
    await expect(pool.locator('.arow', { hasText: 'Zhao Lei' })).toBeVisible();
    await page.reload();
    await dismissQuest(page);
    const pool2 = page.locator('.arcpool', { hasText: 'Removed' });
    await pool2.locator('> summary').click();
    await pool2.locator('.arow', { hasText: 'Zhao Lei' }).getByRole('button', { name: 'Restore' }).click();
    await expect(page.locator('.p', { has: page.locator('.pname', { hasText: 'Zhao Lei' }) }).first()).toBeVisible();
    expect(errs()).toEqual([]);
  });

  test('M8: no component overflows its container (all rows expanded)', async ({ page }) => {
    await page.goto('/market');
    await dismissQuest(page);
    await page.locator('.prow').first().waitFor();
    const bad = await page.evaluate(() => {
      document.querySelectorAll('details').forEach((d) => (d.open = true));
      const out: string[] = [];
      const vw = document.documentElement.clientWidth;
      if (document.body.scrollWidth > vw + 1) out.push(`body scrolls ${document.body.scrollWidth - vw}px`);
      document.querySelectorAll('.p, .prow, .strbar, .cands').forEach((card) => {
        const cb = card.getBoundingClientRect();
        card.querySelectorAll('*').forEach((el) => {
          const b = el.getBoundingClientRect();
          if (b.width && b.right > cb.right + 2)
            out.push(`${(el.className || el.tagName).toString().slice(0, 30)} overflows ${(card.className || '').toString().slice(0, 20)} by ${Math.round(b.right - cb.right)}px`);
        });
      });
      return [...new Set(out)].slice(0, 10);
    });
    expect(bad).toEqual([]);
  });

  test('M7: + New creates a project (open v0.3) and it appears', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    await page.locator('.newmenu > summary').click();
    const box = page.locator('.newmenu .sub2', { hasText: 'Project' }).first();
    await box.locator('> summary').click();
    await box.locator('input').fill('mk-NewPaper');
    await box.getByRole('button', { name: 'Create' }).click();
    await expect(page.locator('.prow', { hasText: 'mk-NewPaper' })).toBeVisible();
    await page.reload();
    await dismissQuest(page);
    await expect(page.locator('.prow', { hasText: 'mk-NewPaper' })).toBeVisible();
    expect(errs()).toEqual([]);
  });
});
