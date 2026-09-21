from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.tasks.models import Task


async def owned_task(db: AsyncSession, task_id, user_id, *, lock=False):
    query = select(Task).where(Task.id == task_id, Task.user_id == user_id)
    return await db.scalar(query.with_for_update() if lock else query)


async def list_owned(db: AsyncSession, user_id, *, day=None, limit=None, offset=0):
    query = select(Task).where(Task.user_id == user_id)
    if day is not None:
        query = query.where(Task.due_date == day).order_by(Task.created_at, Task.id)
    else:
        query = query.order_by(Task.due_date.asc().nullslast(), Task.created_at.desc(), Task.id)
    if limit is not None:
        query = query.limit(limit).offset(offset)
    return (await db.scalars(query)).all()
