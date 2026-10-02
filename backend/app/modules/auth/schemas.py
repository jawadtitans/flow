from datetime import date

from pydantic import BaseModel, EmailStr, Field, field_validator


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=100)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str | None = Field(default=None, max_length=4096)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"


class EmailRequest(BaseModel):
    email: EmailStr


class AccountTokenRequest(BaseModel):
    token: str = Field(min_length=20, max_length=256)


class ResetPasswordRequest(AccountTokenRequest):
    password: str = Field(min_length=12, max_length=128)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    password: str = Field(min_length=12, max_length=128)


class SetPasswordRequest(BaseModel):
    password: str = Field(min_length=12, max_length=128)


class AccessResponse(BaseModel):
    email: str
    account_exists: bool
    has_password: bool


class OtpRequest(EmailRequest):
    code: str = Field(pattern=r"^[0-9]{6}$")


class GoogleAuthRequest(BaseModel):
    access_token: str = Field(min_length=20, max_length=4096)


class OtpResetRequest(OtpRequest):
    new_password: str = Field(min_length=12, max_length=128)


class AuthTokenResponse(TokenResponse):
    profile_completed: bool


class CompleteProfileRequest(BaseModel):
    first_name: str = Field(min_length=1, max_length=50)
    last_name: str = Field(min_length=1, max_length=49)
    birth_date: date

    @field_validator("first_name", "last_name")
    @classmethod
    def clean_name(cls, value):
        value = value.strip()
        if not value:
            raise ValueError("Name cannot be blank")
        return value

    @field_validator("birth_date")
    @classmethod
    def valid_birth_date(cls, value):
        if value > date.today() or value < date(1900, 1, 1):
            raise ValueError("Birth date must be between 1900 and today")
        return value
