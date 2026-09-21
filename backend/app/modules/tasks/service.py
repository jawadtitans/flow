from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.reminders.models import Reminder
from app.modules.tasks.models import Category, Task, TaskStatus
from app.modules.tasks.repository import owned_task
from app.modules.tasks.schemas import TaskCreate, TaskUpdate
from app.shared.time import utcnow


async def get_owned_task(db: AsyncSession, task_id: UUID, user_id: UUID, *, lock=False) -> Task:
    task = await owned_task(db, task_id, user_id, lock=lock)
    if task is None:
        raise HTTPException(404, "Task not found")
    return task


async def validate_category(db, category_id, user_id):
    if category_id and not await db.scalar(
        select(Category.id).where(Category.id == category_id, Category.user_id == user_id)
    ):
        raise HTTPException(422, "Category not found")


async def create_task(db: AsyncSession, user_id: UUID, payload: TaskCreate) -> Task:
    await validate_category(db, payload.category_id, user_id)
    task = Task(user_id=user_id, **payload.model_dump())
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return task


async def update_task(db: AsyncSession, task: Task, payload: TaskUpdate) -> Task:
    values = payload.model_dump(exclude_unset=True)
    if "category_id" in values:
        await validate_category(db, values["category_id"], task.user_id)
    for key, value in values.items():
        setattr(task, key, value)
    await db.commit()
    await db.refresh(task)
    return task


async def complete_task(db: AsyncSession, task: Task) -> Task:
    if task.status != TaskStatus.COMPLETED:
        task.status = TaskStatus.COMPLETED
        task.completed_at = utcnow()
        await db.execute(
            update(Reminder)
            .where(
                Reminder.task_id == task.id,
                Reminder.is_sent.is_(False),
                Reminder.cancelled_at.is_(None),
            )
            .values(cancelled_at=utcnow())
        )
        await db.commit()
        await db.refresh(task)
    return task


async def remove_task(db, task):
    await db.execute(
        delete(Reminder).where(Reminder.task_id == task.id, Reminder.user_id == task.user_id)
    )
    await db.delete(task)
    await db.commit()
