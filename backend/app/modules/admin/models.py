import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class AdminAudit(Base):
    __tablename__ = "admin_audit"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    actor_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", name="fk_admin_audit_actor_users"), index=True
    )
    target_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", name="fk_admin_audit_target_users"), index=True
    )
    action: Mapped[str] = mapped_column(String(40))
    request_id: Mapped[str] = mapped_column(String(128))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
