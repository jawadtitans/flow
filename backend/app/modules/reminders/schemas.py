from datetime import datetime
from uuid import UUID

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field


class ReminderCreate(BaseModel):
    remind_at: AwareDatetime
    task_id: UUID | None = None
    message: str | None = Field(default=None, max_length=280)


class ReminderUpdate(BaseModel):
    remind_at: AwareDatetime
    message: str | None = Field(default=None, max_length=280)


class ReminderResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    task_id: UUID | None
    remind_at: datetime
    message: str | None
    is_sent: bool
    cancelled_at: datetime | None
    sent_at: datetime | None
    created_at: datetime
