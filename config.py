import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


DEFAULT_GENERATE_MODEL = "openai/gpt-5"
DEFAULT_REVIEW_MODEL = "openai/gpt-5-mini"


@dataclass(frozen=True)
class Settings:
    bot_token: str
    openrouter_api_key: str
    generate_model: str = DEFAULT_GENERATE_MODEL
    review_model: str = DEFAULT_REVIEW_MODEL


def load_settings() -> Settings:
    bot_token = os.getenv("BOT_TOKEN", "").strip()
    openrouter_api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
    generate_model = os.getenv(
        "OPENROUTER_GENERATE_MODEL",
        DEFAULT_GENERATE_MODEL,
    ).strip()
    review_model = os.getenv(
        "OPENROUTER_REVIEW_MODEL",
        DEFAULT_REVIEW_MODEL,
    ).strip()

    if not bot_token:
        raise RuntimeError("BOT_TOKEN не найден в переменных окружения")
    if not openrouter_api_key:
        raise RuntimeError("OPENROUTER_API_KEY не найден в переменных окружения")

    return Settings(
        bot_token=bot_token,
        openrouter_api_key=openrouter_api_key,
        generate_model=generate_model,
        review_model=review_model,
    )
