import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    bot_token: str
    openai_api_key: str
    openai_model: str = "gpt-5.2"


def load_settings() -> Settings:
    bot_token = os.getenv("BOT_TOKEN", "").strip()
    openai_api_key = os.getenv("OPENAI_API_KEY", "").strip()
    openai_model = os.getenv("OPENAI_MODEL", "gpt-5.2").strip()

    if not bot_token:
        raise RuntimeError("BOT_TOKEN не найден в переменных окружения")
    if not openai_api_key:
        raise RuntimeError("OPENAI_API_KEY не найден в переменных окружения")

    return Settings(
        bot_token=bot_token,
        openai_api_key=openai_api_key,
        openai_model=openai_model,
    )
