import asyncio
import logging
import os
from collections import Counter
from typing import Any

from aiohttp import web
from aiogram import Bot, Dispatcher, F, types
from aiogram.filters import Command, CommandStart
from openai import AsyncOpenAI, APIConnectionError, APIStatusError, RateLimitError

from config import load_settings
from services.project_store import ProjectStore

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
settings = load_settings()
bot = Bot(token=settings.bot_token)
dp = Dispatcher()
store = ProjectStore()
client = AsyncOpenAI(api_key=settings.openai_api_key)

MANAGER_PROMPT = """Ты Senior iOS Engineer. Создай полноценный SwiftUI-проект на Swift 5.9+ с MVVM, NavigationStack и async/await. Не используй force unwrap, TODO, псевдокод и фразы об аналогичном коде. Сначала покажи дерево файлов, затем полный код каждого файла. Проверь импорты, типы, Binding, State, StateObject, EnvironmentObject и навигацию. Отвечай на русском. Не утверждай, что проект собран без фактической сборки."""
REVIEW_PROMPT = """Ты Principal iOS Code Reviewer. Проверяй только предоставленный Swift-код, не придумывай файлы и номера строк. Не повторяй замечания. Разделы: критические ошибки, возможные проблемы, архитектура, стиль, производительность, безопасность. Таблица: | Severity | Файл | Строка | Проблема | Исправление |. В конце дай итог и степень готовности. Отвечай на русском."""


def repetitive(text: str) -> bool:
    lines = [x.strip() for x in text.splitlines() if x.strip()]
    if len(lines) < 20:
        return False
    counts = Counter(lines)
    return len(counts) / len(lines) < 0.55 or counts.most_common(1)[0][1] >= 5


def _as_dict(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _as_dict(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_as_dict(item) for item in value]

    model_dump = getattr(value, "model_dump", None)
    if callable(model_dump):
        try:
            return _as_dict(model_dump(mode="json"))
        except TypeError:
            return _as_dict(model_dump())

    return value


def response_text(response: Any) -> str:
    """Извлекает текст из Responses API для разных версий OpenAI SDK."""
    direct = getattr(response, "output_text", None)
    if isinstance(direct, str) and direct.strip():
        return direct.strip()

    data = _as_dict(response)
    if not isinstance(data, dict):
        return ""

    direct = data.get("output_text")
    if isinstance(direct, str) and direct.strip():
        return direct.strip()

    parts: list[str] = []

    for output_item in data.get("output") or []:
        if not isinstance(output_item, dict):
            continue

        for content_item in output_item.get("content") or []:
            if not isinstance(content_item, dict):
                continue

            item_type = content_item.get("type")
            if item_type == "output_text":
                value = content_item.get("text")
                if isinstance(value, str) and value.strip():
                    parts.append(value.strip())
            elif item_type == "refusal":
                refusal = content_item.get("refusal")
                if isinstance(refusal, str) and refusal.strip():
                    parts.append(f"OpenAI отказался выполнить запрос: {refusal.strip()}")

    return "\n".join(parts).strip()


async def ask(prompt: str, task: str, model: str, max_tokens: int) -> str:
    status = "unknown"

    for attempt in range(2):
        suffix = "" if attempt == 0 else "\n\nВерни полный финальный ответ обычным текстом."
        response = await client.responses.create(
            model=model,
            instructions=prompt,
            input=task + suffix,
            max_output_tokens=max_tokens,
            reasoning={"effort": "low"},
        )

        status = str(getattr(response, "status", "unknown"))
        text = response_text(response)

        if text and not repetitive(text):
            return text

        data = _as_dict(response)
        output_summary = []
        if isinstance(data, dict):
            for item in data.get("output") or []:
                if not isinstance(item, dict):
                    continue
                output_summary.append(
                    {
                        "type": item.get("type"),
                        "status": item.get("status"),
                        "content_types": [
                            part.get("type")
                            for part in (item.get("content") or [])
                            if isinstance(part, dict)
                        ],
                    }
                )

        logger.warning(
            "OpenAI response has no usable text model=%s attempt=%s status=%s request_id=%s output=%s",
            model,
            attempt + 1,
            status,
            getattr(response, "_request_id", "unknown"),
            output_summary,
        )

        if attempt == 0:
            await asyncio.sleep(2)

    raise RuntimeError(
        f"Модель {model} завершила запрос, но текст ответа не найден. Статус: {status}"
    )


async def send_long(message: types.Message, text: str) -> None:
    for i in range(0, len(text), 3900):
        await message.answer(text[i:i + 3900])


async def show_error(status: types.Message, exc: Exception) -> None:
    logger.exception("OpenAI request failed")
    if isinstance(exc, RateLimitError):
        text = "❌ OpenAI ограничил запрос. Проверьте баланс и лимиты API."
    elif isinstance(exc, APIConnectionError):
        text = "❌ Нет соединения с OpenAI."
    elif isinstance(exc, APIStatusError):
        text = f"❌ Ошибка OpenAI: HTTP {exc.status_code}."
    else:
        text = f"❌ {exc}"
    await status.edit_text(text)


def save_requirements(user_id: int, text: str, append: bool = False):
    project = store.get(user_id)
    if not project:
        return None
    project.requirements = (
        project.requirements.rstrip()
        + "\n\nДополнительные требования:\n"
        + text.strip()
        if append and project.requirements
        else text.strip()
    )
    project.generated_code = ""
    project.review = ""
    store.save(project)
    return project


@dp.message(CommandStart())
async def start(message: types.Message) -> None:
    await message.answer(
        "👋 ИИ-помощник для iOS.\n"
        "/newproject Название\n"
        "/requirements Текст\n"
        "/status\n"
        "/generate — GPT-5\n"
        "/review — GPT-5 mini"
    )


@dp.message(Command("newproject"))
async def new_project(message: types.Message) -> None:
    name = (message.text or "").partition(" ")[2].strip()
    if not name:
        await message.answer("Укажите название: /newproject CaseonePOS")
        return
    project = store.create(message.from_user.id, name)
    await message.answer(f"✅ Проект «{project.name}» создан. Теперь отправьте требования.")


@dp.message(Command("requirements"))
async def requirements(message: types.Message) -> None:
    if not store.get(message.from_user.id):
        await message.answer("Сначала создайте проект: /newproject Название")
        return
    text = (message.text or "").partition(" ")[2].strip()
    if not text:
        await message.answer("Отправьте требования обычным сообщением.")
        return
    save_requirements(message.from_user.id, text)
    await message.answer("✅ Требования сохранены. Используйте /generate")


@dp.message(Command("status"))
async def status(message: types.Message) -> None:
    project = store.get(message.from_user.id)
    if not project:
        await message.answer("Активного проекта нет. Используйте /newproject")
        return
    await message.answer(
        f"📱 Проект: {project.name}\n"
        f"Требования: {'есть' if project.requirements else 'нет'}\n"
        f"Код: {'создан' if project.generated_code else 'не создан'}\n"
        f"Ревью: {'выполнено' if project.review else 'не выполнено'}\n"
        f"Генерация: {settings.generate_model}\n"
        f"Проверка: {settings.review_model}\n"
        "Провайдер: OpenAI"
    )


@dp.message(Command("generate"))
async def generate(message: types.Message) -> None:
    project = store.get(message.from_user.id)
    if not project or not project.requirements:
        await message.answer("Сначала создайте проект и добавьте требования.")
        return

    status_message = await message.answer(
        f"⏳ {settings.generate_model} создаёт код через OpenAI..."
    )
    task = (
        f"Проект: {project.name}\n"
        f"Требования: {project.requirements}\n"
        "Создай полноценную рабочую MVP-версию и полный код всех файлов."
    )

    try:
        project.generated_code = await ask(
            MANAGER_PROMPT,
            task,
            settings.generate_model,
            16000,
        )
        project.review = ""
        store.save(project)
        await status_message.delete()
        await send_long(message, project.generated_code)
    except Exception as exc:
        await show_error(status_message, exc)


@dp.message(Command("review"))
async def review(message: types.Message) -> None:
    project = store.get(message.from_user.id)
    if not project or not project.generated_code:
        await message.answer("Сначала создайте код командой /generate")
        return

    status_message = await message.answer(
        f"🔍 {settings.review_model} проверяет код через OpenAI..."
    )
    task = (
        f"Название проекта: {project.name}\n"
        f"Проведи строгое ревью кода:\n\n{project.generated_code}"
    )

    try:
        project.review = await ask(
            REVIEW_PROMPT,
            task,
            settings.review_model,
            8000,
        )
        store.save(project)
        await status_message.delete()
        await send_long(message, project.review)
    except Exception as exc:
        await show_error(status_message, exc)


@dp.message(F.text)
async def text(message: types.Message) -> None:
    value = (message.text or "").strip()
    if not value:
        return
    if value.startswith("/"):
        await message.answer("❌ Неизвестная команда. Используйте /start")
        return

    project = store.get(message.from_user.id)
    if not project:
        await message.answer("Сначала создайте проект: /newproject Название")
        return

    append = bool(project.requirements)
    save_requirements(message.from_user.id, value, append)
    await message.answer("✅ Требования обновлены. Используйте /generate")


async def health(_: web.Request) -> web.Response:
    return web.json_response(
        {
            "status": "ok",
            "provider": "openai",
            "generate_model": settings.generate_model,
            "review_model": settings.review_model,
        }
    )


async def health_server() -> web.AppRunner:
    app = web.Application()
    app.router.add_get("/", health)
    app.router.add_get("/health", health)
    runner = web.AppRunner(app)
    await runner.setup()
    await web.TCPSite(
        runner,
        "0.0.0.0",
        int(os.getenv("PORT", "3000")),
    ).start()
    return runner


async def main() -> None:
    runner = await health_server()
    try:
        await bot.delete_webhook(drop_pending_updates=True)
        await dp.start_polling(bot)
    finally:
        await runner.cleanup()
        await client.close()
        await bot.session.close()


if __name__ == "__main__":
    asyncio.run(main())
