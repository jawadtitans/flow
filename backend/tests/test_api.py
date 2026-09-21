from datetime import UTC, datetime

import pytest

from tests.conftest import register


async def test_task_lifecycle_and_ownership(client, owner):
    other, _ = await register(client, "other@example.com")
    created = await client.post("/api/v1/tasks", headers=owner, json={"title": "Study Python"})
    assert created.status_code == 201
    task_id = created.json()["id"]
    for method, suffix in [("get", ""), ("patch", ""), ("delete", ""), ("post", "/complete")]:
        kwargs = {"json": {"title": "attack"}} if method == "patch" else {}
        assert (
            await getattr(client, method)(
                f"/api/v1/tasks/{task_id}{suffix}", headers=other, **kwargs
            )
        ).status_code == 404
    done = await client.post(f"/api/v1/tasks/{task_id}/complete", headers=owner)
    again = await client.post(f"/api/v1/tasks/{task_id}/complete", headers=owner)
    assert done.json()["status"] == "completed"
    assert done.json()["completed_at"] == again.json()["completed_at"]
    assert (await client.delete(f"/api/v1/tasks/{task_id}", headers=owner)).status_code == 204
    assert (await client.get(f"/api/v1/tasks/{task_id}", headers=owner)).status_code == 404


async def test_validation_and_routine_creation(client, owner):
    assert (
        await client.post("/api/v1/tasks", headers=owner, json={"title": ""})
    ).status_code == 422
    routine = await client.post(
        "/api/v1/routines",
        headers=owner,
        json={"name": "Morning", "steps": [{"title": "Water", "position": 0}]},
    )
    assert routine.status_code == 201
    assert routine.json()["steps"][0]["title"] == "Water"
    assert (await client.get("/api/v1/routines", headers=owner)).json()[0]["steps"][0][
        "title"
    ] == "Water"


async def test_category_cannot_cross_ownership_on_update(client, owner):
    other, _ = await register(client, "other@example.com")
    category = (
        await client.post("/api/v1/categories", headers=other, json={"name": "Private"})
    ).json()
    assert (
        await client.post(
            "/api/v1/tasks", headers=owner, json={"title": "Test", "category_id": category["id"]}
        )
    ).status_code == 422
    task = (await client.post("/api/v1/tasks", headers=owner, json={"title": "Test"})).json()
    assert (
        await client.patch(
            f"/api/v1/tasks/{task['id']}", headers=owner, json={"category_id": category["id"]}
        )
    ).status_code == 422
    assert (
        await client.patch(f"/api/v1/tasks/{task['id']}", headers=owner, json={"title": None})
    ).status_code == 422


async def test_today_cache_invalidation_and_isolation(client, owner, env):
    me = (await client.get("/api/v1/me", headers=owner)).json()
    from zoneinfo import ZoneInfo

    day = datetime.now(UTC).astimezone(ZoneInfo(me["timezone"])).date().isoformat()
    assert (await client.get("/api/v1/today", headers=owner)).json() == []
    task = (
        await client.post(
            "/api/v1/tasks", headers=owner, json={"title": "Due today", "due_date": day}
        )
    ).json()
    assert len((await client.get("/api/v1/today", headers=owner)).json()) == 1
    await client.patch(f"/api/v1/tasks/{task['id']}", headers=owner, json={"title": "Updated"})
    assert (await client.get("/api/v1/today", headers=owner)).json()[0]["title"] == "Updated"
    await client.post(f"/api/v1/tasks/{task['id']}/complete", headers=owner)
    assert (await client.get("/api/v1/today", headers=owner)).json()[0]["status"] == "completed"
    other, _ = await register(client, "other@example.com")
    assert (await client.get("/api/v1/today", headers=other)).json() == []
    await client.delete(f"/api/v1/tasks/{task['id']}", headers=owner)
    assert (await client.get("/api/v1/today", headers=owner)).json() == []
    assert await env[2].keys("flow:cache:today:*")


async def test_routine_run_history_and_idempotency(client, owner):
    routine = (
        await client.post(
            "/api/v1/routines",
            headers=owner,
            json={"name": "Morning", "steps": [{"title": "Water", "position": 0}]},
        )
    ).json()
    run = (
        await client.post(
            f"/api/v1/routines/{routine['id']}/runs", headers={**owner, "Idempotency-Key": "first"}
        )
    ).json()
    retry = (
        await client.post(
            f"/api/v1/routines/{routine['id']}/runs", headers={**owner, "Idempotency-Key": "first"}
        )
    ).json()
    assert run["id"] == retry["id"]
    other, _ = await register(client, "other@example.com")
    assert (await client.get(f"/api/v1/routine-runs/{run['id']}", headers=other)).status_code == 404
    done = (
        await client.post(
            f"/api/v1/routine-runs/{run['id']}/steps/{run['steps'][0]['id']}/complete",
            headers=owner,
        )
    ).json()
    assert done["status"] == "completed"
    await client.delete(f"/api/v1/routines/{routine['id']}", headers=owner)
    history = (await client.get(f"/api/v1/routine-runs/{run['id']}", headers=owner)).json()
    assert history["name"] == "Morning" and history["routine_id"] is None


@pytest.mark.parametrize(
    "path", ["tasks", "today", "routines", "reminders", "notifications", "devices", "me"]
)
async def test_auth_required(client, path):
    assert (await client.get(f"/api/v1/{path}")).status_code == 401
