from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import AuthSession
from app.modules.users.models import User
from app.shared.time import utcnow


async def find_user(db: AsyncSession, email: str):
    return await db.scalar(select(User).where(User.email == email.lower()))


async def revoke_sessions(db: AsyncSession, user_id):
    await db.execute(
        update(AuthSession)
        .where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=utcnow())
    )
