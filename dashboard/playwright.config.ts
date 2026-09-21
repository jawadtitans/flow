import { defineConfig, devices } from '@playwright/test'
export default defineConfig({
  testDir: './e2e', fullyParallel: false, workers: 1,
  timeout: 30_000, retries: process.env.CI ? 1 : 0,
  use: { baseURL: process.env.FLOW_DASHBOARD_URL || 'http://localhost:18080', trace: 'retain-on-failure', screenshot: 'only-on-failure', launchOptions: process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : undefined },
  projects: [{ name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 1000 } } }, { name: 'mobile', use: { ...devices['iPhone 13'], defaultBrowserType: 'chromium' } }],
})
