import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, String, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Reminder(Base):
    __tablename__ = "reminders"
    __table_args__ = (Index("ix_reminders_due_pending", "is_sent", "cancelled_at", "remind_at"),)
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    task_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("tasks.id", ondelete="CASCADE"), nullable=True
    )
    remind_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    message: Mapped[str | None] = mapped_column(String(280), nullable=True)
    is_sent: Mapped[bool] = mapped_column(Boolean, default=False, server_default=text("false"))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
