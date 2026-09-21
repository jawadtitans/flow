import re

from sqlalchemy import select

from app.core.config import get_settings
from app.modules.notifications.models import OutboundEmail
from tests.conftest import register


async def test_refresh_rotation_replay_revokes_session(client):
    headers, tokens = await register(client)
    rotated = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert rotated.status_code == 200
    assert rotated.json()["refresh_token"] != tokens["refresh_token"]
    assert (
        await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    ).status_code == 401
    assert (await client.get("/api/v1/me", headers=headers)).status_code == 401
    assert (
        await client.post(
            "/api/v1/auth/refresh", json={"refresh_token": rotated.json()["refresh_token"]}
        )
    ).status_code == 401


async def test_logout_revokes_access(client, owner):
    assert (await client.post("/api/v1/auth/logout", headers=owner)).status_code == 204
    assert (await client.get("/api/v1/me", headers=owner)).status_code == 401


async def test_browser_staff_cookie_and_csrf(client, staff):
    origin = {"Origin": "http://localhost:5173"}
    login = await client.post(
        "/api/v1/auth/login?client=browser",
        headers=origin,
        json={"email": "staff@example.com", "password": "correct-password"},
    )
    assert login.status_code == 200
    assert "refresh_token" not in login.json()
    assert "HttpOnly" in login.headers.get_list("set-cookie")[0]
    assert (
        await client.post("/api/v1/auth/refresh?client=browser", headers=origin)
    ).status_code == 403
    csrf = client.cookies.get("flow_csrf")
    refreshed = await client.post(
        "/api/v1/auth/refresh?client=browser", headers={**origin, "X-Flow-CSRF": csrf}
    )
    assert refreshed.status_code == 200
    assert (
        await client.post(
            "/api/v1/auth/refresh?client=browser",
            headers={
                "Origin": "https://evil.example",
                "X-Flow-CSRF": client.cookies.get("flow_csrf"),
            },
        )
    ).status_code == 403


async def test_nonstaff_browser_login_rejected(client, owner):
    response = await client.post(
        "/api/v1/auth/login?client=browser",
        headers={"Origin": "http://localhost:5173"},
        json={"email": "user@example.com", "password": "correct-password"},
    )
    assert response.status_code == 403
    assert "flow_refresh" not in client.cookies


async def test_reset_and_verification_one_use(env, owner):
    client, factory, _, _ = env
    async with factory() as db:
        verify_mail = await db.scalar(
            select(OutboundEmail).where(OutboundEmail.subject == "Verify your Flow email")
        )
        verify_token = re.search(r"token=([^\s]+)", verify_mail.body)[1]
    assert (
        await client.post("/api/v1/auth/verify-email", json={"token": verify_token})
    ).status_code == 204
    assert (
        await client.post("/api/v1/auth/verify-email", json={"token": verify_token})
    ).status_code == 400
    known = await client.post("/api/v1/auth/forgot-password", json={"email": "user@example.com"})
    unknown = await client.post(
        "/api/v1/auth/forgot-password", json={"email": "unknown@example.com"}
    )
    assert known.json() == unknown.json()
    async with factory() as db:
        reset_mail = await db.scalar(
            select(OutboundEmail).where(OutboundEmail.subject == "Reset your Flow password")
        )
        token = re.search(r"token=([^\s]+)", reset_mail.body)[1]
    assert (
        await client.post(
            "/api/v1/auth/reset-password", json={"token": token, "password": "new-password-123"}
        )
    ).status_code == 204
    assert (await client.get("/api/v1/me", headers=owner)).status_code == 401
    assert (
        await client.post(
            "/api/v1/auth/reset-password", json={"token": token, "password": "another-password"}
        )
    ).status_code == 400
    assert (
        await client.post(
            "/api/v1/auth/login", json={"email": "user@example.com", "password": "new-password-123"}
        )
    ).status_code == 200


async def test_auth_rate_limit(client, monkeypatch):
    monkeypatch.setattr(get_settings(), "auth_rate_limit", 2)
    for _ in range(2):
        response = await client.post(
            "/api/v1/auth/login", json={"email": "wrong@example.com", "password": "wrong-password"}
        )
        assert response.status_code == 401
    response = await client.post(
        "/api/v1/auth/login", json={"email": "wrong@example.com", "password": "wrong-password"}
    )
    assert response.status_code == 429
    assert int(response.headers["retry-after"]) > 0


async def test_profile_timezone_validation(client, owner):
    assert (
        await client.patch("/api/v1/me", headers=owner, json={"timezone": "No/SuchZone"})
    ).status_code == 422
    updated = await client.patch(
        "/api/v1/me", headers=owner, json={"timezone": "Asia/Kabul", "is_staff": True}
    )
    assert updated.json()["timezone"] == "Asia/Kabul"
    assert updated.json()["is_staff"] is False
