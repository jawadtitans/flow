from datetime import datetime, time
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class RoutineStepCreate(BaseModel):
    title: str = Field(min_length=1, max_length=280)
    position: int = Field(ge=0)
    offset_minutes: int = Field(default=0, ge=0)


class RoutineCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    description: str | None = None
    start_time: time | None = None
    steps: list[RoutineStepCreate] = Field(default_factory=list, max_length=100)

    @field_validator("steps")
    @classmethod
    def unique_positions(cls, value):
        if len({step.position for step in value}) != len(value):
            raise ValueError("Step positions must be unique")
        return value


class RoutineUpdate(RoutineCreate):
    is_active: bool = True


class RoutineStepResponse(RoutineStepCreate):
    model_config = ConfigDict(from_attributes=True)
    id: UUID


class RoutineResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    name: str
    description: str | None
    start_time: time | None
    is_active: bool
    steps: list[RoutineStepResponse]


class RunStepResponse(RoutineStepResponse):
    completed_at: datetime | None


class RunResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    routine_id: UUID | None
    name: str
    status: str
    started_at: datetime
    completed_at: datetime | None
    steps: list[RunStepResponse]
