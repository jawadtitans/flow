from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class DeviceCreate(BaseModel):
    token: str = Field(min_length=20, max_length=4096)
    platform: Literal["android", "ios", "web"]


class DeviceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    platform: str
    is_active: bool
    updated_at: datetime


class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    reminder_id: UUID | None
    title: str
    body: str
    read_at: datetime | None
    created_at: datetime


class NotificationPage(BaseModel):
    items: list[NotificationResponse]
    total: int
    unread: int
    limit: int
    offset: int
