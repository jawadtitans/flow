import uuid
from datetime import date, datetime, time
from enum import StrEnum

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Index, Integer, String, Text, Time, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class TaskStatus(StrEnum):
    PENDING = "pending"
    COMPLETED = "completed"


class Priority(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class Category(Base):
    __tablename__ = "task_categories"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    color: Mapped[str | None] = mapped_column(String(7), nullable=True)


class Task(Base):
    __tablename__ = "tasks"
    __table_args__ = (
        Index("ix_tasks_user_due", "user_id", "due_date"),
        Index("ix_tasks_user_completed", "user_id", "completed_at"),
    )
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(280))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Keep legacy uppercase database values; public JSON remains lowercase.
    status: Mapped[TaskStatus] = mapped_column(
        Enum(TaskStatus, native_enum=False, length=20), default=TaskStatus.PENDING
    )
    priority: Mapped[Priority] = mapped_column(
        Enum(Priority, native_enum=False, length=20), default=Priority.MEDIUM
    )
    category_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("task_categories.id", ondelete="SET NULL"), nullable=True
    )
    due_date: Mapped[date | None] = mapped_column(Date, index=True, nullable=True)
    due_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    estimated_duration: Mapped[int | None] = mapped_column(Integer, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    user = relationship("User", back_populates="tasks")
