import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { LoginPage } from '@/pages/login'
import { useSession } from '@/lib/session'
function renderLogin() { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { mutations: { retry: false } } })}><MemoryRouter initialEntries={['/login']}><Routes><Route path="/login" element={<LoginPage/>}/><Route path="/" element={<div>Workspace loaded</div>}/></Routes></MemoryRouter></QueryClientProvider>) }
beforeEach(() => useSession.getState().clear())
describe('Staff login', () => {
  it('signs in using cookie mode and opens the workspace', async () => {
    const fetch = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({ access_token: 'access' }), { status: 200 })).mockResolvedValueOnce(new Response(JSON.stringify({ id: 'staff', display_name: 'Staff', email: 'staff@example.com', is_staff: true }), { status: 200 }))
    vi.stubGlobal('fetch', fetch)
    renderLogin(); const user = userEvent.setup()
    await user.type(screen.getByLabelText('Email address'), 'staff@example.com'); await user.type(screen.getByLabelText('Password'), 'correct-password'); await user.click(screen.getByRole('button', { name: /Sign in to workspace/i }))
    expect(await screen.findByText('Workspace loaded')).toBeInTheDocument()
    expect(fetch.mock.calls[0][0]).toBe('/api/v1/auth/login?client=browser')
    expect(localStorage.length).toBe(0)
  })
  it('shows a useful server error without entering the workspace', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ detail: 'Staff access required' }), { status: 403 })))
    renderLogin(); const user = userEvent.setup()
    await user.type(screen.getByLabelText('Email address'), 'user@example.com'); await user.type(screen.getByLabelText('Password'), 'password'); await user.click(screen.getByRole('button', { name: /Sign in to workspace/i }))
    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('Staff access required'))
    expect(useSession.getState().status).toBe('anonymous')
  })
})
