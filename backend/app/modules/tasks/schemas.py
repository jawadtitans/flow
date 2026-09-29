from datetime import date, datetime, time
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.modules.tasks.models import Priority, TaskStatus


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=280)
    description: str | None = None
    priority: Priority = Priority.MEDIUM
    category_id: UUID | None = None
    due_date: date | None = None
    due_time: time | None = None
    estimated_duration: int | None = Field(default=None, ge=1)


class TaskUpdate(BaseModel):
    estimated_duration: int | None = Field(default=None, ge=1)
    title: str | None = Field(default=None, min_length=1, max_length=280)
    description: str | None = None
    priority: Priority | None = None
    category_id: UUID | None = None
    due_date: date | None = None
    due_time: time | None = None

    @field_validator("title", "priority")
    @classmethod
    def cannot_clear_required(cls, value):
        if value is None:
            raise ValueError("Cannot be null")
        return value


class TaskResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    title: str
    description: str | None
    status: TaskStatus
    priority: Priority
    category_id: UUID | None
    due_date: date | None
    due_time: time | None
    estimated_duration: int | None
    completed_at: datetime | None
    created_at: datetime
    updated_at: datetime


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")


class CategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    name: str
    color: str | None
