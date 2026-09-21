from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class ToolDefinition:
    tool_name: str
    description: str
    input_schema: dict[str, Any]
    permission_level: str = "user"
    requires_confirmation: bool = True


# Tools are intent declarations only. Application services execute approved requests.
CREATE_TASK_TOOL = ToolDefinition(
    "create_task",
    "Create a task for the current user",
    {"title": "string"},
    requires_confirmation=False,
)
