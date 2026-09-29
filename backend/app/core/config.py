from email.utils import parseaddr
from functools import lru_cache
from typing import Literal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import AliasChoices, EmailStr, Field, SecretStr, TypeAdapter, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "development"
    database_url: str = "sqlite+aiosqlite:///./flow.db"
    migration_database_url: str | None = None
    database_pooler: bool = False
    redis_url: str = "redis://localhost:6379/0"
    rate_limit_redis_url: str = "redis://localhost:6379/1"
    celery_broker_url: str = "redis://localhost:6379/2"
    celery_result_backend: str = "redis://localhost:6379/3"
    jwt_secret: str = "unsafe-development-secret"
    jwt_refresh_secret: str = "unsafe-development-refresh-secret"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30
    cors_origins: str = "http://localhost:5173,http://localhost:8080"
    reporting_timezone: str = "Asia/Kabul"
    cache_ttl_seconds: int = 20
    auth_rate_limit: int = 10
    auth_email_rate_limit: int = 5
    otp_email_rate_limit: int = 3
    otp_ip_rate_limit: int = 20
    otp_expiry_minutes: int = 10
    email_provider: Literal["console", "resend", "brevo", "smtp"] = "console"
    resend_api_key: str | None = None
    brevo_api_key: SecretStr | None = None
    brevo_sender_email: str | None = None
    brevo_sender_name: str | None = Field(
        default=None, validation_alias=AliasChoices("brevo_sender_name", "email_from_name")
    )
    smtp_host: str = "localhost"
    smtp_port: int = 587
    smtp_username: str | None = None
    smtp_password: str | None = None
    smtp_starttls: bool = True
    smtp_use_tls: bool = False
    otp_mail_from: str = "Flow <noreply@flow.af>"
    register_rate_limit: int = 5
    refresh_rate_limit: int = 30
    public_rate_limit: int = 120
    user_rate_limit: int = 300
    admin_rate_limit: int = 120
    sentry_dsn: str | None = None
    release: str = "development"
    mail_from: str = Field(
        default="Flow <noreply@flow.af>",
        validation_alias=AliasChoices("mail_from", "email_from"),
    )
    public_app_url: str = "http://localhost:5173"
    fcm_project_id: str | None = None
    fcm_credentials_file: str | None = None
    push_enabled: bool = False
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", hide_input_in_errors=True)

    @property
    def cors_origin_list(self) -> list[str]:
        return [
            origin.strip().rstrip("/") for origin in self.cors_origins.split(",") if origin.strip()
        ]

    @property
    def production(self) -> bool:
        return self.app_env == "production"

    @property
    def brevo_sender(self) -> dict[str, str]:
        name, address = parseaddr(self.mail_from)
        address = (self.brevo_sender_email or address).strip()
        try:
            address = str(TypeAdapter(EmailStr).validate_python(address))
        except ValueError:
            raise ValueError(
                "BREVO_SENDER_EMAIL or MAIL_FROM must contain a valid sender email"
            ) from None
        return {"email": address, "name": self.brevo_sender_name or name or "Flow"}

    @model_validator(mode="after")
    def validate_settings(self):
        if self.email_provider == "brevo":
            if not self.brevo_api_key or not self.brevo_api_key.get_secret_value().strip():
                raise ValueError("BREVO_API_KEY is required when EMAIL_PROVIDER=brevo")
            _ = self.brevo_sender  # Validate the sender before accepting Brevo configuration.
        if self.email_provider == "smtp":
            if not self.smtp_host.strip():
                raise ValueError("SMTP_HOST is required when EMAIL_PROVIDER=smtp")
            if not self.smtp_username or not self.smtp_username.strip():
                raise ValueError("SMTP_USERNAME is required when EMAIL_PROVIDER=smtp")
            if not self.smtp_password or not self.smtp_password.strip():
                raise ValueError("SMTP_PASSWORD is required when EMAIL_PROVIDER=smtp")
        try:
            ZoneInfo(self.reporting_timezone)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("REPORTING_TIMEZONE must be an IANA timezone") from exc
        if self.production:
            for secret in (self.jwt_secret, self.jwt_refresh_secret):
                if len(secret) < 32 or secret.startswith(("unsafe-", "change-")):
                    raise ValueError(
                        "Production JWT secrets must be unique random strings of at least 32 characters"
                    )
            if self.jwt_secret == self.jwt_refresh_secret:
                raise ValueError("Access and refresh secrets must differ")
            if not self.database_url.startswith("postgresql+asyncpg://"):
                raise ValueError("Production requires PostgreSQL with asyncpg")
            if not self.public_app_url.startswith("https://"):
                raise ValueError("PUBLIC_APP_URL must use HTTPS in production")
            if any(not origin.startswith("https://") for origin in self.cors_origin_list):
                raise ValueError("Production CORS origins must use HTTPS")
        if self.push_enabled and not (self.fcm_project_id and self.fcm_credentials_file):
            raise ValueError(
                "FCM_PROJECT_ID and FCM_CREDENTIALS_FILE are required when push is enabled"
            )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
