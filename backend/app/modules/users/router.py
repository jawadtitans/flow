from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.users.models import User
from app.modules.users.schemas import UserResponse, UserUpdate
from app.shared.cache import invalidate_today

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserResponse)
async def me(user: User = Depends(get_current_user)):
    return user


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
