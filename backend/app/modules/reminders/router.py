from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.reminders.models import Reminder
from app.modules.reminders.schemas import ReminderCreate, ReminderResponse, ReminderUpdate
from app.modules.tasks.models import TaskStatus
from app.modules.tasks.service import get_owned_task
from app.modules.users.models import User
from app.shared.time import utcnow

router = APIRouter(prefix="/reminders", tags=["reminders"])


async def owned(db, user_id, reminder_id):
    reminder = await db.scalar(
        select(Reminder)
        .where(Reminder.id == reminder_id, Reminder.user_id == user_id)
        .with_for_update()
    )
    if not reminder:
        raise HTTPException(404, "Reminder not found")
    return reminder


@router.get("", response_model=list[ReminderResponse])
async def reminders(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return (
        await db.scalars(
            select(Reminder)
            .where(Reminder.user_id == user.id)
            .order_by(Reminder.remind_at, Reminder.id)
            .limit(limit)
            .offset(offset)
        )
    ).all()


@router.post("", response_model=ReminderResponse, status_code=201)
async def create(
    payload: ReminderCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if payload.task_id:
        task = await get_owned_task(db, payload.task_id, user.id, lock=True)
        if task.status == TaskStatus.COMPLETED:
            raise HTTPException(422, "Completed tasks cannot have new reminders")
    reminder = Reminder(user_id=user.id, **payload.model_dump())
    db.add(reminder)
    await db.commit()
    await db.refresh(reminder)
    return reminder


@router.get("/{reminder_id}", response_model=ReminderResponse)
async def get(
    reminder_id: UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    return await owned(db, user.id, reminder_id)


@router.patch("/{reminder_id}", response_model=ReminderResponse)
async def edit(
    reminder_id: UUID,
    payload: ReminderUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    reminder = await owned(db, user.id, reminder_id)
    if reminder.is_sent or reminder.cancelled_at:
        raise HTTPException(409, "A sent or cancelled reminder cannot be changed")
    reminder.remind_at, reminder.message = payload.remind_at, payload.message
    await db.commit()
    return reminder


@router.delete("/{reminder_id}", status_code=204)
async def cancel(
    reminder_id: UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    reminder = await owned(db, user.id, reminder_id)
    if not reminder.cancelled_at and not reminder.is_sent:
        reminder.cancelled_at = utcnow()
    await db.commit()
