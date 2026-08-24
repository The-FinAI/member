import { defineConfig, devices } from '@playwright/test';

// Real-user tests run against the app in MOCK mode (the same seeded world the
// preview uses), so they exercise the real rendered UI end-to-end without a
// backend. Each test follows the Definition of Done: real role · real surface ·
// interact → control appears → reload → persisted → console clean.
export default defineConfig({
  testDir: './tests/e2e',
  timeout: 30_000,
  expect: { timeout: 7_000 },
  fullyParallel: true,
  workers: 4,
  reporter: [['list']],
  use: {
    baseURL: 'http://localhost:5183',
    headless: true,
    ...devices['Desktop Chrome']
  },
  webServer: {
    command: process.env.E2E_DB === '1' ? 'npx vite dev --port 5183' : 'npx vite dev --port 5183 --mode mock',
    port: 5183,
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
    env: process.env.E2E_DB === '1'
      ? { PUBLIC_SUPABASE_URL: process.env.PUBLIC_SUPABASE_URL ?? '', PUBLIC_SUPABASE_ANON_KEY: process.env.PUBLIC_SUPABASE_ANON_KEY ?? '', PUBLIC_MOCK: '' }
      : {}
  }
});
