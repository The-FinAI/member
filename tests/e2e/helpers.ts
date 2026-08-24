import { type Page, expect } from '@playwright/test';
import { execSync } from 'node:child_process';

// Drive the app as a specific mock persona. mockAs is read from localStorage
// before the app boots, so we set it via an init script (runs on every nav).
//   uid-chap  = Chan Min   (chapter officer of the Beijing chapter)
//   uid-member= Li Hua     (a plain member, no officer role)
//   uid-admin = Sai Tan    (President / admin)
//   uid-wg    = Wu Jing    (working-group officer)
const DB = process.env.E2E_DB === '1';
const SB_URL = process.env.PUBLIC_SUPABASE_URL ?? '';
const SB_ANON = process.env.PUBLIC_SUPABASE_ANON_KEY ?? '';
const ROLE_EMAIL: Record<string, string> = {
  'uid-chap': 'chan@e2e.local', 'uid-member': 'li@e2e.local',
  'uid-admin': 'admin@e2e.local', 'uid-wg': 'wu@e2e.local', 'mock-uid': 'chen@e2e.local'
};
// storage key supabase-js derives from the URL host's first label
const sbKey = () => `sb-${new URL(SB_URL).hostname.split('.')[0]}-auth-token`;
async function dbSession(role: string) {
  const r = await fetch(`${SB_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: SB_ANON, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: ROLE_EMAIL[role] ?? ROLE_EMAIL['uid-chap'], password: 'e2e-password' })
  });
  const s = await r.json();
  if (!r.ok) throw new Error(`e2e login failed for ${role}: ${JSON.stringify(s)}`);
  return { ...s, expires_at: Math.floor(Date.now() / 1000) + (s.expires_in ?? 3600) };
}

// Real-DB lane: tests share one database, so each test starts from a fresh
// seed (mock lane resets per browser context for free — this is its analogue).
export function resetDb() {
  if (!DB) return;
  const local = process.env.LOCAL ?? 'postgresql://postgres:postgres@127.0.0.1:5432/postgres';
  execSync(`psql "${local}" -v ON_ERROR_STOP=1 -f supabase/tests/e2e_reset.sql`, { stdio: 'pipe' });
}

export async function asRole(page: Page, role: string) {
  if (DB) {
    const session = await dbSession(role);
    await page.addInitScript(([k, v]) => {
      try { if (!localStorage.getItem(k)) localStorage.setItem(k, v); } catch { /* ignore */ }
    }, [sbKey(), JSON.stringify(session)] as const);
    return;
  }
  // set on every nav, but only if not already set — so a test can switch persona
  // mid-flow via switchRole() without this clobbering it back.
  await page.addInitScript((r) => {
    try { if (!localStorage.getItem('mockAs')) localStorage.setItem('mockAs', r); } catch { /* ignore */ }
  }, role);
}

// switch the acting persona mid-test (e.g. member submits → officer approves)
export async function switchRole(page: Page, role: string) {
  if (DB) {
    const session = await dbSession(role);
    await page.evaluate(([k, v]) => localStorage.setItem(k, v), [sbKey(), JSON.stringify(session)] as const);
    await page.reload();
    return;
  }
  await page.evaluate((r) => localStorage.setItem('mockAs', r), role);
  await page.reload();
}

// Collect console errors + uncaught page errors for the Definition-of-Done
// "console clean" assertion. Returns a getter; benign noise can be filtered.
export function trackErrors(page: Page) {
  const errors: string[] = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e?.message ?? e)));
  return () => errors.filter((e) => !/favicon|net::ERR|Failed to load resource|WebSocket|realtime/i.test(e));
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

// Dismiss the first-run onboarding quest (a returning officer has finished it).
// Tests not about onboarding skip it so its fixed panel can't intercept clicks.
export async function dismissQuest(page: Page) {
  const skip = page.locator('.q-skip');
  try { await skip.click({ timeout: 2000 }); } catch { /* no quest present */ }
}

export { expect };
