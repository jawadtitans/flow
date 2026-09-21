import { useState, type FormEvent } from 'react'
import { useMutation } from '@tanstack/react-query'
import { ArrowLeft, ArrowRight, Check, Eye, EyeOff, Loader2, LockKeyhole, ShieldCheck } from 'lucide-react'
import { Link, Navigate, useSearchParams } from 'react-router-dom'
import { api, signIn } from '@/lib/api'
import { useSession } from '@/lib/session'
import { Brand } from '@/components/feedback'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

export function AuthFrame({ children }: { children: React.ReactNode }) { return <div className="grid min-h-screen bg-card lg:grid-cols-[.95fr_1.05fr]">
  <aside className="relative hidden overflow-hidden bg-[#113e34] p-12 text-white lg:flex lg:flex-col xl:p-16"><Brand inverse/><div className="relative z-10 my-auto max-w-md py-20"><span className="mb-6 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-[11px] text-emerald-100"><span className="size-1.5 rounded-full bg-emerald-300"/>A little clarity goes a long way</span><h1 className="text-[48px] font-medium leading-[1.12] tracking-[-.045em] xl:text-[58px]">Good days start<br/>with a little flow.</h1><p className="mt-6 max-w-sm text-[15px] leading-7 text-emerald-50/65">A thoughtful space to care for your community, follow their progress, and keep everything running smoothly.</p><div className="mt-10 flex items-center gap-3 text-xs text-emerald-100/80"><span className="flex size-8 items-center justify-center rounded-full border border-white/15"><ShieldCheck size={16}/></span>Built for the people behind Flow</div></div>
  <svg aria-hidden="true" viewBox="0 0 800 700" className="pointer-events-none absolute -bottom-40 -right-72 w-[850px] text-[#73b396] opacity-[.16]" fill="none">{Array.from({ length: 9 }, (_, i) => <path key={i} d={`M 0 ${350 + i * 27} C 210 ${80 + i * 27}, 280 ${660 + i * 9}, 480 ${330 + i * 22} S 750 ${60 + i * 25}, 840 ${290 + i * 22}`} stroke="currentColor" strokeWidth="1.5"/>)}</svg><p className="relative text-[11px] text-emerald-100/45">Made for everyday progress.</p></aside>
  <main className="relative flex min-h-screen flex-col items-center justify-center px-6 py-12 sm:px-12"><div className="mb-14 lg:hidden"><Brand/></div><div className="w-full max-w-[370px]">{children}</div><p className="mt-12 flex items-center gap-1.5 text-center text-[11px] text-muted-foreground"><LockKeyhole size={12}/>Secure access for authorized Flow staff</p></main>
</div> }

export function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [visible, setVisible] = useState(false)
  const session = useSession(state => state.status)
  const login = useMutation({ mutationFn: () => signIn(email, password) })
  if (session === 'authenticated') return <Navigate to="/" replace/>
  function submit(event: FormEvent) { event.preventDefault(); login.mutate() }
  return <AuthFrame><p className="eyebrow text-primary">Flow operations</p><h2 className="mt-3 text-[32px] font-semibold tracking-[-.04em]">Welcome back.</h2><p className="mt-3 text-sm leading-6 text-muted-foreground">Sign in to your workspace. Let’s see how things are flowing.</p><form className="mt-9 space-y-5" onSubmit={submit}>
    <div className="space-y-2"><label htmlFor="email" className="text-xs font-medium">Email address</label><Input id="email" type="email" autoComplete="username" placeholder="you@flow.app" value={email} onChange={event => setEmail(event.target.value)} required autoFocus/></div>
    <div className="space-y-2"><div className="flex items-center justify-between"><label htmlFor="password" className="text-xs font-medium">Password</label><Link to="/forgot-password" className="text-xs font-medium text-primary hover:underline">Forgot password?</Link></div><div className="relative"><Input id="password" type={visible ? 'text' : 'password'} autoComplete="current-password" placeholder="Enter your password" className="pr-11" value={password} onChange={event => setPassword(event.target.value)} required maxLength={128}/><button type="button" onClick={() => setVisible(!visible)} aria-label={visible ? 'Hide password' : 'Show password'} className="absolute right-1 top-1 rounded p-2.5 text-muted-foreground">{visible ? <EyeOff size={16}/> : <Eye size={16}/>}</button></div></div>
    {login.error && <p role="alert" className="rounded-md border border-rose-100 bg-rose-50 p-3 text-xs leading-5 text-destructive">{login.error.message}</p>}
    <Button type="submit" className="!mt-7 w-full" size="lg" disabled={login.isPending}>{login.isPending ? <><Loader2 className="animate-spin"/>Signing in…</> : <>Sign in to workspace<ArrowRight className="ml-auto"/></>}</Button>
  </form><div className="mt-8 border-t pt-6 text-center"><p className="text-xs leading-6 text-muted-foreground">Need access? Contact your workspace administrator.</p></div></AuthFrame>
}

export function RecoveryPage({ mode }: { mode: 'forgot' | 'reset' | 'verify' }) {
  const [params] = useSearchParams()
  const token = params.get('token') || ''
  const [value, setValue] = useState('')
  const mutation = useMutation({ mutationFn: () => api(mode === 'forgot' ? '/auth/forgot-password' : mode === 'reset' ? '/auth/reset-password' : '/auth/verify-email', { method: 'POST', body: JSON.stringify(mode === 'forgot' ? { email: value } : mode === 'reset' ? { token, password: value } : { token }) }) })
  const titles = { forgot: 'Let’s get you back in.', reset: 'A fresh start.', verify: 'Make it official.' }
  const description = { forgot: 'Enter your email and we’ll send a password reset link if your account is available.', reset: 'Choose a new password with at least eight characters. Your other sessions will be signed out.', verify: 'Confirm this email address for your Flow account.' }
  return <AuthFrame><p className="eyebrow text-primary">Account access</p><h1 className="mt-3 text-[30px] font-semibold tracking-tight">{titles[mode]}</h1><p className="mt-3 text-sm leading-6 text-muted-foreground">{description[mode]}</p>{mutation.isSuccess ? <div role="status" className="my-8 rounded-lg border border-emerald-100 bg-emerald-50 p-5"><Check className="mb-2 size-5 text-primary"/><p className="text-sm">{mode === 'forgot' ? 'If your account is available, check your inbox for the next step.' : mode === 'reset' ? 'Your password has been updated. You can sign in now.' : 'Your email is verified. You’re all set.'}</p></div> : <form className="mt-7 space-y-5" onSubmit={event => { event.preventDefault(); mutation.mutate() }}>{mode !== 'verify' && <div className="space-y-2"><label htmlFor="recovery" className="text-xs font-medium">{mode === 'forgot' ? 'Email address' : 'New password'}</label><Input id="recovery" type={mode === 'forgot' ? 'email' : 'password'} autoComplete={mode === 'forgot' ? 'email' : 'new-password'} value={value} onChange={event => setValue(event.target.value)} required minLength={mode === 'reset' ? 8 : undefined} maxLength={mode === 'reset' ? 128 : undefined}/></div>}{mode !== 'forgot' && !token && <p role="alert" className="text-sm text-destructive">This link is incomplete. Request a new link from your account.</p>}{mutation.error && <p role="alert" className="text-sm text-destructive">{mutation.error.message}</p>}<Button className="w-full" type="submit" disabled={mutation.isPending || (mode !== 'forgot' && !token)}>{mutation.isPending && <Loader2 className="animate-spin"/>}{mode === 'forgot' ? 'Send reset link' : mode === 'reset' ? 'Update password' : 'Verify email'}</Button></form>}<Link to="/login" className="mt-7 inline-flex items-center gap-2 text-xs font-medium text-primary"><ArrowLeft size={14}/>Back to sign in</Link></AuthFrame>
}
