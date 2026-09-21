from app.modules.ai_assistant.providers.base import AIProvider


class OpenAIProvider(AIProvider):
    async def structured(self, prompt: str, schema: dict) -> dict:
        raise NotImplementedError(
            "Configure an OpenAI client adapter before enabling this provider"
        )
