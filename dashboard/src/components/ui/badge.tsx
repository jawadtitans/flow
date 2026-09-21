import type { HTMLAttributes } from 'react'
import { cn } from '@/lib/utils'
export function Badge({ className, tone = 'neutral', ...props }: HTMLAttributes<HTMLSpanElement> & { tone?: 'good' | 'bad' | 'neutral' }) { return <span className={cn('inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-medium', tone === 'good' ? 'border-emerald-100 bg-emerald-50 text-emerald-800' : tone === 'bad' ? 'border-rose-100 bg-rose-50 text-rose-700' : 'border-border bg-muted text-muted-foreground', className)} {...props} /> }
