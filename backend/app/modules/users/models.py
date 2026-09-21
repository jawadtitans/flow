import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, func, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class User(Base):
    __tablename__ = "users"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(100))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default=text("true"))
    is_staff: Mapped[bool] = mapped_column(Boolean, default=False, server_default=text("false"))
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, server_default=text("false"))
    timezone: Mapped[str] = mapped_column(
        String(64), default="Asia/Kabul", server_default="Asia/Kabul"
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    tasks = relationship("Task", back_populates="user", cascade="all, delete-orphan")
