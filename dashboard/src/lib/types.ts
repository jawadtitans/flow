export type User = { id: string; email: string; display_name: string; timezone: string; is_staff: boolean; is_active: boolean; is_verified: boolean; created_at: string }
export type AdminUser = Omit<User, 'timezone'> & { task_count: number; completed_task_count: number; routine_count: number }
export type UserPage = { items: AdminUser[]; total: number; limit: number; offset: number }
export type Overview = { total_users: number; active_users_7d: number; tasks_created_today: number; tasks_completed_today: number; routines_run_today: number; timezone: string; date: string }
export type ActivityPoint = { date: string; tasks_created: number; tasks_completed: number; routines_completed: number; users_joined: number }
export type SystemHealth = { db: string; redis: string; limiter: string; broker: string; worker: string; beat: string; celery_queue_depth: number | null; pending_reminders: number | null; failed_push: number | null; failed_email: number | null; checked_at: string; push_enabled: boolean }
