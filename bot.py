import asyncio
import logging
import os
from collections import Counter

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

openrouter_client = AsyncOpenAI(
    api_key=settings.openrouter_api_key,
    base_url="https://openrouter.ai/api/v1",
    default_headers={
        "HTTP-Referer": "https://github.com/tahirovdd-lang/ios-agent-bot",
        "X-Title": "iOS Agent Bot",
    },
)

MANAGER_SYSTEM_PROMPT = """
Ты — Senior iOS Engineer и Software Architect с опытом коммерческой разработки более 15 лет.
Создавай полноценные, логически завершённые iOS-проекты для Xcode на Swift 5.9+ и SwiftUI.
Используй MVVM, NavigationStack, async/await и современные API Apple.
Для финансовых значений используй Decimal.
Не используй force unwrap, псевдокод, TODO и фразы «остальной код аналогичен».
Не ссылайся на несуществующие типы, методы, свойства, изображения или зависимости.
Сначала покажи дерево файлов, затем полный код каждого файла отдельно.
Перед ответом проверь импорты, типы, инициализаторы, Binding, State, StateObject,
EnvironmentObject, async/await и маршруты навигации.
Отвечай только на русском языке.
Не утверждай, что проект собран в Xcode, если сборка не выполнялась.
""".strip()

REVIEW_SYSTEM_PROMPT = """
Ты — Principal iOS Engineer и Senior Code Reviewer.
Проведи строгое ревью только предоставленного Swift-кода.
Не придумывай отсутствующие файлы, типы, зависимости и номера строк.
Не показывай внутренние рассуждения и не пиши служебные фразы вроде «We need to ensure».
Не повторяй одинаковые предложения или замечания.

Разделы ответа:
1. Критические ошибки
2. Возможные проблемы
3. Архитектурные замечания
4. Стиль кода
5. Производительность
6. Безопасность

Для замечаний используй таблицу:
| Severity | Файл | Строка | Проблема | Исправление |
Severity: Critical, Major, Minor, Info.
Если строка неизвестна, укажи «не указана».
Если замечаний нет, напиши «Подтверждённых замечаний не обнаружено.»
Не утверждай, что проект компилируется, если сборка не выполнялась.
В конце выведи количество критических ошибок, потенциальных проблем,
архитектурных рекомендаций и степень готовности проекта.
Отвечай только на русском языке.
""".strip()


def has_excessive_repetition(text: str) -> bool:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if len(lines) < 20:
        return False
    counts = Counter(lines)
    repeated = sum(count - 1 for count in counts.values() if count > 1)
    unique_ratio = len(counts) / len(lines)
    most_common = counts.most_common(1)[0][1]
    return unique_ratio < 0.55 or repeated >= 10 or most_common >= 5


def extract_message_text(message) -> str:
    """Extract final answer text without exposing hidden reasoning."""
    content = getattr(message, "content", None)
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict):
                text = item.get("text") or item.get("content")
            else:
                text = getattr(item, "text", None) or getattr(item, "content", None)
            if text:
                parts.append(str(text))
        return "\n".join(parts).strip()
    return ""


async def request_ai(system_prompt: str, user_prompt: str) -> str:
    last_finish_reason = "неизвестно"

    for attempt in range(3):
        prompt = user_prompt
        if attempt:
            prompt += (
                "\n\nПредыдущая попытка не вернула готовый ответ. "
                "Верни только полный финальный результат обычным текстом, без скрытого плана анализа."
            )

        response = await openrouter_client.chat.completions.create(
            model=settings.openrouter_model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ],
            temperature=0.1,
            max_tokens=12000,
            extra_body={
                "reasoning": {
                    "effort": "low",
                    "exclude": True,
                }
            },
        )

        if not response.choices:
            logger.warning("OpenRouter returned no choices, attempt %s", attempt + 1)
            await asyncio.sleep(2 * (attempt + 1))
            continue

        choice = response.choices[0]
        last_finish_reason = str(getattr(choice, "finish_reason", "неизвестно"))
        content = extract_message_text(choice.message)

        if not content:
            logger.warning(
                "OpenRouter returned empty content, attempt %s, finish_reason=%s",
                attempt + 1,
                last_finish_reason,
            )
            await asyncio.sleep(2 * (attempt + 1))
            continue

        if has_excessive_repetition(content):
            logger.warning("OpenRouter returned repetitive content, attempt %s", attempt + 1)
            await asyncio.sleep(2 * (attempt + 1))
            continue

        return content

    raise RuntimeError(
        "Модель трижды не вернула готовый текст. "
        f"Последняя причина завершения: {last_finish_reason}. "
        "Повторите /generate позже или временно выберите другую модель."
    )


async def send_long(message: types.Message, text: str) -> None:
    for start in range(0, len(text), 3900):
        await message.answer(text[start : start + 3900])


async def show_ai_error(status: types.Message, exc: Exception) -> None:
    logger.exception("AI request failed")
    if isinstance(exc, RateLimitError):
        text = "❌ OpenRouter временно ограничил запрос. Повторите немного позже."
    elif isinstance(exc, APIConnectionError):
        text = "❌ Не удалось подключиться к OpenRouter. Повторите запрос позже."
    elif isinstance(exc, APIStatusError):
        text = f"❌ Ошибка OpenRouter: HTTP {exc.status_code}."
    elif isinstance(exc, RuntimeError):
        text = f"❌ {exc}"
    else:
        text = f"❌ Ошибка генерации: {type(exc).__name__}"
    await status.edit_text(text)


def save_requirements_text(user_id: int, text: str, append: bool = False):
    project = store.get(user_id)
    if project is None:
        return None
    if append and project.requirements:
        project.requirements = (
            project.requirements.rstrip()
            + "\n\nДополнительные требования:\n"
            + text.strip()
        )
    else:
        project.requirements = text.strip()
    project.generated_code = ""
    project.review = ""
    store.save(project)
    return project


@dp.message(CommandStart())
async def start_handler(message: types.Message) -> None:
    await message.answer(
        "👋 Я ИИ-помощник для разработки iPhone-приложений.\n\n"
        "Команды:\n"
        "/newproject Название — создать проект\n"
        "/requirements Текст — сохранить требования\n"
        "/status — состояние проекта\n"
        "/generate — создать SwiftUI-код\n"
        "/review — проверить созданный код\n\n"
        "После создания проекта требования можно отправлять обычным сообщением."
    )


@dp.message(Command("newproject"))
async def new_project_handler(message: types.Message) -> None:
    name = (message.text or "").partition(" ")[2].strip()
    if not name:
        await message.answer("Укажите название: /newproject CaseonePOS")
        return
    project = store.create(message.from_user.id, name)
    await message.answer(
        f"✅ Проект «{project.name}» создан.\n\n"
        "Теперь отправьте требования обычным сообщением или командой /requirements Текст"
    )


@dp.message(Command("requirements"))
async def requirements_handler(message: types.Message) -> None:
    project = store.get(message.from_user.id)
    if project is None:
        await message.answer("Сначала создайте проект: /newproject Название")
        return
    requirements = (message.text or "").partition(" ")[2].strip()
    if not requirements:
        await message.answer("📝 Отправьте требования следующим обычным сообщением.")
        return
    save_requirements_text(message.from_user.id, requirements)
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
        f"Ревью: {'выполнено' if project.review else 'не выполнено'}\n"
        f"Модель: {settings.openrouter_model}"
    )


@dp.message(Command("generate"))
async def generate_handler(message: types.Message) -> None:
    project = store.get(message.from_user.id)
    if project is None or not project.requirements:
        await message.answer("Сначала создайте проект и добавьте требования.")
        return

    status = await message.answer("⏳ ИИ создаёт структуру и SwiftUI-код через OpenRouter...")
    prompt = (
        f"Проект: {project.name}\n"
        f"Требования: {project.requirements}\n\n"
        "Создай полноценную рабочую MVP-версию. Сначала перечисли дерево файлов, "
        "затем дай полный код каждого файла. Проверь зависимости и отсутствие "
        "ссылок на несуществующие типы."
    )

    try:
        generated = await request_ai(MANAGER_SYSTEM_PROMPT, prompt)
        project.generated_code = generated
        project.review = ""
        store.save(project)
        await status.delete()
        await send_long(message, generated)
    except Exception as exc:
        await show_ai_error(status, exc)


@dp.message(Command("review"))
async def review_handler(message: types.Message) -> None:
    project = store.get(message.from_user.id)
    if project is None or not project.generated_code:
        await message.answer("Сначала создайте код командой /generate")
        return

    status = await message.answer("🔍 ИИ проверяет проект через OpenRouter...")
    prompt = (
        f"Название проекта: {project.name}\n\n"
        "Проведи строгое ревью следующего SwiftUI-проекта. "
        "Считай предоставленными только файлы и код ниже:\n\n"
        + project.generated_code
    )

    try:
        review = await request_ai(REVIEW_SYSTEM_PROMPT, prompt)
        project.review = review
        store.save(project)
        await status.delete()
        await send_long(message, review)
    except Exception as exc:
        await show_ai_error(status, exc)


@dp.message(F.text)
async def text_handler(message: types.Message) -> None:
    text = (message.text or "").strip()
    if not text:
        return
    if text.startswith("/"):
        await message.answer("❌ Неизвестная команда. Используйте /start.")
        return

    project = store.get(message.from_user.id)
    if project is None:
        await message.answer("Сначала создайте проект: /newproject НазваниеПроекта")
        return

    append = bool(project.requirements)
    save_requirements_text(message.from_user.id, text, append=append)
    if append:
        await message.answer(
            "✅ Дополнительное требование добавлено. Для новой генерации используйте /generate"
        )
    else:
        await message.answer("✅ Требования сохранены. Для генерации используйте /generate")


async def health_handler(_: web.Request) -> web.Response:
    return web.json_response(
        {
            "status": "ok",
            "service": "ios-agent-bot",
            "provider": "openrouter",
            "model": settings.openrouter_model,
        }
    )


async def start_health_server() -> web.AppRunner:
    app = web.Application()
    app.router.add_get("/", health_handler)
    app.router.add_get("/health", health_handler)
    runner = web.AppRunner(app)
    await runner.setup()
    port = int(os.getenv("PORT", "3000"))
    site = web.TCPSite(runner, "0.0.0.0", port)
    await site.start()
    logger.info("Health server started on port %s", port)
    return runner


async def main() -> None:
    health_runner = await start_health_server()
    try:
        await bot.delete_webhook(drop_pending_updates=True)
        await dp.start_polling(bot)
    finally:
        await health_runner.cleanup()
        await openrouter_client.close()
        await bot.session.close()


if __name__ == "__main__":
    asyncio.run(main())
