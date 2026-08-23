import { test } from '@playwright/test';
import { asRole, trackErrors, dismissQuest, expect } from './helpers';

// 市场 Market (v49 落地, governance v0.3 无权限期) — Definition of Done:
// real role · real surface · interact → control appears → reload → persisted ·
// console clean. Settlement/minting stay President-gated and are NOT here.

test.describe('market — officer single page', () => {
  test.beforeEach(async ({ page }) => {
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
    await lead.locator('.cd', { hasText: 'Wang Fang' }).locator('input[type=radio]').check();
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
    if (!(await row3.locator('.pbody').isVisible())) await row3.locator('> summary').click();
    await expect(row3.locator('.seat', { hasText: 'Co-corresponding' })).toBeVisible();
    expect(errs()).toEqual([]);
  });

  test('M4: member row — edit hours, then remove with confirm', async ({ page }) => {
    const errs = trackErrors(page);
    await page.goto('/market');
    await dismissQuest(page);
    const mrow = page.locator('.p', { has: page.locator('.pname', { hasText: 'Zhao Lei' }) }).first();
    await mrow.locator('> summary').click();
    await mrow.locator('.pf input[type=number]').fill('12');
    await mrow.getByRole('button', { name: 'Save' }).click();
    await page.reload();
    await dismissQuest(page);
    const mrow2 = page.locator('.p', { has: page.locator('.pname', { hasText: 'Zhao Lei' }) }).first();
    await mrow2.locator('> summary').click();
    await expect(mrow2.locator('.pf input[type=number]')).toHaveValue('12');
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
    const orow = page.locator('.p.orphan', { hasText: 'orphan@test' });
    await orow.locator('> summary').click();
    await orow.locator('select').selectOption({ label: 'Wang Fang' });
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
