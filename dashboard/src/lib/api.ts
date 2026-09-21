import { QueryClient } from '@tanstack/react-query'
import { useSession } from './session'
import type { User } from './types'

export class ApiError extends Error { constructor(public status: number, message: string, public requestId?: string) { super(message) } }
export const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 30_000, retry: (count, error) => count < 1 && !(error instanceof ApiError && [401, 403, 429].includes(error.status)), refetchOnWindowFocus: true } } })
const csrf = () => document.cookie.split('; ').find(item => item.startsWith('flow_csrf='))?.split('=').slice(1).join('=') || ''
let refreshing: Promise<string> | null = null
async function refreshRequest() {
  const response = await fetch('/api/v1/auth/refresh?client=browser', { method: 'POST', credentials: 'include', headers: { 'X-Flow-CSRF': csrf() } })
  if (!response.ok) { useSession.getState().clear(); queryClient.clear(); throw new ApiError(response.status, 'Your session has ended. Please sign in again.') }
  const tokens = await response.json()
  useSession.getState().setToken(tokens.access_token)
  return tokens.access_token as string
}
export function refreshAccess() {
  if (!refreshing) {
    refreshing = (navigator.locks ? navigator.locks.request('flow-session-refresh', refreshRequest) : refreshRequest()).finally(() => { refreshing = null })
  }
  return refreshing
}
export async function api<T>(path: string, options: RequestInit = {}, retry = true): Promise<T> {
  const token = useSession.getState().token
  const headers = new Headers(options.headers)
  if (options.body) headers.set('Content-Type', 'application/json')
  if (token) headers.set('Authorization', `Bearer ${token}`)
  headers.set('X-Flow-CSRF', csrf())
  const response = await fetch(`/api/v1${path}`, { ...options, headers, credentials: 'include' })
  if (response.status === 401 && retry && !path.startsWith('/auth/login') && !path.startsWith('/auth/refresh')) { await refreshAccess(); return api<T>(path, options, false) }
  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    const message = typeof data.detail === 'string' ? data.detail : response.status === 422 ? 'Please check the details and try again.' : 'We couldn’t load this information. Please try again.'
    throw new ApiError(response.status, message, response.headers.get('x-request-id') || undefined)
  }
  return response.status === 204 ? undefined as T : response.json()
}
export async function signIn(email: string, password: string) {
  const tokens = await api<{ access_token: string }>('/auth/login?client=browser', { method: 'POST', body: JSON.stringify({ email, password }) }, false)
  useSession.getState().setToken(tokens.access_token)
  const user = await api<User>('/me')
  if (!user.is_staff) { useSession.getState().clear(); throw new ApiError(403, 'This workspace is for Flow staff.') }
  useSession.getState().setUser(user)
}
export async function bootstrap() {
  if (!csrf()) { useSession.getState().clear(); return }
  try { await refreshAccess(); const user = await api<User>('/me'); if (!user.is_staff) throw new Error('Staff access required'); useSession.getState().setUser(user) } catch { useSession.getState().clear() }
}
export async function signOut() {
  await api('/auth/logout?client=browser', { method: 'POST' })
  useSession.getState().clear(); queryClient.clear()
  if ('BroadcastChannel' in window) { const channel = new BroadcastChannel('flow-session'); channel.postMessage('logout'); channel.close() }
}
