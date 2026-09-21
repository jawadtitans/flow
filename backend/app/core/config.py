from functools import lru_cache
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import model_validator
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
    register_rate_limit: int = 5
    refresh_rate_limit: int = 30
    public_rate_limit: int = 120
    user_rate_limit: int = 300
    admin_rate_limit: int = 120
    sentry_dsn: str | None = None
    release: str = "development"
    smtp_host: str = "localhost"
    smtp_port: int = 1025
    smtp_username: str | None = None
    smtp_password: str | None = None
    smtp_starttls: bool = False
    smtp_use_tls: bool = False
    mail_from: str = "Flow <noreply@localhost>"
    public_app_url: str = "http://localhost:5173"
    fcm_project_id: str | None = None
    fcm_credentials_file: str | None = None
    push_enabled: bool = False
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def cors_origin_list(self) -> list[str]:
        return [
            origin.strip().rstrip("/") for origin in self.cors_origins.split(",") if origin.strip()
        ]

    @property
    def production(self) -> bool:
        return self.app_env == "production"

    @model_validator(mode="after")
    def validate_settings(self):
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
