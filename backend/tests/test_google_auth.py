from sqlalchemy import select

from app.modules.auth import service
from app.modules.users.models import User
from tests.conftest import register


async def test_google_login_creates_flow_session_and_profile(env, monkeypatch):
    client, factory, _, _ = env

    async def verified_identity(access_token):
        assert access_token == "supabase-access-token"
        return "google@example.com", "Google User"

    monkeypatch.setattr(service, "verify_google_access_token", verified_identity)
    response = await client.post(
        "/api/v1/auth/google",
        json={"access_token": "supabase-access-token"},
    )
    assert response.status_code == 200, response.text
    tokens = response.json()
    assert tokens["access_token"]
    assert tokens["refresh_token"]
    assert tokens["profile_completed"] is False

    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    profile = await client.get("/api/v1/me", headers=headers)
    assert profile.status_code == 200
    assert profile.json()["email"] == "google@example.com"
    assert profile.json()["display_name"] == "Google User"
    assert profile.json()["first_name"] == "Google"
    assert profile.json()["last_name"] == "User"
    assert profile.json()["email_verified"] is True
    assert profile.json()["social_auth"] is True
    assert profile.json()["has_password"] is False

    access = await client.post(
        "/api/v1/auth/request-access",
        json={"email": "google@example.com"},
    )
    assert access.json()["has_password"] is False

    async with factory() as db:
        user = await db.scalar(select(User).where(User.email == "google@example.com"))
        assert user is not None
        assert user.password_hash is None
        assert user.social_auth is True


async def test_google_login_links_verified_existing_account(env, monkeypatch):
    client, factory, _, _ = env
    await register(client, "google@example.com")

    async def verified_identity(_access_token):
        return "google@example.com", "Google Profile"

    monkeypatch.setattr(service, "verify_google_access_token", verified_identity)
    response = await client.post(
        "/api/v1/auth/google",
        json={"access_token": "supabase-access-token"},
    )
    assert response.status_code == 200, response.text
    headers = {"Authorization": f"Bearer {response.json()['access_token']}"}
    profile = await client.get("/api/v1/me", headers=headers)
    assert profile.json()["has_password"] is True
    assert profile.json()["social_auth"] is True
    assert profile.json()["display_name"] == "Flow User"
    assert profile.json()["first_name"] == "Google"
    assert profile.json()["last_name"] == "Profile"

    async with factory() as db:
        users = (await db.scalars(select(User))).all()
        assert len(users) == 1
        assert users[0].password_hash is not None
