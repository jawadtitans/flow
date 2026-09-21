"""Opt-in checks against the full, isolated Docker stack (no mocked broker/worker)."""

import asyncio
import os
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import httpx
import pytest

pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(
        not os.getenv("FLOW_STACK_URL"), reason="Set FLOW_STACK_URL to an isolated running stack"
    ),
]


async def test_real_celery_reminder_delivery_and_session_rotation():
    base = os.environ["FLOW_STACK_URL"]
    async with httpx.AsyncClient(base_url=base, timeout=15) as client:
        assert (await client.get("/ready")).status_code == 200
        email = f"stack-{uuid4().hex}@example.com"
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": email,
                "password": "stack-test-password",
                "display_name": "Stack validation",
            },
        )
        assert response.status_code == 201, response.text
        tokens = response.json()
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        reminder = await client.post(
            "/api/v1/reminders",
            headers=headers,
            json={
                "remind_at": (datetime.now(UTC) - timedelta(seconds=1)).isoformat(),
                "message": "Real worker delivery",
            },
        )
        assert reminder.status_code == 201, reminder.text
        for _ in range(30):
            inbox = (await client.get("/api/v1/notifications", headers=headers)).json()
            if inbox["total"]:
                break
            await asyncio.sleep(1)
        assert inbox["total"] == 1, "A real beat/worker must deliver the reminder within 30s"
        assert inbox["items"][0]["body"] == "Real worker delivery"
        # Another scheduler interval must not create a duplicate inbox item.
        await asyncio.sleep(11)
        assert (await client.get("/api/v1/notifications", headers=headers)).json()["total"] == 1
        refresh = await client.post(
            "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
        )
        assert refresh.status_code == 200, refresh.text
        assert (
            await client.get("/api/v1/admin/stats/overview", headers=headers)
        ).status_code == 403
        assert (await client.get("/metrics")).status_code == 404
