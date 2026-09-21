import { Component, Suspense, lazy, type ReactNode } from 'react'
import { QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Navigate, Outlet, Route, Routes } from 'react-router-dom'
import { Loader2 } from 'lucide-react'
import { queryClient } from './lib/api'
import { useSession } from './lib/session'
import { Layout, RootError } from './components/layout'
import { LoginPage, RecoveryPage } from './pages/login'
import { Brand } from './components/feedback'

const OverviewPage = lazy(() => import('./pages/overview').then(module => ({ default: module.OverviewPage })))
const UsersPage = lazy(() => import('./pages/users').then(module => ({ default: module.UsersPage })))
const SystemPage = lazy(() => import('./pages/system').then(module => ({ default: module.SystemPage })))
class ErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null }
  static getDerivedStateFromError(error: Error) { return { error } }
  render() { return this.state.error ? <RootError error={this.state.error}/> : this.props.children }
}
function RequireStaff() {
  const { status, user } = useSession()
  if (status === 'loading') return <div role="status" className="flex min-h-screen flex-col items-center justify-center gap-6"><Brand/><Loader2 className="size-5 animate-spin text-primary"/><span className="text-xs text-muted-foreground">Opening your workspace…</span></div>
  return status === 'authenticated' && user?.is_staff ? <Outlet/> : <Navigate to="/login" replace/>
}
export function AppRoutes() { return <Suspense fallback={<div role="status" className="p-12 text-sm text-muted-foreground">Loading your workspace…</div>}><Routes><Route path="/login" element={<LoginPage/>}/><Route path="/forgot-password" element={<RecoveryPage key="forgot" mode="forgot"/>}/><Route path="/reset-password" element={<RecoveryPage key="reset" mode="reset"/>}/><Route path="/verify-email" element={<RecoveryPage key="verify" mode="verify"/>}/><Route element={<RequireStaff/>}><Route element={<Layout/>}><Route index element={<OverviewPage/>}/><Route path="users" element={<UsersPage/>}/><Route path="system" element={<SystemPage/>}/></Route></Route><Route path="*" element={<Navigate to="/" replace/>}/></Routes></Suspense> }
export function App() { return <ErrorBoundary><QueryClientProvider client={queryClient}><BrowserRouter><AppRoutes/></BrowserRouter></QueryClientProvider></ErrorBoundary> }
