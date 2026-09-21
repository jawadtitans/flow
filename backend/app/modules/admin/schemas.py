from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel


class Overview(BaseModel):
    total_users: int
    active_users_7d: int
    tasks_created_today: int
    tasks_completed_today: int
    routines_run_today: int
    timezone: str
    date: date


class ActivityPoint(BaseModel):
    date: date
    tasks_created: int
    tasks_completed: int
    routines_completed: int
    users_joined: int


class AdminUser(BaseModel):
    id: UUID
    email: str
    display_name: str
    is_active: bool
    is_staff: bool
    is_verified: bool
    created_at: datetime
    task_count: int
    completed_task_count: int
    routine_count: int


class UserPage(BaseModel):
    items: list[AdminUser]
    total: int
    limit: int
    offset: int


class SystemHealth(BaseModel):
    db: str
    redis: str
    limiter: str
    broker: str
    worker: str
    beat: str
    celery_queue_depth: int | None
    pending_reminders: int | None
    failed_push: int | None
    failed_email: int | None
    checked_at: datetime
    push_enabled: bool
