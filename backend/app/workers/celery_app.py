from celery import Celery

from app.core.config import get_settings

settings = get_settings()
celery_app = Celery(
    "flow",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
    include=["app.workers.notification_worker"],
)
celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    enable_utc=True,
    result_expires=3600,
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    worker_prefetch_multiplier=1,
    task_soft_time_limit=210,
    task_time_limit=240,
    broker_connection_retry_on_startup=True,
    broker_transport_options={"visibility_timeout": 600},
    result_backend_transport_options={"visibility_timeout": 600},
    visibility_timeout=600,
    beat_scheduler="app.workers.scheduler:FlowScheduler",
    beat_schedule={
        "due-reminders": {"task": "flow.reminders.poll", "schedule": 10.0},
        "push-outbox": {"task": "flow.push.deliver", "schedule": 10.0},
        "email-outbox": {"task": "flow.email.deliver", "schedule": 10.0},
        "expired-secrets": {"task": "flow.cleanup", "schedule": 3600.0},
    },
)
