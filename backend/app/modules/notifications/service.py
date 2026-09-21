from datetime import timedelta
from uuid import uuid4

from sqlalchemy import and_, or_, select, update

from app.core.config import get_settings
from app.modules.notifications.models import Device, Notification, OutboundEmail, PushDelivery
from app.modules.notifications.providers import DeliveryError, FCMProvider, SMTPProvider
from app.modules.reminders.models import Reminder
from app.modules.tasks.models import Task, TaskStatus
from app.modules.users.models import User
from app.shared.time import utcnow


async def materialize_due(db, *, batch_size=100):
    """Commit the inbox and outbox together; the database is the durable queue of record."""
    query = (
        select(Reminder)
        .join(User, Reminder.user_id == User.id)
        .outerjoin(Task, Reminder.task_id == Task.id)
        .where(
            Reminder.remind_at <= utcnow(),
            Reminder.is_sent.is_(False),
            Reminder.cancelled_at.is_(None),
            User.is_active.is_(True),
            or_(Reminder.task_id.is_(None), Task.status == TaskStatus.PENDING),
        )
        .order_by(Reminder.remind_at, Reminder.id)
        .limit(batch_size)
        .with_for_update(skip_locked=True, of=Reminder)
    )
    reminders = (await db.scalars(query)).all()
    for reminder in reminders:
        notification = Notification(
            user_id=reminder.user_id,
            reminder_id=reminder.id,
            title="A moment for your next task",
            body=reminder.message or "You have a Flow reminder.",
        )
        db.add(notification)
        await db.flush()
        if get_settings().push_enabled:
            devices = (
                await db.scalars(
                    select(Device).where(
                        Device.user_id == reminder.user_id, Device.is_active.is_(True)
                    )
                )
            ).all()
            for device in devices:
                db.add(PushDelivery(notification_id=notification.id, device_id=device.id))
        reminder.is_sent, reminder.sent_at = True, utcnow()
    await db.commit()
    return len(reminders)


async def claim(db, model, batch_size):
    now = utcnow()
    due = or_(
        and_(model.status.in_(["pending", "retry"]), model.next_attempt_at <= now),
        and_(model.status == "processing", model.lease_until < now),
    )
    items = (
        await db.scalars(
            select(model)
            .where(due)
            .order_by(model.next_attempt_at, model.id)
            .limit(batch_size)
            .with_for_update(skip_locked=True)
        )
    ).all()
    claims = []
    for item in items:
        item.status, item.lease_id, item.lease_until = (
            "processing",
            str(uuid4()),
            now + timedelta(minutes=5),
        )
        item.attempts += 1
        claims.append((item.id, item.lease_id))
    await db.commit()
    return claims


async def finish(db, model, item, lease_id, error=None):
    if error:
        values = {
            "status": "failed" if error.permanent or item.attempts >= 6 else "retry",
            "last_error": error.code[:80],
            "next_attempt_at": utcnow() + timedelta(seconds=min(3600, 15 * 2**item.attempts)),
        }
    else:
        values = {"status": "sent", "sent_at": utcnow(), "last_error": None}
        if model is OutboundEmail:
            values["body"] = "[delivered]"
    await db.execute(
        update(model)
        .where(model.id == item.id, model.lease_id == lease_id)
        .values(**values, lease_until=None, lease_id=None)
    )
    await db.commit()


async def deliver_push(db, provider=None, *, batch_size=10):
    provider = provider or FCMProvider()
    claims = await claim(db, PushDelivery, batch_size)
    for item_id, lease in claims:
        item = await db.get(PushDelivery, item_id)
        if not item:
            continue
        device = await db.get(Device, item.device_id)
        notification = await db.get(Notification, item.notification_id)
        user = await db.get(User, notification.user_id) if notification else None
        if not device or not device.is_active or not user or not user.is_active:
            await finish(
                db,
                PushDelivery,
                item,
                lease,
                DeliveryError("recipient_unavailable", permanent=True),
            )
            continue
        try:
            await provider.send(
                token=device.token,
                notification_id=str(notification.id),
                title=notification.title,
                body=notification.body,
            )
            await finish(db, PushDelivery, item, lease)
        except DeliveryError as error:
            if error.invalid_device:
                device.is_active = False
            await finish(db, PushDelivery, item, lease, error)
    return len(claims)


async def deliver_email(db, provider=None, *, batch_size=10):
    provider = provider or SMTPProvider()
    claims = await claim(db, OutboundEmail, batch_size)
    for item_id, lease in claims:
        item = await db.get(OutboundEmail, item_id)
        try:
            await provider.send(recipient=item.recipient, subject=item.subject, body=item.body)
            await finish(db, OutboundEmail, item, lease)
        except DeliveryError as error:
            await finish(db, OutboundEmail, item, lease, error)
    return len(claims)
