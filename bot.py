import asyncio
import logging
import os

from aiogram import Bot, Dispatcher, F, types
from aiogram.filters import Command, CommandStart
from agents import Runner

from agents.team import create_manager_agent
from config import load_settings
from services.project_store import ProjectStore

logging.basicConfig(level=logging.INFO)

settings = load_settings()
os.environ["OPENAI_API_KEY"] = settings.openai_api_key

bot = Bot(token=settings.bot_token)
dp = Dispatcher()
manager_agent = create_manager_agent(settings.openai_model)
store = ProjectStore()


async def send_long(message: types.Message, text: str) -> None:
    for start in range(0, len(text), 4000):
        await message.answer(text[start : start + 4000])


@dp.message(CommandStart())
async def start_handler(message: types.Message) -> None:
    await message.answer(
        "👋 Я команда ИИ-агентов для разработки iPhone-приложений.\n\n"
        "Команды:\n"
        "/newproject Название — создать проект\n"
        "/requirements Текст — сохранить требования\n"
        "/status — показать состояние проекта\n"
        "/generate — подготовить SwiftUI-код\n"
        "/review — проверить созданный код\n\n"
        "Начните с команды: /newproject Название приложения"
    )


@dp.message(Command("newproject"))
async def new_project_handler(message: types.Message) -> None:
    name = (message.text or "").partition(" ")[2].strip()
    if not name:
        await message.answer("Укажите название: /newproject Kolibri App")
        return
    project = store.create(message.from_user.id, name)
    await message.answer(
        f"✅ Проект «{project.name}» создан.\n"
        "Теперь отправьте требования командой /requirements"
    )


@dp.message(Command("requirements"))
async def requirements_handler(message: types.Message) -> None:
    project = store.get(message.from_user.id)
    if project is None:
        await message.answer("Сначала создайте проект: /newproject Название")
        return
    requirements = (message.text or "").partition(" ")[2].strip()
    if not requirements:
        await message.answer("После команды добавьте описание приложения.")
        return
    project.requirements = requirements
    project.generated_code = ""
    project.review = ""
    store.save(project)
    await message.answer("✅ Требования сохранены. Для генерации используйте /generate")


@dp.message(Command("status"))
async def status_handler(message: types.Message) -> None:
    project = store.get(message.from_user.id)
    if project is None:
        await message.answer("Активного проекта нет. Используйте /newproject")
        return
    await message.answer(
        f"📱 Проект: {project.name}\n"
        f"Требования: {'есть' if project.requirements else 'не добавлены'}\n"
        f"Код: {'создан' if project.generated_code else 'не создан'}\n"
        f"Ревью: {'выполнено' if project.review else 'не выполнено'}"
    )


@dp.message(Command("generate"))
async def generate_handler(message: types.Message) -> None:
    project = store.get(message.from_user.id)
    if project is None or not project.requirements:
        await message.answer("Сначала создайте проект и добавьте требования.")
        return
    status = await message.answer("⏳ Агенты создают структуру и SwiftUI-код...")
    prompt = (
        f"Проект: {project.name}\n"
        f"Требования: {project.requirements}\n\n"
        "Создай первую рабочую MVP-версию. Перечисли файлы и дай полный код. "
        "После этого обязательно выполни code review."
    )
    try:
        result = await Runner.run(manager_agent, prompt, max_turns=10)
        project.generated_code = str(result.final_output).strip()
        store.save(project)
        await status.delete()
        await send_long(message, project.generated_code or "Код не был сформирован.")
    except Exception as exc:
        logging.exception("Generation failed")
        await status.edit_text(f"❌ Ошибка генерации: {type(exc).__name__}")


@dp.message(Command("review"))
async def review_handler(message: types.Message) -> None:
    project = store.get(message.from_user.id)
    if project is None or not project.generated_code:
        await message.answer("Сначала создайте код командой /generate")
        return
    status = await message.answer("🔍 Агент проверяет проект...")
    prompt = (
        "Проведи отдельное строгое ревью следующего SwiftUI-проекта. "
        "Найди ошибки компиляции, архитектуры, состояния и безопасности. "
        "Дай исправления и итоговый вердикт.\n\n"
        + project.generated_code
    )
    try:
        result = await Runner.run(manager_agent, prompt, max_turns=8)
        project.review = str(result.final_output).strip()
        store.save(project)
        await status.delete()
        await send_long(message, project.review or "Ревью не сформировано.")
    except Exception as exc:
        logging.exception("Review failed")
        await status.edit_text(f"❌ Ошибка проверки: {type(exc).__name__}")


@dp.message(F.text)
async def text_handler(message: types.Message) -> None:
    await message.answer(
        "Используйте команды /newproject, /requirements, /status, /generate или /review."
    )


async def main() -> None:
    await bot.delete_webhook(drop_pending_updates=True)
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
