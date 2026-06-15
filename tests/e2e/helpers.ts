import { type Page, expect } from '@playwright/test';

// Drive the app as a specific mock persona. mockAs is read from localStorage
// before the app boots, so we set it via an init script (runs on every nav).
//   uid-chap  = Chan Min   (chapter officer of the Beijing chapter)
//   uid-member= Li Hua     (a plain member, no officer role)
//   uid-admin = Sai Tan    (President / admin)
//   uid-wg    = Wu Jing    (working-group officer)
export async function asRole(page: Page, role: string) {
  await page.addInitScript((r) => {
    try { localStorage.setItem('mockAs', r); } catch { /* ignore */ }
  }, role);
}

// Collect console errors + uncaught page errors for the Definition-of-Done
// "console clean" assertion. Returns a getter; benign noise can be filtered.
export function trackErrors(page: Page) {
  const errors: string[] = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e?.message ?? e)));
  return () => errors.filter((e) => !/favicon|net::ERR|Failed to load resource/i.test(e));
}

// The member detail page is tabbed (SectionNav shows only the active section).
// A real user clicks the "Skills" tab to reach skills & available time — so the
// journey must too, or the controls are display:none.
export async function openSkillsTab(page: Page) {
  const tab = page.locator('.detail-nav a[href="#skills"]');
  await tab.waitFor({ state: 'visible' });
  await tab.click();
  await page.locator('.sc-cap').first().waitFor({ state: 'visible' });
}

export { expect };
