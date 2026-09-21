import { render, screen } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { expect, it, vi } from 'vitest'
import { OverviewPage } from '@/pages/overview'
function renderOverview() { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}><MemoryRouter><OverviewPage/></MemoryRouter></QueryClientProvider>) }
it('renders server KPIs and a real empty-user state', async () => {
  vi.stubGlobal('fetch', vi.fn(async (url: string) => new Response(JSON.stringify(url.includes('overview') ? { total_users: 1234, active_users_7d: 78, tasks_created_today: 22, tasks_completed_today: 14, routines_run_today: 6, date: '2026-09-20', timezone: 'Asia/Kabul' } : url.includes('activity') ? [{ date: '2026-09-20', tasks_created: 22, tasks_completed: 14, routines_completed: 6, users_joined: 0 }] : { items: [], total: 0, limit: 5, offset: 0 }), { status: 200 })))
  renderOverview()
  expect(await screen.findByText('1,234')).toBeInTheDocument()
  expect(screen.getByText('78')).toBeInTheDocument()
  expect(await screen.findByText('Your community starts here')).toBeInTheDocument()
  expect(screen.queryByText('FLOW-101')).not.toBeInTheDocument()
})
it('shows retry controls for a failed request', async () => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ detail: 'Service is unavailable' }), { status: 503 })))
  renderOverview()
  expect((await screen.findAllByRole('alert')).length).toBeGreaterThan(0)
  expect(screen.getAllByRole('button', { name: 'Try again' }).length).toBeGreaterThan(0)
})
