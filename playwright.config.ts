import { defineConfig, devices } from '@playwright/test';

// Real-user tests run against the app in MOCK mode (the same seeded world the
// preview uses), so they exercise the real rendered UI end-to-end without a
// backend. Each test follows the Definition of Done: real role · real surface ·
// interact → control appears → reload → persisted → console clean.
export default defineConfig({
  testDir: './tests/e2e',
  timeout: 30_000,
  expect: { timeout: 7_000 },
  fullyParallel: false,
  reporter: [['list']],
  use: {
    baseURL: 'http://127.0.0.1:5183',
    headless: true,
    ...devices['Desktop Chrome']
  },
  webServer: {
    // Keep the test backend explicit so a clean clone does not depend on an
    // ignored .env.mock file being present on the developer's machine.
    command: 'npx vite dev --host 127.0.0.1 --port 5183 --mode mock',
    env: { PUBLIC_MOCK: '1' },
    url: 'http://127.0.0.1:5183',
    reuseExistingServer: !process.env.CI,
    timeout: 60_000
  }
});
