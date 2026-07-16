import asyncio
import logging
import os

from aiogram import Bot, Dispatcher, F, types
from aiogram.filters import CommandStart
from agents import Runner

from agents.team import create_manager_agent
from config import load_settings

logging.basicConfig(level=logging.INFO)

settings = load_settings()
os.environ["OPENAI_API_KEY"] = settings.openai_api_key

bot = Bot(token=settings.bot_token)
dp = Dispatcher()
manager_agent = create_manager_agent(settings.openai_model)


@dp.message(CommandStart())
async def start_handler(message: types.Message) -> None:
    await message.answer(
        "👋 Я команда ИИ-агентов для разработки iPhone-приложений.\n\n"
        "Опишите приложение, которое хотите создать. Например:\n"
        "Создай приложение доставки для ресторана с каталогом, корзиной и заказом."
    )


@dp.message(F.text)
async def text_handler(message: types.Message) -> None:
    user_text = (message.text or "").strip()
    if not user_text:
        return

    status = await message.answer("⏳ ИИ-команда анализирует задачу...")

    try:
        result = await Runner.run(
            manager_agent,
            user_text,
            max_turns=8,
        )
        answer = str(result.final_output).strip()
        if not answer:
            answer = "Агенты завершили работу без текстового ответа."

        await status.delete()

        # Telegram ограничивает длину одного сообщения.
        for start in range(0, len(answer), 4000):
            await message.answer(answer[start : start + 4000])
    except Exception as exc:
        logging.exception("Agent execution failed")
        await status.edit_text(
            "❌ Не удалось выполнить запрос. Проверьте OPENAI_API_KEY и журнал сервера.\n"
            f"Ошибка: {type(exc).__name__}"
        )


async def main() -> None:
    await bot.delete_webhook(drop_pending_updates=True)
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
