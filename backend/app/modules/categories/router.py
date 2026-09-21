from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.tasks.models import Category, Task
from app.modules.tasks.schemas import CategoryCreate, CategoryResponse
from app.modules.users.models import User
from app.shared.cache import invalidate_today

router = APIRouter(prefix="/categories", tags=["categories"])


async def owned(db, user_id, category_id):
    item = await db.scalar(
        select(Category).where(Category.id == category_id, Category.user_id == user_id)
    )
    if not item:
        raise HTTPException(404, "Category not found")
    return item


@router.get("", response_model=list[CategoryResponse])
async def categories(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return (
        await db.scalars(
            select(Category).where(Category.user_id == user.id).order_by(Category.name, Category.id)
        )
    ).all()


@router.post("", response_model=CategoryResponse, status_code=201)
async def category(
    payload: CategoryCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    item = Category(user_id=user.id, **payload.model_dump())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


@router.patch("/{category_id}", response_model=CategoryResponse)
async def edit(
    category_id: UUID,
    payload: CategoryCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    item = await owned(db, user.id, category_id)
    item.name, item.color = payload.name, payload.color
    await db.commit()
    await invalidate_today(request.app.state.redis, user.id)
    return item


@router.delete("/{category_id}", status_code=204)
async def remove(
    category_id: UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    item = await owned(db, user.id, category_id)
    await db.execute(
        update(Task)
        .where(Task.category_id == item.id, Task.user_id == user.id)
        .values(category_id=None)
    )
    await db.delete(item)
    await db.commit()
    await invalidate_today(request.app.state.redis, user.id)
