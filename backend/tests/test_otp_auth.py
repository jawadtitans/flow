import asyncio
from datetime import date

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.core.config import get_settings
from app.modules.auth import otp
from app.modules.auth.email import ConsoleEmailProvider
from app.modules.users.models import User
from tests.conftest import register


@pytest.fixture
def mail(monkeypatch):
    messages = []

    class Mailbox:
        async def send(self, recipient, template, context):
            messages.append((recipient, template, context["code"]))

    monkeypatch.setattr(otp, "get_email_provider", Mailbox)
    return messages


async def request_code(client, mail, email="new@example.com", purpose="login"):
    path = "request-access" if purpose == "login" else "forgot-password"
    response = await client.post(f"/api/v1/auth/{path}", json={"email": email})
    assert response.status_code in (200, 202), response.text
    return mail[-1][2], response


async def test_new_account_profile_and_returning_otp(env, mail):
    client, factory, redis, _ = env
    code, response = await request_code(client, mail, "New@Example.com")
    assert response.json() == {
        "email": "new@example.com",
        "account_exists": False,
        "has_password": False,
    }
    async with factory() as db:
        assert await db.scalar(select(User)) is None
    stored = await redis.hgetall("otp:login:new@example.com")
    assert code not in str(stored)
    assert stored["attempts"] == "0"
    assert 0 < await redis.ttl("otp:login:new@example.com") <= 600
    verified = await client.post(
        "/api/v1/auth/verify-otp", json={"email": "NEW@example.com", "code": code}
    )
    assert verified.status_code == 200, verified.text
    tokens = verified.json()
    assert tokens["profile_completed"] is False
    assert tokens["refresh_token"]
    assert not await redis.exists("otp:login:new@example.com")
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    profile = {"first_name": "  Amina  ", "last_name": "Ahmadi", "birth_date": "2000-02-29"}
    assert (await client.patch("/api/v1/auth/complete-profile", json=profile)).status_code == 401
    updated = await client.patch("/api/v1/auth/complete-profile", headers=headers, json=profile)
    assert updated.status_code == 200, updated.text
    assert updated.json()["profile_completed"] is True
    assert updated.json()["display_name"] == "Amina Ahmadi"
    assert updated.json()["email_verified"] is True
    assert updated.json()["is_verified"] is True
    assert "password_hash" not in updated.json()
    profile["last_name"] = "Rahimi"
    assert (
        await client.patch("/api/v1/auth/complete-profile", headers=headers, json=profile)
    ).json()["last_name"] == "Rahimi"
    for invalid in ({**profile, "first_name": " "}, {**profile, "birth_date": "2999-01-01"}):
        assert (
            await client.patch("/api/v1/auth/complete-profile", headers=headers, json=invalid)
        ).status_code == 422
    code, _ = await request_code(client, mail)
    assert (
        await client.post(
            "/api/v1/auth/verify-otp", json={"email": "new@example.com", "code": code}
        )
    ).json()["profile_completed"] is True
    async with factory() as db:
        user = await db.scalar(select(User))
        assert user.password_hash is None
        assert user.birth_date == date(2000, 2, 29)


async def test_existing_password_login_and_passwordless_error(env, mail):
    client, factory, _, _ = env
    await register(client)
    async with factory() as db:
        user = await db.scalar(select(User))
        user.profile_completed = True
        await db.commit()
    _, response = await request_code(client, mail, "user@example.com")
    assert response.json()["account_exists"] and response.json()["has_password"]
    login = await client.post(
        "/api/v1/auth/login-password",
        json={"email": "user@example.com", "password": "correct-password"},
    )
    assert login.status_code == 200
    assert login.json()["profile_completed"] is True
    code, _ = await request_code(client, mail)
    await client.post("/api/v1/auth/verify-otp", json={"email": "new@example.com", "code": code})
    for endpoint, payload in (
        ("login-password", {"password": "anything"}),
        ("forgot-password", {}),
    ):
        error = await client.post(
            f"/api/v1/auth/{endpoint}", json={"email": "new@example.com", **payload}
        )
        assert error.status_code == 400
        assert error.json()["detail"] == otp.NO_PASSWORD


async def test_five_wrong_attempts_expiry_resend_and_single_use(env, mail):
    client, _, redis, _ = env
    code, _ = await request_code(client, mail)
    wrong = "000000" if code != "000000" else "111111"
    for _ in range(5):
        assert (
            await client.post(
                "/api/v1/auth/verify-otp", json={"email": "new@example.com", "code": wrong}
            )
        ).status_code == 400
    assert not await redis.exists("otp:login:new@example.com")
    assert (
        await client.post(
            "/api/v1/auth/verify-otp", json={"email": "new@example.com", "code": code}
        )
    ).status_code == 400
    code, _ = await request_code(client, mail)
    await redis.expire("otp:login:new@example.com", 0)
    assert (
        await client.post(
            "/api/v1/auth/verify-otp", json={"email": "new@example.com", "code": code}
        )
    ).status_code == 400
    code, _ = await request_code(client, mail)
    results = await asyncio.gather(
        *[
            client.post("/api/v1/auth/verify-otp", json={"email": "new@example.com", "code": code})
            for _ in range(2)
        ]
    )
    assert sorted(r.status_code for r in results) == [200, 400]


async def test_reset_rejects_login_code_enforces_policy_and_revokes_all(env, mail):
    client = env[0]
    _, tokens = await register(client)
    second = (
        await client.post(
            "/api/v1/auth/login-password",
            json={"email": "user@example.com", "password": "correct-password"},
        )
    ).json()
    login_code, _ = await request_code(client, mail, "user@example.com")
    payload = {
        "email": "user@example.com",
        "code": login_code,
        "new_password": "a-new-long-password",
    }
    assert (await client.post("/api/v1/auth/reset-password", json=payload)).status_code == 400
    reset_code, _ = await request_code(client, mail, "user@example.com", "reset")
    payload["code"] = reset_code
    assert (
        await client.post("/api/v1/auth/reset-password", json={**payload, "new_password": "short"})
    ).status_code == 422
    assert (await client.post("/api/v1/auth/reset-password", json=payload)).status_code == 204
    assert (await client.post("/api/v1/auth/reset-password", json=payload)).status_code == 400
    for session in (tokens, second):
        assert (
            await client.post(
                "/api/v1/auth/refresh", json={"refresh_token": session["refresh_token"]}
            )
        ).status_code == 401
    assert (
        await client.post(
            "/api/v1/auth/login-password",
            json={"email": "user@example.com", "password": "correct-password"},
        )
    ).status_code == 401
    assert (
        await client.post(
            "/api/v1/auth/login-password",
            json={"email": "user@example.com", "password": payload["new_password"]},
        )
    ).status_code == 200


async def test_email_and_ip_rate_limits(env, mail, monkeypatch):
    client = env[0]
    for _ in range(3):
        await request_code(client, mail)
    response = await client.post("/api/v1/auth/request-access", json={"email": "NEW@example.com"})
    assert response.status_code == 429
    assert "minute" in response.json()["detail"]
    assert 0 < int(response.headers["retry-after"]) <= 900
    assert len(mail) == 3
    monkeypatch.setattr(get_settings(), "otp_ip_rate_limit", 4)
    response = await client.post(
        "/api/v1/auth/request-access", json={"email": "different@example.com"}
    )
    assert response.status_code == 429


async def test_password_backoff_shared_with_dashboard(env):
    client, _, redis, _ = env
    await register(client)
    for _ in range(4):
        assert (
            await client.post(
                "/api/v1/auth/login-password",
                json={"email": "user@example.com", "password": "wrong"},
            )
        ).status_code == 401
    blocked = await client.post(
        "/api/v1/auth/login-password", json={"email": "user@example.com", "password": "wrong"}
    )
    assert blocked.status_code == 429
    assert (
        await client.post(
            "/api/v1/auth/login", json={"email": "user@example.com", "password": "correct-password"}
        )
    ).status_code == 429
    await redis.expire(otp.password_keys("user@example.com")[1], 0)
    assert (
        await client.post(
            "/api/v1/auth/login-password",
            json={"email": "user@example.com", "password": "correct-password"},
        )
    ).status_code == 200
    assert not await redis.exists(*otp.password_keys("user@example.com"))


async def test_delivery_failure_does_not_leave_valid_code(env, monkeypatch):
    class Broken:
        async def send(self, *args):
            raise RuntimeError("provider failed")

    monkeypatch.setattr(otp, "get_email_provider", Broken)
    response = await env[0].post("/api/v1/auth/request-access", json={"email": "new@example.com"})
    assert response.status_code == 503
    assert not await env[2].exists("otp:login:new@example.com")


async def test_redis_failure_is_closed(env, mail, monkeypatch):
    from redis.exceptions import ConnectionError

    async def down(*args):
        raise ConnectionError()

    monkeypatch.setattr(env[2], "eval", down)
    with pytest.raises(HTTPException) as error:
        await otp.consume_code(env[2], "new@example.com", "login", "123456")
    assert error.value.status_code == 503


async def test_console_provider_disabled_outside_development(monkeypatch):
    monkeypatch.setattr(get_settings(), "app_env", "production")
    with pytest.raises(RuntimeError):
        await ConsoleEmailProvider().send("test@example.com", "login", {"code": "123456"})
