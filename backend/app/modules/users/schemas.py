from datetime import date, datetime
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    email: str
    display_name: str
    first_name: str | None
    last_name: str | None
    birth_date: date | None
    profile_completed: bool
    has_password: bool
    social_auth: bool
    onboarding_completed: bool
    discovery_source: str | None
    interests: list[str]
    other_interest: str | None
    profile_photo: str | None
    email_verified: bool
    timezone: str
    is_staff: bool
    is_verified: bool
    is_active: bool
    created_at: datetime


class UserUpdate(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=100)
    timezone: str | None = Field(default=None, max_length=64)

    @field_validator("display_name", "timezone")
    @classmethod
    def not_blank(cls, value):
        if value is None or not value.strip():
            raise ValueError("Cannot be null or blank")
        return value.strip()

    @field_validator("timezone")
    @classmethod
    def timezone_exists(cls, value):
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise ValueError("Use a valid IANA timezone") from exc
        return value


class OnboardingUpdate(BaseModel):
    discovery_source: str = Field(min_length=1, max_length=80)
    interests: list[str] = Field(min_length=1, max_length=16)
    other_interest: str | None = Field(default=None, max_length=120)
    completed: bool = False

    @field_validator("discovery_source")
    @classmethod
    def valid_source(cls, value):
        if value not in {
            "Instagram",
            "TikTok",
            "YouTube",
            "Facebook",
            "X",
            "LinkedIn",
            "Telegram",
            "Friend",
            "Other",
        }:
            raise ValueError("Choose a discovery source")
        return value

    @field_validator("interests")
    @classmethod
    def valid_interests(cls, value):
        allowed = {
            "Technology",
            "AI",
            "Design",
            "Business",
            "Productivity",
            "Education",
            "Science",
            "Health",
            "Fitness",
            "Food",
            "Travel",
            "Music",
            "Art",
            "Gaming",
            "Books",
            "Other",
        }
        if len(set(value)) != len(value) or not set(value) <= allowed:
            raise ValueError("Choose valid, unique interests")
        return value


class ProfilePhotoUpdate(BaseModel):
    photo: str | None = Field(default=None, max_length=700000)


class DeleteAccountRequest(BaseModel):
    confirmation: str = Field(pattern=r"^Delete$")
    acknowledge: bool
