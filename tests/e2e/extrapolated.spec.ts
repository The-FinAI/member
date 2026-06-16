import { test, type Page, type Locator } from '@playwright/test';
import { asRole, trackErrors, expect } from './helpers';

// =====================================================================
// EXTRAPOLATED — not issues she filed, but the next ones she'd file, by applying
// her demonstrated reasoning to surfaces she hasn't tested yet:
//   P1 "does my edit actually persist?"      (from #26/#43)
//   P2 "every create needs an undo/delete"   (from #34)
//   P6 "no silent bad write / clear feedback"(from #20/#31)
// Target: the project TASK BOARD (she stress-tested the member card; the task
// board has the same create/edit/persist/delete shape and was never probed).
// =====================================================================

async function openProjectBody(page: Page) {
  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });
  await page.locator('.tb-addrow, .tb-table').first().waitFor({ state: 'visible' });
}

// a task's name lives in a bound <input value> (not text), so find its row by
// scanning the first cell input of each task row for the value.
async function taskRowByName(page: Page, name: string): Promise<Locator | null> {
  const rows = page.locator('.tb-table tr').filter({ has: page.locator('.tb-x') });
  const n = await rows.count();
  for (let i = 0; i < n; i++) {
    if ((await rows.nth(i).locator('input.cell').first().inputValue()) === name) return rows.nth(i);
  }
  return null;
}

async function addTask(page: Page, name: string) {
  await page.locator('.tb-addrow').first().click();
  await page.locator('.tb-add input.cell').first().fill(name);
  await page.locator('.tb-go').first().click();
  await expect.poll(() => taskRowByName(page, name).then((r) => !!r)).toBe(true);
}

test('P1: adding a task persists on reload (extrapolated from #26/#43)', async ({ page }) => {
  const errs = trackErrors(page);
  await asRole(page, 'uid-admin');
  await openProjectBody(page);

  const name = 'probe task ' + Date.now();
  await addTask(page, name);

  // reload → it must still be there (her core distrust: did it actually save?)
  await openProjectBody(page);
  expect(await taskRowByName(page, name), 'task must persist across reload').not.toBeNull();
  expect(errs(), 'console clean').toEqual([]);
});

test('P2: a created task can be deleted, and stays gone on reload (from #34)', async ({ page }) => {
  await asRole(page, 'uid-admin');
  await openProjectBody(page);

  const name = 'deletable task ' + Date.now();
  await addTask(page, name);

  const row = await taskRowByName(page, name);
  await row!.locator('.tb-x').click();
  await expect.poll(() => taskRowByName(page, name).then((r) => !!r)).toBe(false);

  await openProjectBody(page);
  expect(await taskRowByName(page, name), 'deleted task stays gone').toBeNull();
});

test('P6: an empty task name cannot be added (no silent bad write) (from #20/#31)', async ({ page }) => {
  await asRole(page, 'uid-admin');
  await openProjectBody(page);

  await page.locator('.tb-addrow').first().click();
  await expect(page.locator('.tb-go').first()).toBeDisabled();
});
