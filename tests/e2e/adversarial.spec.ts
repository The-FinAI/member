import { test } from '@playwright/test';
import { asRole, openSkillsTab, expect } from './helpers';

// =====================================================================
// ADVERSARIAL — a LOW-compliance, LOW-goal-direction user (like the real tester):
// doesn't follow the happy path, distrusts the UI, types junk, deviates. This is
// where her bugs come from — the compliant goal-directed persona never hits them.
// =====================================================================

// A1 — she types junk into a numeric field (it's now a free text input). What
// persists must be a clean number, never the garbage she typed.
test('A1 (junk input): typing "abc" into available time must not persist as text', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/members/m-li');
  await openSkillsTab(page);

  await page.locator('.sc-hours').fill('abc');
  // if a Save even appears, saving must not store "abc"
  if (await page.locator('.sc-save').count()) await page.locator('.sc-save').click();

  await page.goto('/members/m-li');
  await openSkillsTab(page);
  const v = await page.locator('.sc-hours').inputValue();
  expect(v, 'available time must be numeric, never the junk text').toMatch(/^\d*$/);
});

// A2 — negative hours. It must clamp, not store a negative capacity.
test('A2 (negative input): a negative available time must not be stored', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/members/m-li');
  await openSkillsTab(page);

  await page.locator('.sc-hours').fill('-5');
  if (await page.locator('.sc-save').count()) await page.locator('.sc-save').click();

  await page.goto('/members/m-li');
  await openSkillsTab(page);
  const v = await page.locator('.sc-hours').inputValue();
  expect(Number(v), 'available time must not be negative').toBeGreaterThanOrEqual(0);
});

// A3 — the SKEPTIC: she doesn't trust the optimistic toast. After saving she
// navigates fully AWAY (to People) and back IN-APP (no reload) — is it still
// there? (catches reactive staleness the reload-test can miss.)
test('A3 (skeptic): saved hours survive navigating away and back in-app', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/members/m-li');
  await openSkillsTab(page);
  await page.locator('.sc-hours').fill('17');
  await page.locator('.sc-save').click();
  await expect(page.locator('.toast')).toContainText('Saved');

  // leave entirely, then come back by clicking through the roster (not a reload)
  await page.goto('/people');
  await page.getByText('Li Hua').first().click();
  await openSkillsTab(page);
  await expect(page.locator('.sc-hours'), 'value persists across in-app navigation').toHaveValue('17');
});

// A4 — whitespace-only task name (she pastes a stray space). Must not create a
// blank task; the Add control stays disabled.
test('A4 (whitespace): a whitespace-only task name cannot be added', async ({ page }) => {
  await asRole(page, 'uid-admin');
  await page.goto('/projects');
  await page.locator('.lrow-head').first().click();
  await page.locator('.lrow-body').first().waitFor({ state: 'visible' });

  await page.locator('.tb-addrow').first().click();
  await page.locator('.tb-add input.cell').first().fill('   ');
  await expect(page.locator('.tb-go').first(), 'blank/space-only name must not be addable').toBeDisabled();
});

// A5 — the EXPLORER (zero goal-direction): she wants to set someone's available
// time but doesn't know the path. She scans the in-page tabs. None of them says
// "availability / time / capacity" — it's buried under a bare "Skills" tab — so
// she can't find it. (This is exactly her #10/#14/#46 "where / what do I do" class.)
test('A5 (explorer): a tab label should point to where available time lives', async ({ page }) => {
  await asRole(page, 'uid-chap');
  await page.goto('/members/m-li');
  await page.locator('.detail-nav a').first().waitFor({ state: 'visible' });

  const tabs = await page.locator('.detail-nav a').allTextContents();
  const pointsToAvailability = tabs.some((t) => /avail|time|capacity/i.test(t));
  expect(pointsToAvailability, `tabs ${JSON.stringify(tabs)} give no hint where available time is`).toBeTruthy();
});
