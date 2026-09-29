"""Atomic, single-use OTPs and account throttles in the authentication Redis."""

import hashlib
import hmac
import logging
import math
import secrets

from fastapi import HTTPException, Request
from redis.exceptions import RedisError

from app.core.config import get_settings
from app.modules.auth.email import get_email_provider

logger = logging.getLogger(__name__)
NO_PASSWORD = "This account doesn't have a password set. Sign in with a code instead."
INVALID_CODE = "This code is invalid or expired. Request a new code if needed."

# All read/check/write operations are atomic, including expiry and consumption.
_LIMIT = """
local count = redis.call('INCR', KEYS[1])
if count == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end
if count > tonumber(ARGV[2]) then return redis.call('TTL', KEYS[1]) end
return 0
"""
_SAVE = """
redis.call('HSET', KEYS[1], 'digest', ARGV[1], 'attempts', 0)
redis.call('EXPIRE', KEYS[1], 600)
return 1
"""
_CONSUME = """
local digest = redis.call('HGET', KEYS[1], 'digest')
if not digest or redis.call('TTL', KEYS[1]) <= 0 then return 0 end
if digest == ARGV[1] then redis.call('DEL', KEYS[1]); return 1 end
local attempts = redis.call('HINCRBY', KEYS[1], 'attempts', 1)
if attempts >= 5 then redis.call('DEL', KEYS[1]) end
return 0
"""
_REMOVE = """
if redis.call('HGET', KEYS[1], 'digest') == ARGV[1] then return redis.call('DEL', KEYS[1]) end
return 0
"""
_PASSWORD_FAILURE = """
local count = redis.call('INCR', KEYS[1])
if count == 1 then redis.call('EXPIRE', KEYS[1], 900) end
if count >= 5 then
  local delay = math.min(900, 30 * 2 ^ math.min(count - 5, 5))
  redis.call('SET', KEYS[2], '1', 'EX', delay)
  return delay
end
return 0
"""


def normalize_email(email: str) -> str:
    return email.strip().lower()


def digest_code(email: str, purpose: str, code: str) -> str:
    # A keyed hash prevents a Redis dump from exposing six-digit codes by brute force.
    return hmac.new(
        get_settings().jwt_secret.encode(), f"{purpose}:{email}:{code}".encode(), hashlib.sha256
    ).hexdigest()


async def evaluate(redis, script: str, keys: list[str], *args):
    try:
        return await redis.eval(script, len(keys), *keys, *args)
    except RedisError:
        raise HTTPException(
            503, "Authentication temporarily unavailable", headers={"Retry-After": "30"}
        ) from None


def throttled(seconds: int):
    seconds = max(1, seconds)
    return HTTPException(
        429,
        f"Too many attempts. Try again in {math.ceil(seconds / 60)} minute(s).",
        headers={"Retry-After": str(seconds)},
    )


async def delivery_limit(request: Request, email: str, purpose: str):
    settings = get_settings()
    ip = request.client.host if request.client else "unknown"
    for kind, identity, count in (
        ("ip", ip, settings.otp_ip_rate_limit),
        ("email", email, settings.otp_email_rate_limit),
    ):
        identity_hash = hashlib.sha256(identity.encode()).hexdigest()
        retry = await evaluate(
            request.app.state.limiter,
            _LIMIT,
            [f"otp-limit:{purpose}:{kind}:{identity_hash}"],
            900,
            count,
        )
        if retry:
            raise throttled(retry)


async def send_code(redis, email: str, purpose: str):
    code = f"{secrets.randbelow(1_000_000):06d}"
    key = f"otp:{purpose}:{email}"
    digest = digest_code(email, purpose, code)
    await evaluate(redis, _SAVE, [key], digest)
    try:
        await get_email_provider().send(email, purpose, {"code": code})
    except Exception:
        # Do not log provider response bodies or OTPs on real-provider failures.
        await evaluate(redis, _REMOVE, [key], digest)
        logger.warning("otp_email_delivery_failed")
        raise HTTPException(
            503,
            "Could not send your code. Please try again shortly.",
            headers={"Retry-After": "60"},
        ) from None


async def consume_code(redis, email: str, purpose: str, code: str):
    accepted = await evaluate(
        redis, _CONSUME, [f"otp:{purpose}:{email}"], digest_code(email, purpose, code)
    )
    if not accepted:
        raise HTTPException(400, INVALID_CODE)


def password_keys(email: str) -> list[str]:
    identity = hashlib.sha256(email.encode()).hexdigest()
    return [f"password-failures:{identity}", f"password-lock:{identity}"]


async def check_password_lock(redis, email: str):
    retry = await evaluate(redis, "return redis.call('TTL', KEYS[1])", [password_keys(email)[1]])
    if retry > 0:
        raise throttled(retry)


async def password_failure(redis, email: str):
    retry = await evaluate(redis, _PASSWORD_FAILURE, password_keys(email))
    if retry:
        raise throttled(retry)


async def clear_password_failures(redis, email: str):
    await evaluate(redis, "return redis.call('DEL', unpack(KEYS))", password_keys(email))
