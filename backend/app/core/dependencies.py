from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db
from app.core.security import decode_token
from app.modules.auth.models import AuthSession
from app.modules.users.models import User
from app.shared.rate_limit import limit
from app.shared.time import utcnow

bearer = HTTPBearer(auto_error=False)


async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    try:
        if not credentials:
            raise ValueError("Missing token")
        payload = decode_token(credentials.credentials, "access")
        user_id, session_id = UUID(payload["sub"]), UUID(payload["sid"])
    except (jwt.PyJWTError, ValueError, KeyError, TypeError):
        raise HTTPException(
            401, "Invalid authentication credentials", headers={"WWW-Authenticate": "Bearer"}
        ) from None
    user = await db.scalar(
        select(User)
        .join(AuthSession, AuthSession.user_id == User.id)
        .where(
            User.id == user_id,
            User.is_active.is_(True),
            AuthSession.id == session_id,
            AuthSession.revoked_at.is_(None),
            AuthSession.expires_at > utcnow(),
        )
    )
    if user is None:
        raise HTTPException(401, "User session is unavailable")
    request.state.user_id = str(user.id)
    request.state.session_id = session_id
    if not request.url.path.startswith("/api/v1/admin"):
        await limit(request, "user", str(user.id), get_settings().user_rate_limit)
    return user


async def require_staff(request: Request, user: User = Depends(get_current_user)) -> User:
    if not user.is_staff:
        raise HTTPException(403, "Staff access required")
    await limit(request, "staff", str(user.id), get_settings().admin_rate_limit)
    return user
