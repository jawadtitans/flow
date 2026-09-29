from celery.beat import Scheduler
from redis import Redis
from redis.exceptions import RedisError

from app.core.config import get_settings
from app.shared.time import utcnow


class FlowScheduler(Scheduler):
    """One beat instance; DB row locks keep accidental duplicate polls harmless."""

    def tick(self, *args, **kwargs):
        try:
            with Redis.from_url(
                get_settings().redis_url, socket_timeout=1, socket_connect_timeout=1
            ) as redis:
                redis.set("flow:health:beat", utcnow().isoformat(), ex=30)
        except RedisError:
            pass
        return min(super().tick(*args, **kwargs), 10)
