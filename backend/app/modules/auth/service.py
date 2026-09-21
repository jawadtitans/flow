from datetime import timedelta
from uuid import UUID

import jwt
from fastapi import HTTPException
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import (
    create_token,
    decode_token,
    hash_password,
    opaque_token,
    token_digest,
    verify_password,
)
from app.modules.auth.models import AccountToken, AuthSession, RefreshToken
from app.modules.auth.repository import find_user, revoke_sessions
from app.modules.auth.schemas import RegisterRequest
from app.modules.notifications.models import OutboundEmail
from app.modules.users.models import User
from app.shared.time import aware, utcnow


async def issue_tokens(db: AsyncSession, user: User, session: AuthSession):
    refresh = create_token(user.id, session.id, "refresh")
    db.add(
        RefreshToken(
            session_id=session.id,
            token_hash=token_digest(refresh),
            expires_at=min(
                aware(session.expires_at),
                utcnow() + timedelta(days=get_settings().refresh_token_expire_days),
            ),
        )
    )
    return {
        "access_token": create_token(user.id, session.id, "access"),
        "refresh_token": refresh,
        "token_type": "bearer",
    }


async def new_session(db: AsyncSession, user: User):
    session = AuthSession(
        user_id=user.id,
        expires_at=utcnow() + timedelta(days=get_settings().refresh_token_expire_days),
    )
    db.add(session)
    await db.flush()
    result = await issue_tokens(db, user, session)
    await db.commit()
    return result


async def queue_account_email(db: AsyncSession, user: User, purpose: str):
    await db.execute(
        update(AccountToken)
        .where(
            AccountToken.user_id == user.id,
            AccountToken.purpose == purpose,
            AccountToken.used_at.is_(None),
        )
        .values(used_at=utcnow())
    )
    token = opaque_token()
    db.add(
        AccountToken(
            user_id=user.id,
            token_hash=token_digest(token),
            purpose=purpose,
            expires_at=utcnow() + timedelta(minutes=30 if purpose == "reset" else 1440),
        )
    )
    path = "reset-password" if purpose == "reset" else "verify-email"
    link = f"{get_settings().public_app_url.rstrip('/')}/{path}?token={token}"
    subject = "Reset your Flow password" if purpose == "reset" else "Verify your Flow email"
    db.add(
        OutboundEmail(
            recipient=user.email,
            subject=subject,
            body=f"{subject}\n\nOpen this link: {link}\n\nIf you didn't request this, you can ignore this email.\nFlow",
        )
    )


async def register_user(db: AsyncSession, payload: RegisterRequest):
    if await find_user(db, str(payload.email)):
        raise HTTPException(409, "Email is already registered")
    user = User(
        email=str(payload.email).lower(),
        display_name=payload.display_name.strip(),
        password_hash=await hash_password(payload.password),
    )
    if not user.display_name:
        raise HTTPException(422, "Display name cannot be blank")
    db.add(user)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(409, "Email is already registered") from None
    await queue_account_email(db, user, "verify")
    return await new_session(db, user)


async def authenticate(db: AsyncSession, email: str, password: str, browser=False):
    user = await find_user(db, email)
    if not user:
        # Equalize the expensive work for unknown emails.
        await hash_password(password)
        raise HTTPException(401, "Invalid email or password")
    if not await verify_password(password, user.password_hash) or not user.is_active:
        raise HTTPException(401, "Invalid email or password")
    if browser and not user.is_staff:
        raise HTTPException(403, "Staff access required")
    return await new_session(db, user)


async def rotate_tokens(db: AsyncSession, token: str, browser=False):
    try:
        payload = decode_token(token, "refresh")
        sid, uid = UUID(payload["sid"]), UUID(payload["sub"])
    except (jwt.PyJWTError, ValueError, TypeError, KeyError):
        raise HTTPException(401, "Invalid refresh token") from None
    session = await db.scalar(
        select(AuthSession)
        .where(AuthSession.id == sid, AuthSession.user_id == uid)
        .with_for_update()
    )
    user = await db.get(User, uid)
    if (
        not session
        or session.revoked_at
        or aware(session.expires_at) <= utcnow()
        or not user
        or not user.is_active
    ):
        raise HTTPException(401, "User session is unavailable")
    if browser and not user.is_staff:
        raise HTTPException(403, "Staff access required")
    saved = await db.scalar(
        select(RefreshToken).where(
            RefreshToken.token_hash == token_digest(token), RefreshToken.session_id == sid
        )
    )
    if not saved or aware(saved.expires_at) <= utcnow():
        raise HTTPException(401, "Invalid refresh token")
    consumed = await db.execute(
        update(RefreshToken)
        .where(RefreshToken.id == saved.id, RefreshToken.used_at.is_(None))
        .values(used_at=utcnow())
    )
    if consumed.rowcount != 1:
        session.revoked_at = utcnow()
        await db.commit()
        raise HTTPException(401, "Refresh token was reused; sign in again")
    result = await issue_tokens(db, user, session)
    await db.commit()
    return result


async def consume_account_token(db: AsyncSession, token: str, purpose: str):
    record = await db.scalar(
        select(AccountToken)
        .where(
            AccountToken.token_hash == token_digest(token),
            AccountToken.purpose == purpose,
            AccountToken.expires_at > utcnow(),
        )
        .with_for_update()
    )
    if not record:
        raise HTTPException(400, "This link is invalid or expired")
    consumed = await db.execute(
        update(AccountToken)
        .where(AccountToken.id == record.id, AccountToken.used_at.is_(None))
        .values(used_at=utcnow())
    )
    if consumed.rowcount != 1:
        raise HTTPException(400, "This link is invalid or expired")
    user = await db.get(User, record.user_id)
    if not user or not user.is_active:
        raise HTTPException(400, "This link is invalid or expired")
    return user


async def reset_password(db: AsyncSession, token: str, password: str):
    user = await consume_account_token(db, token, "reset")
    user.password_hash = await hash_password(password)
    await revoke_sessions(db, user.id)
    await db.commit()
