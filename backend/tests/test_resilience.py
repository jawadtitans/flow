from datetime import UTC, datetime

from redis.exceptions import ConnectionError

from app.core.config import Settings
from app.shared.cache import cached_today, invalidate_today, store_today


async def test_today_uses_user_timezone(client, owner, monkeypatch):
    monkeypatch.setattr("app.shared.time.utcnow", lambda: datetime(2026, 9, 20, 20, 0, tzinfo=UTC))
    await client.post(
        "/api/v1/tasks", headers=owner, json={"title": "Kabul tomorrow", "due_date": "2026-09-21"}
    )
    await client.post(
        "/api/v1/tasks", headers=owner, json={"title": "UTC today", "due_date": "2026-09-20"}
    )
    assert [
        item["title"] for item in (await client.get("/api/v1/today", headers=owner)).json()
    ] == ["Kabul tomorrow"]


async def test_stale_read_cannot_repopulate_after_invalidation(env):
    redis = env[2]
    old_key, _ = await cached_today(redis, "user", "2026-09-20", "Asia/Kabul")
    await invalidate_today(redis, "user")
    await store_today(redis, old_key, [{"title": "stale"}])
    _, value = await cached_today(redis, "user", "2026-09-20", "Asia/Kabul")
    assert value is None


async def test_redis_outage_separates_health_and_readiness(env, monkeypatch):
    async def unavailable(*args, **kwargs):
        raise ConnectionError("offline")

    monkeypatch.setattr(env[2], "ping", unavailable)
    assert (await env[0].get("/health")).status_code == 200
    assert (await env[0].get("/ready")).status_code == 503


async def test_cache_outage_does_not_block_reads(env, owner, monkeypatch):
    async def unavailable(*args, **kwargs):
        raise ConnectionError("offline")

    monkeypatch.setattr(env[2], "get", unavailable)
    assert (await env[0].get("/api/v1/today", headers=owner)).status_code == 200


def test_production_rejects_default_secrets():
    import pytest
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        Settings(app_env="production", jwt_secret="unsafe-development-secret")
