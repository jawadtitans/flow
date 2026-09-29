from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.modules.routines.models import Routine, RoutineRun


async def owned_routine(db, user_id, routine_id):
    return await db.scalar(
        select(Routine)
        .where(Routine.id == routine_id, Routine.user_id == user_id)
        .options(selectinload(Routine.steps))
    )


async def owned_run(db, user_id, run_id, *, lock=False):
    stmt = (
        select(RoutineRun)
        .where(RoutineRun.id == run_id, RoutineRun.user_id == user_id)
        .options(selectinload(RoutineRun.steps))
    )
    return await db.scalar(stmt.with_for_update() if lock else stmt)
