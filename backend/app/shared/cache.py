import json
import logging

from redis.exceptions import RedisError

from app.core.config import get_settings

logger = logging.getLogger(__name__)


async def today_key(redis, user_id, day, timezone):
    generation = await redis.get(f"flow:cache:generation:{user_id}") or "0"
    return f"flow:cache:today:{user_id}:{timezone}:{day}:{generation}"


async def cached_today(redis, user_id, day, timezone):
    try:
        key = await today_key(redis, user_id, day, timezone)
        value = await redis.get(key)
        return key, json.loads(value) if value else None
    except (RedisError, ValueError, TypeError):
        logger.warning("cache_read_unavailable")
        return None, None


async def store_today(redis, key, value):
    if key:
        try:
            await redis.set(key, json.dumps(value), ex=get_settings().cache_ttl_seconds)
        except RedisError:
            logger.warning("cache_write_unavailable")


async def invalidate_today(redis, user_id):
    # Generation keys prevent an in-flight old read from repopulating the new cache.
    try:
        await redis.incr(f"flow:cache:generation:{user_id}")
    except RedisError:
        logger.warning("cache_invalidation_unavailable", extra={"user_id": str(user_id)})
