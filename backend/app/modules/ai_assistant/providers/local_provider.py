from app.modules.ai_assistant.providers.base import AIProvider


class LocalProvider(AIProvider):
    async def structured(self, prompt: str, schema: dict) -> dict:
        return {"intent": "unsupported", "requires_confirmation": False}
