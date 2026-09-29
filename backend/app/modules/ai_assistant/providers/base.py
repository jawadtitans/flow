from abc import ABC, abstractmethod
from typing import Any


class AIProvider(ABC):
    @abstractmethod
    async def structured(self, prompt: str, schema: dict[str, Any]) -> dict[str, Any]: ...
