from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.notifications.models import Device, Notification
from app.modules.notifications.schemas import (
    DeviceCreate,
    DeviceResponse,
    NotificationPage,
    NotificationResponse,
)
from app.modules.users.models import User
from app.shared.time import utcnow

router = APIRouter(tags=["notifications"])


@router.post("/devices", response_model=DeviceResponse, status_code=201)
async def register_device(
    payload: DeviceCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    device = await db.scalar(select(Device).where(Device.token == payload.token).with_for_update())
    if device and device.user_id != user.id:
        raise HTTPException(409, "Device is registered to another account; unregister it first")
    if device:
        device.platform, device.is_active, device.updated_at = payload.platform, True, utcnow()
    else:
        device = Device(user_id=user.id, **payload.model_dump())
        db.add(device)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(409, "Device registration changed; retry") from None
    await db.refresh(device)
    return device


@router.get("/devices", response_model=list[DeviceResponse])
async def devices(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return (await db.scalars(select(Device).where(Device.user_id == user.id))).all()


@router.delete("/devices/{device_id}", status_code=204)
async def unregister_device(
    device_id: UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    device = await db.scalar(
        select(Device).where(Device.id == device_id, Device.user_id == user.id)
    )
    if not device:
        raise HTTPException(404, "Device not found")
    await db.delete(device)
    await db.commit()


@router.get("/notifications", response_model=NotificationPage)
async def notifications(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    where = Notification.user_id == user.id
    total = await db.scalar(select(func.count()).select_from(Notification).where(where))
    unread = await db.scalar(
        select(func.count()).select_from(Notification).where(where, Notification.read_at.is_(None))
    )
    items = (
        await db.scalars(
            select(Notification)
            .where(where)
            .order_by(Notification.created_at.desc(), Notification.id)
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return {"items": items, "total": total, "unread": unread, "limit": limit, "offset": offset}


@router.post("/notifications/{notification_id}/read", response_model=NotificationResponse)
async def read(
    notification_id: UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    item = await db.scalar(
        select(Notification)
        .where(Notification.id == notification_id, Notification.user_id == user.id)
        .with_for_update()
    )
    if not item:
        raise HTTPException(404, "Notification not found")
    item.read_at = item.read_at or utcnow()
    await db.commit()
    return item
