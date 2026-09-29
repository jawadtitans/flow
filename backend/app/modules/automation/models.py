from dataclasses import dataclass, field
from typing import Any, Protocol


@dataclass
class WorkflowContext:
    user_id: str
    event: str
    data: dict[str, Any] = field(default_factory=dict)


class Trigger(Protocol):
    def matches(self, context: WorkflowContext) -> bool: ...


class Condition(Protocol):
    def allows(self, context: WorkflowContext) -> bool: ...


class Action(Protocol):
    def execute(self, context: WorkflowContext) -> None: ...
