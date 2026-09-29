from collections.abc import AsyncIterator

from sqlalchemy import MetaData, event
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import NullPool

from app.core.config import get_settings

metadata = MetaData(
    naming_convention={
        "ix": "ix_%(column_0_label)s",
        "pk": "pk_%(table_name)s",
        "fk": "fk_%(table_name)s_%(referred_table_name)s",
        "uq": "uq_%(table_name)s_%(column_0_name)s",
        "ck": "ck_%(table_name)s_%(constraint_name)s",
    }
)


class Base(DeclarativeBase):
    metadata = metadata


def make_engine(url: str, *, pooler: bool = False):
    options = {"pool_pre_ping": True, "hide_parameters": True}
    if pooler:
        options["poolclass"] = NullPool
    engine = create_async_engine(url, **options)
    if url.startswith("sqlite"):

        @event.listens_for(engine.sync_engine, "connect")
        def enable_foreign_keys(connection, _):
            connection.execute("PRAGMA foreign_keys=ON")

    return engine


settings = get_settings()
engine = make_engine(settings.database_url, pooler=settings.database_pooler)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False, autoflush=False)


async def get_db() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
