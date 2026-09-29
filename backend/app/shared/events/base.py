from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any


@dataclass(frozen=True)
class DomainEvent:
    name: str
    payload: dict[str, Any]
    occurred_at: datetime = field(default_factory=lambda: datetime.now(UTC))


class EventBus:
    """In-process adapter; replace with Redis streams without changing services."""

    def publish(self, event: DomainEvent) -> None:
        pass
