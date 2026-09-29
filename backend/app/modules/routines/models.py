import uuid
from datetime import datetime, time

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    Time,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Routine(Base):
    __tablename__ = "routines"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    start_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default=text("true"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    steps = relationship(
        "RoutineStep",
        back_populates="routine",
        cascade="all, delete-orphan",
        order_by="RoutineStep.position",
        lazy="raise",
    )


class RoutineStep(Base):
    __tablename__ = "routine_steps"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    routine_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("routines.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(280))
    position: Mapped[int] = mapped_column(Integer)
    offset_minutes: Mapped[int] = mapped_column(Integer, default=0)
    routine = relationship("Routine", back_populates="steps")


class RoutineRun(Base):
    __tablename__ = "routine_runs"
    __table_args__ = (UniqueConstraint("user_id", "idempotency_key"),)
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    routine_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("routines.id", ondelete="SET NULL"), index=True
    )
    name: Mapped[str] = mapped_column(String(160))
    idempotency_key: Mapped[str] = mapped_column(String(128))
    status: Mapped[str] = mapped_column(String(16), default="active")
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    steps = relationship(
        "RoutineRunStep",
        cascade="all, delete-orphan",
        order_by="RoutineRunStep.position",
        lazy="raise",
    )


class RoutineRunStep(Base):
    __tablename__ = "routine_run_steps"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    run_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("routine_runs.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(280))
    position: Mapped[int] = mapped_column(Integer)
    offset_minutes: Mapped[int] = mapped_column(Integer, default=0)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
