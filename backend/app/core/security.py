import asyncio
import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import jwt
from pwdlib import PasswordHash

from app.core.config import get_settings

password_hash = PasswordHash.recommended()


async def hash_password(password: str) -> str:
    # Argon2 is CPU-bound; only password hashing (never database I/O) runs in a thread.
    return await asyncio.to_thread(password_hash.hash, password)


async def verify_password(password: str, hashed: str) -> bool:
    return await asyncio.to_thread(password_hash.verify, password, hashed)


def token_digest(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def opaque_token() -> str:
    return secrets.token_urlsafe(32)


def create_token(user_id: UUID, session_id: UUID, kind: str) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    expiry = (
        timedelta(days=settings.refresh_token_expire_days)
        if kind == "refresh"
        else timedelta(minutes=settings.access_token_expire_minutes)
    )
    secret = settings.jwt_refresh_secret if kind == "refresh" else settings.jwt_secret
    return jwt.encode(
        {
            "sub": str(user_id),
            "sid": str(session_id),
            "jti": str(uuid4()),
            "type": kind,
            "iat": now,
            "exp": now + expiry,
            "iss": "flow",
            "aud": "flow",
        },
        secret,
        algorithm="HS256",
    )


def decode_token(token: str, kind: str) -> dict:
    settings = get_settings()
    secret = settings.jwt_refresh_secret if kind == "refresh" else settings.jwt_secret
    payload = jwt.decode(
        token,
        secret,
        algorithms=["HS256"],
        audience="flow",
        issuer="flow",
        options={"require": ["sub", "sid", "jti", "exp", "iat"]},
    )
    if payload.get("type") != kind:
        raise jwt.InvalidTokenError("Incorrect token type")
    UUID(payload["sub"])
    UUID(payload["sid"])
    return payload
