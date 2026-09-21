from datetime import timedelta

from sqlalchemy import func, select

from app.core.config import get_settings
from app.modules.notifications.models import Notification, OutboundEmail, PushDelivery
from app.modules.notifications.providers import DeliveryError
from app.modules.notifications.service import deliver_email, deliver_push, materialize_due
from app.shared.time import utcnow
from tests.conftest import register


async def test_due_reminder_materializes_once(env, owner):
    client, factory, _, _ = env
    reminder = await client.post(
        "/api/v1/reminders",
        headers=owner,
        json={"remind_at": (utcnow() - timedelta(seconds=1)).isoformat(), "message": "Drink water"},
    )
    assert reminder.status_code == 201
    async with factory() as db:
        assert await materialize_due(db) == 1
        assert await materialize_due(db) == 0
        assert await db.scalar(select(func.count()).select_from(Notification)) == 1
    page = (await client.get("/api/v1/notifications", headers=owner)).json()
    assert page["unread"] == 1 and page["items"][0]["body"] == "Drink water"
    nid = page["items"][0]["id"]
    other, _ = await register(client, "other@example.com")
    assert (
        await client.post(f"/api/v1/notifications/{nid}/read", headers=other)
    ).status_code == 404
    assert (
        await client.post(f"/api/v1/notifications/{nid}/read", headers=owner)
    ).status_code == 200
    assert (await client.get("/api/v1/notifications", headers=owner)).json()["unread"] == 0


async def test_task_completion_cancels_pending_reminders(env, owner):
    client, factory, _, _ = env
    task = (await client.post("/api/v1/tasks", headers=owner, json={"title": "Task"})).json()
    reminder = (
        await client.post(
            "/api/v1/reminders",
            headers=owner,
            json={"task_id": task["id"], "remind_at": utcnow().isoformat()},
        )
    ).json()
    await client.post(f"/api/v1/tasks/{task['id']}/complete", headers=owner)
    async with factory() as db:
        assert await materialize_due(db) == 0
    assert (await client.get(f"/api/v1/reminders/{reminder['id']}", headers=owner)).json()[
        "cancelled_at"
    ]
    assert (
        await client.post(
            "/api/v1/reminders", headers=owner, json={"remind_at": "2026-09-20T10:00:00"}
        )
    ).status_code == 422


async def test_push_retry_and_duplicate_delivery(env, owner, monkeypatch):
    client, factory, _, _ = env
    monkeypatch.setattr(get_settings(), "push_enabled", True)
    await client.post(
        "/api/v1/devices",
        headers=owner,
        json={"platform": "android", "token": "test-device-token-long-enough"},
    )
    await client.post("/api/v1/reminders", headers=owner, json={"remind_at": utcnow().isoformat()})

    class Provider:
        calls = 0

        async def send(self, **kwargs):
            self.calls += 1
            if self.calls == 1:
                raise DeliveryError("temporary")

    provider = Provider()
    async with factory() as db:
        await materialize_due(db)
        assert await deliver_push(db, provider) == 1
        item = await db.scalar(select(PushDelivery))
        assert item.status == "retry"
        item.next_attempt_at = utcnow() - timedelta(seconds=1)
        await db.commit()
        assert await deliver_push(db, provider) == 1
        await db.refresh(item)
        assert item.status == "sent"
        assert await deliver_push(db, provider) == 0
        assert provider.calls == 2


async def test_email_outbox_redacts_delivered_token(env, owner):
    class Provider:
        async def send(self, **kwargs):
            assert "token=" in kwargs["body"]

    async with env[1]() as db:
        assert await deliver_email(db, Provider()) == 1
        item = await db.scalar(select(OutboundEmail))
        assert item.status == "sent" and item.body == "[delivered]"


async def test_reminder_task_ownership(client, owner):
    other, _ = await register(client, "other@example.com")
    task = (await client.post("/api/v1/tasks", headers=other, json={"title": "Private"})).json()
    assert (
        await client.post(
            "/api/v1/reminders",
            headers=owner,
            json={"task_id": task["id"], "remind_at": utcnow().isoformat()},
        )
    ).status_code == 404
