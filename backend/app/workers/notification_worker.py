import asyncio
from datetime import timedelta

from celery.signals import heartbeat_sent
from redis import Redis
from redis.exceptions import RedisError
from sqlalchemy import delete
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core import models  # noqa: F401
from app.core.config import get_settings
from app.core.database import make_engine
from app.modules.auth.models import AccountToken, AuthSession
from app.modules.notifications.models import OutboundEmail
from app.modules.notifications.service import deliver_email, deliver_push, materialize_due
from app.shared.time import utcnow
from app.workers.celery_app import celery_app


async def with_session(operation):
    settings = get_settings()
    # Celery's synchronous task boundary owns this loop, engine and session completely.
    engine = make_engine(settings.database_url, pooler=settings.database_pooler)
    try:
        async with async_sessionmaker(engine, expire_on_commit=False)() as db:
            return await operation(db)
    finally:
        await engine.dispose()


@celery_app.task(
    name="flow.reminders.poll", autoretry_for=(SQLAlchemyError,), retry_backoff=True, max_retries=5
)
def poll_reminders():
    return asyncio.run(with_session(materialize_due))


@celery_app.task(
    name="flow.push.deliver", autoretry_for=(SQLAlchemyError,), retry_backoff=True, max_retries=5
)
def send_push():
    return asyncio.run(with_session(deliver_push))


@celery_app.task(
    name="flow.email.deliver", autoretry_for=(SQLAlchemyError,), retry_backoff=True, max_retries=5
)
def send_email():
    return asyncio.run(with_session(deliver_email))


@celery_app.task(name="flow.cleanup")
def cleanup():
    async def prune(db):
        await db.execute(
            delete(AuthSession).where(AuthSession.expires_at < utcnow() - timedelta(days=1))
        )
        await db.execute(
            delete(AccountToken).where(AccountToken.expires_at < utcnow() - timedelta(days=1))
        )
        await db.execute(
            delete(OutboundEmail).where(OutboundEmail.created_at < utcnow() - timedelta(days=7))
        )
        await db.commit()

    return asyncio.run(with_session(prune))


@heartbeat_sent.connect
def worker_heartbeat(sender=None, **kwargs):
    try:
        with Redis.from_url(
            get_settings().redis_url, socket_timeout=1, socket_connect_timeout=1
        ) as redis:
            redis.set("flow:health:worker", utcnow().isoformat(), ex=30)
    except RedisError:
        pass
