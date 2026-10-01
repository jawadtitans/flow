from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.auth.otp import evaluate
from app.modules.users.account import delete_account, normalize_photo
from app.modules.users.models import User
from app.modules.users.schemas import (
    DeleteAccountRequest,
    OnboardingUpdate,
    ProfilePhotoUpdate,
    UserResponse,
    UserUpdate,
)
from app.shared.cache import invalidate_today

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserResponse)
async def me(user: User = Depends(get_current_user)):
    return user


@router.put("/me/onboarding", response_model=UserResponse)
async def onboarding(
    payload: OnboardingUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not user.profile_completed:
        raise HTTPException(409, "Complete your personal details first")
    user.discovery_source = payload.discovery_source
    user.interests = payload.interests
    user.other_interest = (
        payload.other_interest.strip()
        if "Other" in payload.interests and payload.other_interest
        else None
    )
    user.onboarding_completed = user.onboarding_completed or payload.completed
    await db.commit()
    return user


@router.put("/me/photo", response_model=UserResponse)
async def photo(
    payload: ProfilePhotoUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user.profile_photo = await run_in_threadpool(normalize_photo, payload.photo)
    await db.commit()
    return user


@router.delete("/me", status_code=204)
async def remove_me(
    payload: DeleteAccountRequest,
    request: Request,
    response: Response,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not payload.acknowledge:
        raise HTTPException(422, "Acknowledge permanent account deletion")
    await evaluate(
        request.app.state.limiter,
        "return redis.call('DEL', unpack(KEYS))",
        [f"otp:login:{user.email}", f"otp:reset:{user.email}"],
    )
    await invalidate_today(request.app.state.redis, user.id)
    await delete_account(db, user)
    response.delete_cookie("flow_refresh", path="/api/v1/auth")
    response.delete_cookie("flow_csrf", path="/")


@router.patch("/me", response_model=UserResponse)
async def update_me(
    payload: UserUpdate,
    request: Request,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(user, key, value)
    await db.commit()
    await invalidate_today(request.app.state.redis, user.id)
    return user
