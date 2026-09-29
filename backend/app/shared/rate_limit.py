import hashlib
import logging
import time

from fastapi import HTTPException, Request
from redis.exceptions import RedisError

from app.core.config import get_settings

logger = logging.getLogger(__name__)


async def limit(
    request: Request, bucket: str, identity: str, count: int, *, seconds=60, strict=False
):
    hashed = hashlib.sha256(identity.encode()).hexdigest()
    window = int(time.time()) // seconds
    key = f"flow:limit:{bucket}:{hashed}:{window}"
    try:
        async with request.app.state.limiter.pipeline(transaction=True) as pipe:
            pipe.incr(key)
            pipe.expire(key, seconds + 1, nx=True)
            result, _ = await pipe.execute()
    except RedisError:
        logger.warning("rate_limiter_unavailable")
        if strict:
            raise HTTPException(
                503, "Authentication temporarily unavailable", headers={"Retry-After": "30"}
            ) from None
        return
    if result > count:
        retry = seconds - int(time.time()) % seconds
        raise HTTPException(
            429, "Too many requests. Please try again shortly.", headers={"Retry-After": str(retry)}
        )


async def auth_limit(request: Request):
    settings = get_settings()
    endpoint = request.url.path.rsplit("/", 1)[-1]
    count = (
        settings.register_rate_limit
        if endpoint == "register"
        else settings.refresh_rate_limit
        if endpoint == "refresh"
        else settings.auth_rate_limit
    )
    ip = request.client.host if request.client else "unknown"
    await limit(request, f"auth:{endpoint}", ip, count, strict=True)


async def email_limit(request: Request, email: str):
    await limit(
        request,
        "auth:email",
        email.lower(),
        get_settings().auth_email_rate_limit,
        seconds=300,
        strict=True,
    )
