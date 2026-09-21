import { useQuery } from '@tanstack/react-query'
import { api } from './api'
import type { ActivityPoint, Overview, SystemHealth, UserPage } from './types'
export const useOverview = () => useQuery({ queryKey: ['overview'], queryFn: () => api<Overview>('/admin/stats/overview') })
export const useActivity = (days: number) => useQuery({ queryKey: ['activity', days], queryFn: () => api<ActivityPoint[]>(`/admin/stats/activity?days=${days}`) })
export const useUsers = (search = '', status = 'all', offset = 0, limit = 20) => useQuery({ queryKey: ['users', search, status, offset, limit], queryFn: () => api<UserPage>(`/admin/users/?${new URLSearchParams({ search, status, offset: String(offset), limit: String(limit) })}`) })
export const useHealth = () => useQuery({ queryKey: ['health'], queryFn: () => api<SystemHealth>('/admin/system/health'), refetchInterval: 30_000 })
