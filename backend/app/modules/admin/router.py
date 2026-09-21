from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from redis.exceptions import RedisError
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db
from app.core.dependencies import require_staff
from app.core.health import dependencies
from app.modules.admin import repository
from app.modules.admin.models import AdminAudit
from app.modules.admin.schemas import ActivityPoint, Overview, SystemHealth, UserPage
from app.modules.auth.repository import revoke_sessions
from app.modules.notifications.models import OutboundEmail, PushDelivery
from app.modules.reminders.models import Reminder
from app.modules.users.models import User
from app.shared.time import utcnow

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(require_staff)])


@router.get("/stats/overview", response_model=Overview)
async def overview(db: AsyncSession = Depends(get_db)):
    return await repository.overview(db)


@router.get("/stats/activity", response_model=list[ActivityPoint])
async def activity(days: int = Query(14, ge=7, le=31), db: AsyncSession = Depends(get_db)):
    return await repository.activity(db, days)


@router.get("/users/", response_model=UserPage)
async def users(
    search: str = Query("", max_length=100),
    status: Literal["all", "active", "inactive"] = "all",
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    return await repository.users(
        db, search=search.strip(), status=status, limit=limit, offset=offset
    )


@router.post("/users/{user_id}/deactivate", status_code=204)
async def deactivate(
    user_id: UUID,
    request: Request,
    staff: User = Depends(require_staff),
    db: AsyncSession = Depends(get_db),
):
    target = await db.scalar(select(User).where(User.id == user_id).with_for_update())
    if not target:
        raise HTTPException(404, "User not found")
    if target.is_staff:
        raise HTTPException(409, "Staff accounts must be managed through the server CLI")
    if target.is_active:
        target.is_active = False
        await revoke_sessions(db, target.id)
        db.add(
            AdminAudit(
                actor_id=staff.id,
                target_id=target.id,
                action="user.deactivate",
                request_id=request.state.request_id,
            )
        )
        await db.commit()


@router.get("/system/health", response_model=SystemHealth)
async def system_health(request: Request, db: AsyncSession = Depends(get_db)):
    state = await dependencies(db, request.app)
    worker, beat, depth = "error", "error", None
    try:
        worker = "ok" if await request.app.state.redis.get("flow:health:worker") else "error"
        beat = "ok" if await request.app.state.redis.get("flow:health:beat") else "error"
        depth = await request.app.state.broker.llen("celery")
    except RedisError:
        pass
    pending = failed_push = failed_email = None
    if state["db"] == "ok":
        pending = await db.scalar(
            select(func.count())
            .select_from(Reminder)
            .where(
                Reminder.is_sent.is_(False),
                Reminder.cancelled_at.is_(None),
                Reminder.remind_at <= utcnow(),
            )
        )
        failed_push = await db.scalar(
            select(func.count()).select_from(PushDelivery).where(PushDelivery.status == "failed")
        )
        failed_email = await db.scalar(
            select(func.count()).select_from(OutboundEmail).where(OutboundEmail.status == "failed")
        )
    return {
        **state,
        "worker": worker,
        "beat": beat,
        "celery_queue_depth": depth,
        "pending_reminders": pending,
        "failed_push": failed_push,
        "failed_email": failed_email,
        "checked_at": utcnow(),
        "push_enabled": get_settings().push_enabled,
    }
