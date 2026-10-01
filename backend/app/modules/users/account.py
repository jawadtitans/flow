import base64
import binascii
from io import BytesIO

from fastapi import HTTPException
from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy import delete, or_, select

from app.modules.admin.models import AdminAudit
from app.modules.auth.models import AccountToken, AuthSession, RefreshToken
from app.modules.notifications.models import Device, Notification, OutboundEmail, PushDelivery
from app.modules.reminders.models import Reminder
from app.modules.routines.models import Routine, RoutineRun, RoutineRunStep, RoutineStep
from app.modules.tasks.models import Category, Task
from app.modules.users.models import User


def normalize_photo(value: str | None) -> str | None:
    if value is None:
        return None
    try:
        raw = base64.b64decode(value, validate=True)
        if len(raw) > 512000:
            raise ValueError("Photo too large")
        with Image.open(BytesIO(raw)) as image:
            if image.format not in {"JPEG", "PNG", "WEBP"} or image.width * image.height > 16000000:
                raise ValueError("Unsupported image")
            image = ImageOps.exif_transpose(image).convert("RGB")
            image.thumbnail((512, 512))
            output = BytesIO()
            image.save(output, format="JPEG", quality=85)
        return base64.b64encode(output.getvalue()).decode("ascii")
    except (
        ValueError,
        binascii.Error,
        OSError,
        UnidentifiedImageError,
        Image.DecompressionBombError,
    ):
        raise HTTPException(422, "Choose a JPEG, PNG or WebP photo smaller than 500 KB") from None


async def delete_account(db, user):
    # Explicit child-first deletion also covers legacy foreign keys without CASCADE.
    await db.execute(
        delete(PushDelivery).where(
            or_(
                PushDelivery.device_id.in_(select(Device.id).where(Device.user_id == user.id)),
                PushDelivery.notification_id.in_(
                    select(Notification.id).where(Notification.user_id == user.id)
                ),
            )
        )
    )
    await db.execute(
        delete(RefreshToken).where(
            RefreshToken.session_id.in_(
                select(AuthSession.id).where(AuthSession.user_id == user.id)
            )
        )
    )
    await db.execute(
        delete(RoutineRunStep).where(
            RoutineRunStep.run_id.in_(select(RoutineRun.id).where(RoutineRun.user_id == user.id))
        )
    )
    await db.execute(
        delete(RoutineStep).where(
            RoutineStep.routine_id.in_(select(Routine.id).where(Routine.user_id == user.id))
        )
    )
    for model in (
        Notification,
        Device,
        Reminder,
        Task,
        Category,
        RoutineRun,
        Routine,
        AccountToken,
        AuthSession,
    ):
        await db.execute(delete(model).where(model.user_id == user.id))
    await db.execute(delete(OutboundEmail).where(OutboundEmail.recipient == user.email))
    await db.execute(
        delete(AdminAudit).where(
            or_(AdminAudit.actor_id == user.id, AdminAudit.target_id == user.id)
        )
    )
    await db.execute(delete(User).where(User.id == user.id))
    await db.commit()
