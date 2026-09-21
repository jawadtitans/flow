import { test, expect } from '@playwright/test'
const email = process.env.FLOW_E2E_EMAIL
const password = process.env.FLOW_E2E_PASSWORD

test('staff can navigate real operations data and retain a secure session', async ({ page }, testInfo) => {
  test.skip(!email || !password, 'Set FLOW_E2E_EMAIL and FLOW_E2E_PASSWORD for a staff account on the isolated stack.')
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  await page.goto('/login')
  await page.getByLabel('Email address').fill(email!)
  await page.getByLabel('Password', { exact: true }).fill(password!)
  await page.getByRole('button', { name: 'Sign in to workspace' }).click()
  await expect(page.getByRole('heading', { name: 'Workspace overview' })).toBeVisible()
  await expect(page.getByText('Total users', { exact: true })).toBeVisible()
  await page.reload()
  await expect(page.getByRole('heading', { name: 'Workspace overview' })).toBeVisible()
  expect(await page.evaluate(() => localStorage.length)).toBe(0)
  const cookies = await page.context().cookies()
  expect(cookies.find(cookie => cookie.name === 'flow_refresh')?.httpOnly).toBe(true)
  await page.screenshot({ path: `test-results/overview-${testInfo.project.name}.png`, fullPage: true })
  if (testInfo.project.name === 'mobile') await page.getByRole('button', { name: 'Open navigation' }).click()
  await page.getByRole('link', { name: 'Users', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'People at Flow' })).toBeVisible()
  await page.getByRole('textbox', { name: 'Search users by name or email' }).fill(email!)
  await expect(page.getByRole('table').getByText(email!, { exact: true })).toBeVisible()
  await page.screenshot({ path: `test-results/users-${testInfo.project.name}.png`, fullPage: true })
  if (testInfo.project.name === 'mobile') await page.getByRole('button', { name: 'Open navigation' }).click()
  await page.getByRole('link', { name: 'System health', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Keeping Flow in flow.' })).toBeVisible()
  await expect(page.getByText('Database', { exact: true })).toBeVisible()
  await page.screenshot({ path: `test-results/system-${testInfo.project.name}.png`, fullPage: true })
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
  expect(errors).toEqual([])
})
