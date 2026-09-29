from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.routines import service
from app.modules.routines.models import Routine, RoutineRun, RoutineStep
from app.modules.routines.schemas import RoutineCreate, RoutineResponse, RoutineUpdate, RunResponse
from app.modules.users.models import User

router = APIRouter(tags=["routines"])


@router.get("/routines", response_model=list[RoutineResponse])
async def list_routines(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return (
        await db.scalars(
            select(Routine)
            .options(selectinload(Routine.steps))
            .where(Routine.user_id == user.id)
            .order_by(Routine.created_at, Routine.id)
        )
    ).all()


@router.post("/routines", response_model=RoutineResponse, status_code=201)
async def create_routine(
    payload: RoutineCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    routine = Routine(user_id=user.id, **payload.model_dump(exclude={"steps"}))
    routine.steps = [RoutineStep(**step.model_dump()) for step in payload.steps]
    db.add(routine)
    await db.commit()
    return await service.get_routine(db, user.id, routine.id)


@router.get("/routines/{routine_id}", response_model=RoutineResponse)
async def get_routine(
    routine_id: UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    return await service.get_routine(db, user.id, routine_id)


@router.put("/routines/{routine_id}", response_model=RoutineResponse)
async def edit_routine(
    routine_id: UUID,
    payload: RoutineUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    routine = await service.get_routine(db, user.id, routine_id)
    for key, value in payload.model_dump(exclude={"steps"}).items():
        setattr(routine, key, value)
    routine.steps = [RoutineStep(**step.model_dump()) for step in payload.steps]
    await db.commit()
    return routine


@router.delete("/routines/{routine_id}", status_code=204)
async def delete_routine(
    routine_id: UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    routine = await service.get_routine(db, user.id, routine_id)
    await db.execute(
        update(RoutineRun)
        .where(RoutineRun.routine_id == routine_id, RoutineRun.user_id == user.id)
        .values(routine_id=None)
    )
    await db.delete(routine)
    await db.commit()


@router.post("/routines/{routine_id}/runs", response_model=RunResponse, status_code=201)
async def start(
    routine_id: UUID,
    idempotency_key: str | None = Header(None, min_length=1, max_length=128),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return await service.start_run(db, user.id, routine_id, idempotency_key or str(uuid4()))


@router.get("/routine-runs", response_model=list[RunResponse])
async def runs(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return (
        await db.scalars(
            select(RoutineRun)
            .where(RoutineRun.user_id == user.id)
            .options(selectinload(RoutineRun.steps))
            .order_by(RoutineRun.started_at.desc(), RoutineRun.id)
            .limit(limit)
            .offset(offset)
        )
    ).all()


@router.get("/routine-runs/{run_id}", response_model=RunResponse)
async def run(
    run_id: UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    return await service.get_run(db, user.id, run_id)


@router.post("/routine-runs/{run_id}/steps/{step_id}/complete", response_model=RunResponse)
async def complete(
    run_id: UUID,
    step_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return await service.complete_step(db, user.id, run_id, step_id)


@router.post("/routine-runs/{run_id}/cancel", response_model=RunResponse)
async def cancel(
    run_id: UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    run = await service.get_run(db, user.id, run_id, lock=True)
    if run.status == "completed":
        raise HTTPException(409, "Completed runs cannot be cancelled")
    run.status = "cancelled"
    await db.commit()
    return run
