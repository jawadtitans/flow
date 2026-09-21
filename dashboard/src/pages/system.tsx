import { useQuery } from '@tanstack/react-query'
import { Activity, Check, CircleAlert, Clock3, Database, Layers, ListTodo, Mail, Radio, RefreshCw, Server, ShieldCheck, Timer, Wifi } from 'lucide-react'
import { useHealth } from '@/lib/queries'
import { cn, number } from '@/lib/utils'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ErrorState } from '@/components/feedback'

export function SystemPage() {
  const health = useHealth()
  const probes = useQuery({ queryKey: ['probes'], refetchInterval: 30_000, queryFn: async () => {
    const results = await Promise.allSettled([fetch('/health'), fetch('/ready')])
    return results.map(result => result.status === 'fulfilled' && result.value.ok)
  } })
  const data = health.data
  const healthy = data && [data.db, data.redis, data.limiter, data.broker, data.worker, data.beat].every(value => value === 'ok') && probes.data?.every(Boolean)
  const services = data ? [
    { name: 'Database', detail: 'Durable application data', value: data.db, icon: Database },
    { name: 'Cache', detail: 'Fast, fresh reads', value: data.redis, icon: Layers },
    { name: 'Rate limiter', detail: 'Request protection', value: data.limiter, icon: ShieldCheck },
    { name: 'Message broker', detail: 'Background job queue', value: data.broker, icon: Radio },
    { name: 'Delivery worker', detail: 'Recent worker heartbeat', value: data.worker, icon: Server },
    { name: 'Scheduler', detail: 'Recent scheduler heartbeat', value: data.beat, icon: Timer },
  ] : []
  const fetching = health.isFetching || probes.isFetching
  return <div className="page-enter space-y-7"><div className="flex flex-wrap items-start justify-between gap-4"><div><p className="eyebrow mb-2 text-primary">Behind the scenes</p><h1 className="page-heading">Keeping Flow in flow.</h1><p className="mt-2 text-sm text-muted-foreground">Service health and delivery, all in one quiet place.</p></div><Button variant="outline" disabled={fetching} onClick={() => { health.refetch(); probes.refetch() }}><RefreshCw className={cn(fetching && 'animate-spin')}/>Refresh status</Button></div>
    {health.error && <ErrorState error={health.error} retry={() => health.refetch()}/>}
    <div role="status" className={cn('flex flex-wrap items-center gap-4 rounded-xl border p-5 sm:p-6', data && healthy ? 'border-emerald-100 bg-[#edf5ee]' : data ? 'border-amber-200 bg-amber-50' : 'bg-card')}><span className={cn('flex size-11 items-center justify-center rounded-full', healthy ? 'bg-emerald-100 text-primary' : data ? 'bg-amber-100 text-amber-700' : 'bg-muted text-muted-foreground')}>{healthy ? <Check size={22}/> : data ? <CircleAlert size={22}/> : <Activity size={22}/>}</span><div className="flex-1"><h2 className="text-base font-semibold">{health.error ? 'Status is unavailable' : !data ? 'Checking your services…' : healthy ? 'Everything is running smoothly' : 'A few things need your attention'}</h2><p className="mt-1.5 text-xs text-muted-foreground">{healthy ? 'Your core services are responding and background processes are checking in.' : 'Review the service checks below for the latest available status.'}</p></div><span className="flex items-center gap-1.5 text-[10px] text-muted-foreground"><Clock3 size={12}/>Updates every 30 seconds</span></div>
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">{health.isPending ? Array.from({ length: 6 }, (_, i) => <div key={i} aria-label="Loading service" className="h-36 animate-pulse rounded-xl border bg-card"/>) : services.map(service => <Card key={service.name} className="p-5"><div className="flex items-center justify-between"><span className="rounded-lg bg-muted p-2.5 text-muted-foreground"><service.icon size={19}/></span><Badge tone={service.value === 'ok' ? 'good' : 'bad'}><span className={cn('size-1.5 rounded-full', service.value === 'ok' ? 'bg-emerald-500' : 'bg-rose-500')}/>{service.value === 'ok' ? 'Healthy' : 'Unavailable'}</Badge></div><h3 className="mt-4 text-sm font-semibold">{service.name}</h3><p className="mt-1.5 text-xs text-muted-foreground">{service.detail}</p></Card>)}</div>
    <div className="grid gap-5 xl:grid-cols-2"><Card><CardHeader><CardTitle>Delivery at a glance</CardTitle><CardDescription>Queued work and deliveries that need a closer look.</CardDescription></CardHeader><CardContent className="space-y-0">{[
      { label: 'Jobs waiting in queue', value: data?.celery_queue_depth, icon: Layers }, { label: 'Due reminders waiting', value: data?.pending_reminders, icon: ListTodo }, { label: 'Failed push deliveries', value: data?.failed_push, icon: Wifi }, { label: 'Failed emails', value: data?.failed_email, icon: Mail },
    ].map(item => <div key={item.label} className="flex items-center gap-3 border-b py-4 first:pt-1 last:border-0 last:pb-0"><item.icon size={16} className="text-muted-foreground"/><span className="text-xs">{item.label}</span><span className="ml-auto text-sm font-semibold tabular-nums">{item.value == null ? '—' : number(item.value)}</span></div>)}<p className="!mt-5 rounded-lg bg-muted px-3 py-2.5 text-[11px] leading-5 text-muted-foreground">{data?.push_enabled ? 'Push delivery is enabled. Accepted messages may still be delayed by the device or network.' : 'Phone push is not enabled in this environment. Due reminders still appear in the notification inbox.'}</p></CardContent></Card>
    <Card><CardHeader><CardTitle>Availability checks</CardTitle><CardDescription>Can the app answer, and is it ready to serve?</CardDescription></CardHeader><CardContent><div className="space-y-4">{[{ label: 'Application health', detail: 'The API process is running.', ok: probes.data?.[0] }, { label: 'Ready to serve', detail: 'Database and Redis connections are available.', ok: probes.data?.[1] }].map(item => <div key={item.label} className="flex items-center gap-3 rounded-lg border p-4"><span className={cn('rounded-full p-1.5', item.ok ? 'bg-emerald-50 text-primary' : 'bg-muted text-muted-foreground')}>{item.ok ? <Check size={15}/> : <CircleAlert size={15}/>}</span><div className="flex-1"><p className="text-xs font-medium">{item.label}</p><p className="mt-1.5 text-[11px] text-muted-foreground">{item.detail}</p></div><span className={cn('text-[11px] font-medium', item.ok ? 'text-primary' : 'text-muted-foreground')}>{item.ok === undefined ? 'Checking' : item.ok ? 'Passing' : 'Failing'}</span></div>)}</div>{data && <p className="mt-5 text-[10px] text-muted-foreground">Last checked {new Date(data.checked_at).toLocaleTimeString('en', { hour: '2-digit', minute: '2-digit', second: '2-digit' })} · your local time</p>}</CardContent></Card></div>
  </div>
}
