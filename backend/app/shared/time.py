from datetime import UTC, datetime
from zoneinfo import ZoneInfo


def utcnow() -> datetime:
    return datetime.now(UTC)


def aware(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


def local_today(timezone: str):
    return utcnow().astimezone(ZoneInfo(timezone)).date()
