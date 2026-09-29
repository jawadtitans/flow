from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.tasks.repository import list_owned
from app.modules.tasks.schemas import TaskCreate, TaskResponse, TaskUpdate
from app.modules.tasks.service import (
    complete_task,
    create_task,
    get_owned_task,
    remove_task,
    update_task,
)
from app.modules.users.models import User
from app.shared.cache import cached_today, invalidate_today, store_today
from app.shared.time import local_today

router = APIRouter(tags=["tasks"])


@router.get("/tasks", response_model=list[TaskResponse])
async def list_tasks(
    limit: int | None = Query(None, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return await list_owned(db, user.id, limit=limit, offset=offset)


@router.post("/tasks", response_model=TaskResponse, status_code=201)
async def add_task(
    payload: TaskCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    task = await create_task(db, user.id, payload)
    await invalidate_today(request.app.state.redis, user.id)
    return task


@router.get("/tasks/{task_id}", response_model=TaskResponse)
async def task(
    task_id: UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    return await get_owned_task(db, task_id, user.id)


@router.patch("/tasks/{task_id}", response_model=TaskResponse)
async def edit_task(
    task_id: UUID,
    payload: TaskUpdate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    task = await update_task(db, await get_owned_task(db, task_id, user.id, lock=True), payload)
    await invalidate_today(request.app.state.redis, user.id)
    return task


@router.post("/tasks/{task_id}/complete", response_model=TaskResponse)
async def complete(
    task_id: UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    task = await complete_task(db, await get_owned_task(db, task_id, user.id, lock=True))
    await invalidate_today(request.app.state.redis, user.id)
    return task


@router.delete("/tasks/{task_id}", status_code=204)
async def delete_task(
    task_id: UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await remove_task(db, await get_owned_task(db, task_id, user.id, lock=True))
    await invalidate_today(request.app.state.redis, user.id)
    return Response(status_code=204)


@router.get("/today", response_model=list[TaskResponse])
async def today(
    request: Request, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    day = local_today(user.timezone)
    key, cached = await cached_today(request.app.state.redis, user.id, day, user.timezone)
    if cached is not None:
        return cached
    tasks = [
        TaskResponse.model_validate(task).model_dump(mode="json")
        for task in await list_owned(db, user.id, day=day)
    ]
    await store_today(request.app.state.redis, key, tasks)
    return tasks
