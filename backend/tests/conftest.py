import os

os.environ.update(
    {
        "APP_ENV": "testing",
        "DATABASE_URL": "sqlite+aiosqlite:///:memory:",
        "JWT_SECRET": "test-secret-with-at-least-thirty-two-characters",
        "JWT_REFRESH_SECRET": "test-refresh-secret-with-at-least-thirty-two-characters",
        "AUTH_RATE_LIMIT": "1000",
        "AUTH_EMAIL_RATE_LIMIT": "1000",
        "REGISTER_RATE_LIMIT": "1000",
        "REFRESH_RATE_LIMIT": "1000",
        "PUBLIC_RATE_LIMIT": "10000",
        "USER_RATE_LIMIT": "10000",
        "ADMIN_RATE_LIMIT": "10000",
    }
)

import pytest
from fakeredis.aioredis import FakeRedis
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core.database import Base, get_db, make_engine
from app.main import create_app


@pytest.fixture
async def env(tmp_path):
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'test.db'}")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    app = create_app()
    fake = FakeRedis(decode_responses=True)
    for name in ("redis", "limiter", "broker", "results"):
        setattr(app.state, name, fake)

    async def override_db():
        async with factory() as db:
            yield db

    app.dependency_overrides[get_db] = override_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        yield client, factory, fake, app
    await fake.aclose()
    await engine.dispose()


@pytest.fixture
async def client(env):
    return env[0]


async def register(client, email="user@example.com"):
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "correct-password", "display_name": "Flow User"},
    )
    assert response.status_code == 201, response.text
    tokens = response.json()
    return {"Authorization": f"Bearer {tokens['access_token']}"}, tokens


@pytest.fixture
async def owner(client):
    return (await register(client))[0]


@pytest.fixture
async def staff(env):
    from sqlalchemy import select

    from app.modules.users.models import User

    headers, _ = await register(env[0], "staff@example.com")
    async with env[1]() as db:
        user = await db.scalar(select(User).where(User.email == "staff@example.com"))
        user.is_staff = True
        await db.commit()
    return headers
