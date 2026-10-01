import uuid
from datetime import date, datetime

from sqlalchemy import JSON, Boolean, Date, DateTime, String, Text, func, text
from sqlalchemy.orm import Mapped, mapped_column, relationship, synonym

from app.core.database import Base


class User(Base):
    __tablename__ = "users"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    display_name: Mapped[str] = mapped_column(String(100), default="", server_default="")
    first_name: Mapped[str | None] = mapped_column(String(50))
    last_name: Mapped[str | None] = mapped_column(String(49))
    birth_date: Mapped[date | None] = mapped_column(Date)
    profile_completed: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=text("false")
    )
    onboarding_completed: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=text("false")
    )
    discovery_source: Mapped[str | None] = mapped_column(String(80))
    interests: Mapped[list[str]] = mapped_column(JSON, default=list, server_default="[]")
    other_interest: Mapped[str | None] = mapped_column(String(120))
    profile_photo: Mapped[str | None] = mapped_column(Text)

    @property
    def has_password(self) -> bool:
        return bool(self.password_hash)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default=text("true"))
    is_staff: Mapped[bool] = mapped_column(Boolean, default=False, server_default=text("false"))
    email_verified: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=text("false")
    )
    # Existing dashboard and account-verification code keep their public alias.
    is_verified = synonym("email_verified")
    timezone: Mapped[str] = mapped_column(
        String(64), default="Asia/Kabul", server_default="Asia/Kabul"
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    tasks = relationship("Task", back_populates="user", cascade="all, delete-orphan")
