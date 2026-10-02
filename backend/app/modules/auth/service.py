from datetime import timedelta
from uuid import UUID

import httpx
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
from app.modules.auth import otp
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
    result["profile_completed"] = user.profile_completed
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
    if not user.is_active:
        raise HTTPException(401, "Invalid email or password")
    if not user.password_hash:
        raise HTTPException(400, otp.NO_PASSWORD)
    if not await verify_password(password, user.password_hash):
        raise HTTPException(401, "Invalid email or password")
    if browser and not user.is_staff:
        raise HTTPException(403, "Staff access required")
    return await new_session(db, user)


async def authenticate_with_backoff(db, redis, email: str, password: str, browser=False):
    email = otp.normalize_email(email)
    await otp.check_password_lock(redis, email)
    try:
        tokens = await authenticate(db, email, password, browser)
    except HTTPException as exc:
        if exc.status_code == 401:
            await otp.password_failure(redis, email)
        raise
    await otp.clear_password_failures(redis, email)
    return tokens


async def authenticate_otp(db: AsyncSession, redis, email: str, code: str):
    email = otp.normalize_email(email)
    await otp.consume_code(redis, email, "login", code)
    user = await find_user(db, email)
    if not user:
        user = User(
            email=email,
            password_hash=None,
            display_name="",
            email_verified=True,
            profile_completed=False,
        )
        db.add(user)
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            user = await find_user(db, email)
            if not user:
                raise HTTPException(409, "Please request a new code and try again") from None
    if not user.is_active:
        raise HTTPException(401, "Account is unavailable")
    user.email_verified = True
    return await new_session(db, user)


async def verify_google_access_token(access_token: str) -> tuple[str, str]:
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_publishable_key:
        raise HTTPException(503, "Google sign-in is not configured")
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            response = await client.get(
                f"{settings.supabase_url.rstrip('/')}/auth/v1/user",
                headers={
                    "apikey": settings.supabase_publishable_key.get_secret_value(),
                    "Authorization": f"Bearer {access_token}",
                },
            )
    except httpx.RequestError:
        raise HTTPException(503, "Google sign-in verification is unavailable") from None
    if response.status_code != 200:
        raise HTTPException(401, "Invalid Google sign-in session")
    try:
        identity = response.json()
    except ValueError:
        raise HTTPException(
            503, "Google sign-in verification returned an invalid response"
        ) from None
    if not isinstance(identity, dict):
        raise HTTPException(401, "Invalid Google sign-in session")
    app_metadata = identity.get("app_metadata")
    if not isinstance(app_metadata, dict):
        raise HTTPException(401, "Invalid Google sign-in session")
    providers = app_metadata.get("providers")
    provider = app_metadata.get("provider")
    if provider != "google" and not (isinstance(providers, list) and "google" in providers):
        raise HTTPException(401, "A Google account is required")
    email = identity.get("email")
    if (
        not isinstance(email, str)
        or not email.strip()
        or not (identity.get("email_confirmed_at") or identity.get("confirmed_at"))
    ):
        raise HTTPException(401, "A verified Google email address is required")
    metadata = identity.get("user_metadata")
    name = ""
    if isinstance(metadata, dict):
        name = metadata.get("full_name") or metadata.get("name") or ""
    if not isinstance(name, str):
        name = ""
    return otp.normalize_email(email), name.strip()[:100]


async def authenticate_google(db: AsyncSession, access_token: str):
    email, display_name = await verify_google_access_token(access_token)
    name_parts = display_name.split(maxsplit=1)
    first_name = name_parts[0][:50] if name_parts else None
    last_name = name_parts[1][:49] if len(name_parts) > 1 else None
    user = await find_user(db, email)
    if not user:
        user = User(
            email=email,
            display_name=display_name,
            first_name=first_name,
            last_name=last_name,
            email_verified=True,
            social_auth=True,
        )
        db.add(user)
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            user = await find_user(db, email)
            if not user:
                raise HTTPException(409, "Please try Google sign-in again") from None
    if not user.is_active:
        raise HTTPException(401, "Account is unavailable")
    user.email_verified = True
    user.social_auth = True
    # A previously passwordless email account may have no profile names yet.
    # Prefill those from the verified provider profile without overwriting any
    # name the user has already supplied to Flow.
    if not user.first_name and first_name:
        user.first_name = first_name
    if not user.last_name and last_name:
        user.last_name = last_name
    return await new_session(db, user)


async def reset_password_otp(db: AsyncSession, redis, email: str, code: str, password: str):
    email = otp.normalize_email(email)
    await otp.consume_code(redis, email, "reset", code)
    user = await find_user(db, email)
    if not user or not user.is_active:
        raise HTTPException(400, otp.INVALID_CODE)
    if not user.password_hash:
        raise HTTPException(400, otp.NO_PASSWORD)
    user.password_hash = await hash_password(password)
    user.email_verified = True
    await revoke_sessions(db, user.id)
    await db.commit()
    await otp.clear_password_failures(redis, email)


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
