import base64
from io import BytesIO

from PIL import Image
from sqlalchemy import func, select

from app.modules.auth import otp
from app.modules.auth.models import AuthSession, RefreshToken
from app.modules.notifications.models import Device, Notification, PushDelivery
from app.modules.users.models import User
from tests.conftest import register


async def test_signup_password_and_persisted_onboarding(env, monkeypatch):
    client, _, _, _ = env
    codes = []

    class Mailbox:
        async def send(self, recipient, template, context):
            codes.append(context["code"])

    monkeypatch.setattr(otp, "get_email_provider", Mailbox)
    await client.post("/api/v1/auth/request-access", json={"email": "new@example.com"})
    tokens = (
        await client.post(
            "/api/v1/auth/verify-otp", json={"email": "new@example.com", "code": codes[-1]}
        )
    ).json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    assert not (await client.get("/api/v1/me", headers=headers)).json()["has_password"]
    path = "/api/v1/auth/set-password"
    assert (await client.post(path, json={"password": "a-long-password"})).status_code == 401
    assert (await client.post(path, headers=headers, json={"password": "short"})).status_code == 422
    response = await client.post(path, headers=headers, json={"password": "a-long-password"})
    assert response.status_code == 200, response.text
    assert response.json()["has_password"]
    assert (
        await client.post(path, headers=headers, json={"password": "another-password"})
    ).status_code == 409
    login = await client.post(
        "/api/v1/auth/login-password",
        json={"email": "new@example.com", "password": "a-long-password"},
    )
    assert login.status_code == 200
    answers = {
        "discovery_source": "Instagram",
        "interests": ["Technology", "Other"],
        "other_interest": "Architecture",
    }
    assert (
        await client.put("/api/v1/me/onboarding", headers=headers, json=answers)
    ).status_code == 409
    await client.patch(
        "/api/v1/auth/complete-profile",
        headers=headers,
        json={"first_name": "Amina", "last_name": "Ahmadi", "birth_date": "2000-02-29"},
    )
    response = await client.put("/api/v1/me/onboarding", headers=headers, json=answers)
    assert response.status_code == 200, response.text
    assert not response.json()["onboarding_completed"]
    for invalid in (
        {**answers, "interests": []},
        {**answers, "interests": ["unknown"]},
        {**answers, "discovery_source": "unknown"},
    ):
        assert (
            await client.put("/api/v1/me/onboarding", headers=headers, json=invalid)
        ).status_code == 422
    response = await client.put(
        "/api/v1/me/onboarding", headers=headers, json={**answers, "completed": True}
    )
    assert response.json()["onboarding_completed"]
    saved = (await client.get("/api/v1/me", headers=headers)).json()
    assert saved["interests"] == answers["interests"]
    assert saved["other_interest"] == "Architecture"
    assert "password_hash" not in saved


async def test_photo_is_validated_resized_private_and_removable(client, owner):
    other, _ = await register(client, "other@example.com")
    output = BytesIO()
    Image.new("RGB", (900, 600), "blue").save(output, format="PNG")
    photo = base64.b64encode(output.getvalue()).decode()
    response = await client.put("/api/v1/me/photo", headers=owner, json={"photo": photo})
    assert response.status_code == 200, response.text
    with Image.open(BytesIO(base64.b64decode(response.json()["profile_photo"]))) as image:
        assert image.format == "JPEG"
        assert max(image.size) == 512
    assert (await client.get("/api/v1/me", headers=other)).json()["profile_photo"] is None
    for invalid in ("not-base64", base64.b64encode(b"not an image").decode()):
        assert (
            await client.put("/api/v1/me/photo", headers=owner, json={"photo": invalid})
        ).status_code == 422
    assert (await client.put("/api/v1/me/photo", headers=owner, json={"photo": None})).json()[
        "profile_photo"
    ] is None


async def test_deletion_requires_confirmation_removes_data_and_revokes_sessions(env):
    client, factory, _, _ = env
    headers, tokens = await register(client)
    other, _ = await register(client, "other@example.com")
    category = (
        await client.post(
            "/api/v1/categories", headers=headers, json={"name": "Work", "color": "#112233"}
        )
    ).json()
    task = await client.post(
        "/api/v1/tasks",
        headers=headers,
        json={"title": "Private task", "category_id": category["id"]},
    )
    assert task.status_code == 201, task.text
    routine = await client.post(
        "/api/v1/routines",
        headers=headers,
        json={"name": "Morning", "steps": [{"title": "Plan", "position": 0}]},
    )
    assert routine.status_code == 201, routine.text
    run = await client.post(f"/api/v1/routines/{routine.json()['id']}/runs", headers=headers)
    assert run.status_code == 201, run.text
    reminder = await client.post(
        "/api/v1/reminders",
        headers=headers,
        json={"task_id": task.json()["id"], "remind_at": "2099-01-01T10:00:00Z"},
    )
    assert reminder.status_code == 201, reminder.text
    async with factory() as db:
        user = await db.scalar(select(User).where(User.email == "user@example.com"))
        notification = Notification(user_id=user.id, title="Private", body="Reminder")
        device = Device(user_id=user.id, token="private-device", platform="android")
        db.add_all([notification, device])
        await db.flush()
        db.add(PushDelivery(notification_id=notification.id, device_id=device.id))
        await db.commit()
    for payload in (
        {"confirmation": "delete", "acknowledge": True},
        {"confirmation": "Delete", "acknowledge": False},
    ):
        assert (
            await client.request("DELETE", "/api/v1/me", headers=headers, json=payload)
        ).status_code == 422
    assert (await client.get("/api/v1/me", headers=headers)).status_code == 200
    response = await client.request(
        "DELETE",
        "/api/v1/me",
        headers=headers,
        json={"confirmation": "Delete", "acknowledge": True},
    )
    assert response.status_code == 204, response.text
    assert (await client.get("/api/v1/me", headers=headers)).status_code == 401
    assert (
        await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    ).status_code == 401
    assert (await client.get("/api/v1/me", headers=other)).status_code == 200
    async with factory() as db:
        assert await db.scalar(select(func.count()).select_from(User)) == 1
        assert await db.scalar(select(func.count()).select_from(AuthSession)) == 1
        assert await db.scalar(select(func.count()).select_from(RefreshToken)) == 1
        for model in (Device, Notification, PushDelivery):
            assert await db.scalar(select(func.count()).select_from(model)) == 0
