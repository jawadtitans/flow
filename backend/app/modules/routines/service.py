from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from app.modules.routines.models import RoutineRun, RoutineRunStep
from app.modules.routines.repository import owned_routine, owned_run
from app.shared.time import utcnow


async def get_routine(db, user_id, routine_id):
    routine = await owned_routine(db, user_id, routine_id)
    if not routine:
        raise HTTPException(404, "Routine not found")
    return routine


async def get_run(db, user_id, run_id, *, lock=False):
    run = await owned_run(db, user_id, run_id, lock=lock)
    if not run:
        raise HTTPException(404, "Routine run not found")
    return run


async def start_run(db, user_id, routine_id, key):
    query = (
        select(RoutineRun)
        .where(RoutineRun.user_id == user_id, RoutineRun.idempotency_key == key)
        .options(selectinload(RoutineRun.steps))
    )
    previous = await db.scalar(query)
    if previous:
        if previous.routine_id != routine_id:
            raise HTTPException(409, "Idempotency key belongs to a different routine")
        return previous
    routine = await get_routine(db, user_id, routine_id)
    if not routine.is_active or not routine.steps:
        raise HTTPException(422, "An active routine with at least one step is required")
    run = RoutineRun(user_id=user_id, routine_id=routine.id, name=routine.name, idempotency_key=key)
    run.steps = [
        RoutineRunStep(title=s.title, position=s.position, offset_minutes=s.offset_minutes)
        for s in routine.steps
    ]
    db.add(run)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        previous = await db.scalar(query)
        if not previous or previous.routine_id != routine_id:
            raise HTTPException(409, "Idempotency key conflict") from None
        return previous
    return await get_run(db, user_id, run.id)


async def complete_step(db, user_id, run_id, step_id):
    run = await get_run(db, user_id, run_id, lock=True)
    if run.status == "cancelled":
        raise HTTPException(409, "This run is cancelled")
    step = next((step for step in run.steps if step.id == step_id), None)
    if not step:
        raise HTTPException(404, "Run step not found")
    if not step.completed_at:
        step.completed_at = utcnow()
    if all(step.completed_at for step in run.steps) and run.status != "completed":
        run.status, run.completed_at = "completed", utcnow()
    await db.commit()
    return run
