import { useState } from 'react'
import { Activity, ChevronRight, LayoutDashboard, LogOut, Menu, ShieldCheck, Users, X } from 'lucide-react'
import * as Dialog from '@radix-ui/react-dialog'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { useSession } from '@/lib/session'
import { signOut } from '@/lib/api'
import { useHealth } from '@/lib/queries'
import { cn, initials } from '@/lib/utils'
import { Brand, ErrorState } from './feedback'
import { Button } from './ui/button'

const navigation = [{ to: '/', label: 'Overview', icon: LayoutDashboard }, { to: '/users', label: 'Users', icon: Users }, { to: '/system', label: 'System health', icon: Activity }]
function Navigation({ close }: { close?: () => void }) {
  const user = useSession(state => state.user)
  const health = useHealth()
  const logout = useMutation({ mutationFn: signOut })
  const healthy = health.data && ['db', 'redis', 'worker', 'beat'].every(key => health.data[key as 'db'] === 'ok')
  return <div className="flex h-full flex-col px-5 pb-5 pt-8">
    <NavLink to="/" aria-label="Flow operations home" onClick={close} className="ml-2 w-fit"><Brand/></NavLink>
    <div className="mt-10 px-3"><p className="eyebrow">Workspace</p></div>
    <nav aria-label="Main navigation" className="mt-3 space-y-1.5">{navigation.map(({ to, label, icon: Icon }) => <NavLink key={to} to={to} end={to === '/'} onClick={close} className={({ isActive }) => cn('flex items-center gap-3 rounded-lg px-3 py-3 text-[13px] font-medium transition-colors', isActive ? 'bg-[#e7f1ec] text-primary' : 'text-muted-foreground hover:bg-muted hover:text-foreground')}><Icon size={18}/>{label}</NavLink>)}</nav>

    <div className="mt-auto pt-12"><NavLink to="/system" onClick={close} className="mb-5 block rounded-lg border bg-card p-3.5"><div className="flex items-center gap-2 text-xs font-medium"><span className={cn('size-1.5 rounded-full', health.isPending ? 'bg-slate-400' : healthy ? 'bg-emerald-500' : 'bg-amber-500')}/>{health.isPending ? 'Checking services' : healthy ? 'Services are healthy' : 'Services need attention'}<ChevronRight size={13} className="ml-auto text-muted-foreground"/></div><p className="mt-2 text-[11px] text-muted-foreground">Live workspace status</p></NavLink>
      <div className="border-t pt-5"><div className="flex items-center gap-3"><span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-[#eee9df] text-xs font-semibold text-[#6c624f]">{initials(user?.display_name || 'Staff')}</span><div className="min-w-0 flex-1"><p className="truncate text-xs font-semibold">{user?.display_name}</p><p className="mt-1 truncate text-[11px] text-muted-foreground">{user?.email}</p></div><Button variant="ghost" size="icon" aria-label="Sign out" className="size-8" disabled={logout.isPending} onClick={() => logout.mutate()}><LogOut/></Button></div>{logout.error && <p role="alert" className="mt-3 text-xs text-destructive">Sign out failed. Please try again.</p>}</div>
    </div>
  </div>
}
export function Layout() {
  const [open, setOpen] = useState(false)
  const location = useLocation()
  const page = navigation.find(item => item.to === location.pathname)?.label || 'Workspace'
  return <div className="min-h-screen">
    <a href="#main" className="sr-only z-[100] rounded bg-card p-3 focus:not-sr-only focus:fixed focus:left-4 focus:top-4">Skip to content</a>
    <aside className="fixed inset-y-0 left-0 z-30 hidden w-[232px] border-r bg-[#f9faf8] lg:block"><Navigation/></aside>
    <div className="lg:pl-[232px]"><header className="flex h-[76px] items-center justify-between border-b bg-card/75 px-5 sm:px-9"><div className="flex items-center gap-3"><Dialog.Root open={open} onOpenChange={setOpen}><Dialog.Trigger asChild><Button variant="ghost" size="icon" aria-label="Open navigation" className="-ml-2 lg:hidden"><Menu/></Button></Dialog.Trigger><Dialog.Portal><Dialog.Overlay className="fixed inset-0 z-40 bg-black/25"/><Dialog.Content className="fixed inset-y-0 left-0 z-50 w-[280px] bg-background"><Dialog.Title className="sr-only">Workspace navigation</Dialog.Title><Dialog.Description className="sr-only">Navigate Flow operations</Dialog.Description><Navigation close={() => setOpen(false)}/><Dialog.Close className="absolute right-3 top-3 rounded p-2" aria-label="Close navigation"><X size={18}/></Dialog.Close></Dialog.Content></Dialog.Portal></Dialog.Root><span className="hidden text-xs text-muted-foreground sm:block">Workspace</span><ChevronRight className="hidden size-3 text-muted-foreground sm:block"/><span className="text-xs font-medium">{page}</span></div><div className="flex items-center gap-2 text-[11px] text-muted-foreground"><ShieldCheck size={15} className="text-primary"/><span>Staff workspace</span></div></header>
      <main id="main" className="mx-auto max-w-[1600px] px-5 py-8 sm:px-9 sm:py-9" tabIndex={-1}><Outlet/></main>
      <footer className="mx-5 flex flex-wrap items-center justify-between gap-3 border-t py-5 text-[11px] text-muted-foreground sm:mx-9"><span>Flow Operations</span><span>Small steps. Meaningful progress.</span></footer>
    </div>
  </div>
}
export function RootError({ error }: { error: Error }) { return <div className="mx-auto max-w-xl p-8"><Brand/><div className="mt-8"><ErrorState error={error} retry={() => window.location.reload()}/></div></div> }
