import secrets
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.security import hash_password, opaque_token, verify_password
from app.modules.auth import service
from app.modules.auth.models import AuthSession
from app.modules.auth.repository import find_user, revoke_sessions
from app.modules.auth.schemas import (
    AccountTokenRequest,
    ChangePasswordRequest,
    EmailRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
)
from app.modules.users.models import User
from app.shared.rate_limit import auth_limit, email_limit
from app.shared.time import utcnow

router = APIRouter(prefix="/auth", tags=["auth"], dependencies=[Depends(auth_limit)])
Client = Literal["mobile", "browser"]


def browser_guard(request: Request, *, csrf=False):
    if request.headers.get("origin", "") not in get_settings().cors_origin_list:
        raise HTTPException(403, "Untrusted browser origin")
    if csrf:
        cookie = request.cookies.get("flow_csrf", "")
        header = request.headers.get("x-flow-csrf", "")
        if not cookie or not secrets.compare_digest(cookie, header):
            raise HTTPException(403, "Invalid CSRF token")


def token_response(tokens: dict, response: Response, browser: bool):
    response.headers["Cache-Control"] = "no-store"
    if browser:
        settings = get_settings()
        age = settings.refresh_token_expire_days * 86400
        response.set_cookie(
            "flow_refresh",
            tokens.pop("refresh_token"),
            max_age=age,
            httponly=True,
            secure=settings.production,
            samesite="strict",
            path="/api/v1/auth",
        )
        response.set_cookie(
            "flow_csrf",
            opaque_token(),
            max_age=age,
            httponly=False,
            secure=settings.production,
            samesite="strict",
            path="/",
        )
    return tokens


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(
    payload: RegisterRequest,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    await email_limit(request, str(payload.email))
    return token_response(await service.register_user(db, payload), response, False)


@router.post("/login", response_model=TokenResponse, response_model_exclude_none=True)
async def login(
    payload: LoginRequest,
    request: Request,
    response: Response,
    client: Client = Query("mobile"),
    db: AsyncSession = Depends(get_db),
):
    if client == "browser":
        browser_guard(request)
    await email_limit(request, str(payload.email))
    tokens = await service.authenticate(
        db, str(payload.email), payload.password, client == "browser"
    )
    return token_response(tokens, response, client == "browser")


@router.post("/refresh", response_model=TokenResponse, response_model_exclude_none=True)
async def refresh(
    request: Request,
    response: Response,
    payload: RefreshRequest | None = None,
    client: Client = Query("mobile"),
    db: AsyncSession = Depends(get_db),
):
    if client == "browser":
        browser_guard(request, csrf=True)
        token = request.cookies.get("flow_refresh")
    else:
        token = payload.refresh_token if payload else None
    if not token:
        raise HTTPException(401, "Refresh token required")
    return token_response(
        await service.rotate_tokens(db, token, client == "browser"), response, client == "browser"
    )


@router.post("/logout", status_code=204)
async def logout(
    request: Request,
    response: Response,
    client: Client = Query("mobile"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if client == "browser":
        browser_guard(request, csrf=True)
    session = await db.get(AuthSession, request.state.session_id)
    session.revoked_at = utcnow()
    await db.commit()
    response.delete_cookie("flow_refresh", path="/api/v1/auth")
    response.delete_cookie("flow_csrf", path="/")


@router.post("/logout-all", status_code=204)
async def logout_all(
    response: Response, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    await revoke_sessions(db, user.id)
    await db.commit()
    response.delete_cookie("flow_refresh", path="/api/v1/auth")
    response.delete_cookie("flow_csrf", path="/")


@router.post("/forgot-password", status_code=202)
async def forgot(payload: EmailRequest, request: Request, db: AsyncSession = Depends(get_db)):
    await email_limit(request, str(payload.email))
    user = await find_user(db, str(payload.email))
    if user and user.is_active:
        await service.queue_account_email(db, user, "reset")
        await db.commit()
    return {"detail": "If that account is available, a reset link will arrive shortly."}


@router.post("/reset-password", status_code=204)
async def reset(payload: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    await service.reset_password(db, payload.token, payload.password)


@router.post("/verify-email", status_code=204)
async def verify(payload: AccountTokenRequest, db: AsyncSession = Depends(get_db)):
    user = await service.consume_account_token(db, payload.token, "verify")
    user.is_verified = True
    await db.commit()


@router.post("/resend-verification", status_code=202)
async def resend(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if not user.is_verified:
        await service.queue_account_email(db, user, "verify")
        await db.commit()
    return {"detail": "Verification email requested."}


@router.post("/change-password", status_code=204)
async def change_password(
    payload: ChangePasswordRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not await verify_password(payload.current_password, user.password_hash):
        raise HTTPException(400, "Current password is incorrect")
    user.password_hash = await hash_password(payload.password)
    await revoke_sessions(db, user.id)
    await db.commit()
