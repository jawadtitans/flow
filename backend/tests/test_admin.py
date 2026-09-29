from uuid import UUID

import pytest
from sqlalchemy import func, select

from app.modules.admin.models import AdminAudit
from tests.conftest import register


@pytest.mark.parametrize("path", ["stats/overview", "stats/activity", "users/", "system/health"])
async def test_staff_required(client, owner, path):
    assert (await client.get(f"/api/v1/admin/{path}", headers=owner)).status_code == 403


async def test_staff_required_for_deactivate(client, owner):
    user = (await client.get("/api/v1/me", headers=owner)).json()
    assert (
        await client.post(f"/api/v1/admin/users/{user['id']}/deactivate", headers=owner)
    ).status_code == 403


async def test_stats_users_deactivation(client, owner, staff, env):
    user = (await client.get("/api/v1/me", headers=owner)).json()
    task = (await client.post("/api/v1/tasks", headers=owner, json={"title": "one"})).json()
    await client.post(f"/api/v1/tasks/{task['id']}/complete", headers=owner)
    stats = (await client.get("/api/v1/admin/stats/overview", headers=staff)).json()
    assert stats["total_users"] == 2 and stats["active_users_7d"] == 1
    assert stats["tasks_created_today"] == 1 and stats["tasks_completed_today"] == 1
    activity = (await client.get("/api/v1/admin/stats/activity?days=14", headers=staff)).json()
    assert len(activity) == 14 and activity[-1]["tasks_completed"] == 1
    page = (await client.get("/api/v1/admin/users/?search=user@&limit=1", headers=staff)).json()
    assert page["total"] == 1 and page["items"][0]["task_count"] == 1
    assert "password_hash" not in page["items"][0]
    for _ in range(2):
        assert (
            await client.post(f"/api/v1/admin/users/{user['id']}/deactivate", headers=staff)
        ).status_code == 204
    assert (await client.get("/api/v1/me", headers=owner)).status_code == 401
    assert (
        await client.post(
            "/api/v1/auth/login", json={"email": "user@example.com", "password": "correct-password"}
        )
    ).status_code == 401
    async with env[1]() as db:
        assert (
            await db.scalar(
                select(func.count())
                .select_from(AdminAudit)
                .where(AdminAudit.target_id == UUID(user["id"]))
            )
            == 1
        )


async def test_staff_account_protected(client, staff):
    me = (await client.get("/api/v1/me", headers=staff)).json()
    assert (
        await client.post(f"/api/v1/admin/users/{me['id']}/deactivate", headers=staff)
    ).status_code == 409


async def test_health_and_ready(client, env, staff):
    assert (await client.get("/health")).json() == {"status": "ok"}
    assert (await client.get("/ready")).status_code == 200
    await env[2].set("flow:health:worker", "test", ex=30)
    await env[2].set("flow:health:beat", "test", ex=30)
    response = await client.get("/api/v1/admin/system/health", headers=staff)
    assert response.json()["worker"] == "ok" and response.json()["celery_queue_depth"] == 0
    assert (await client.get("/metrics")).status_code == 200
    assert "x-request-id" in response.headers


async def test_search_escapes_wildcards(client, staff):
    await register(client, "plain@example.com")
    page = (await client.get("/api/v1/admin/users/?search=%25", headers=staff)).json()
    assert page["total"] == 0
