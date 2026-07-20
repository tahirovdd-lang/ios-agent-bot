import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


DEFAULT_OPENROUTER_MODEL = "cohere/north-mini-code:free"


@dataclass(frozen=True)
class Settings:
    bot_token: str
    openrouter_api_key: str
    openrouter_model: str = DEFAULT_OPENROUTER_MODEL


def load_settings() -> Settings:
    bot_token = os.getenv("BOT_TOKEN", "").strip()
    openrouter_api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
    openrouter_model = os.getenv(
        "OPENROUTER_MODEL",
        DEFAULT_OPENROUTER_MODEL,
    ).strip()

    if not bot_token:
        raise RuntimeError("BOT_TOKEN не найден в переменных окружения")
    if not openrouter_api_key:
        raise RuntimeError("OPENROUTER_API_KEY не найден в переменных окружения")

    return Settings(
        bot_token=bot_token,
        openrouter_api_key=openrouter_api_key,
        openrouter_model=openrouter_model,
    )
