import asyncio
import logging
import os

from aiohttp import web
from aiogram import Bot, Dispatcher, F, types
from aiogram.filters import Command, CommandStart
from openai import AsyncOpenAI, APIConnectionError, APIStatusError, RateLimitError

from config import load_settings
from services.project_store import ProjectStore

MANAGER_SYSTEM_PROMPT = (
    "Ты — Senior iOS Engineer и Software Architect с опытом коммерческой разработки более 15 лет. "
    "Создавай полноценные, логически завершённые и компилируемые iOS-проекты для Xcode на Swift и SwiftUI. "
    "Запрещено ссылаться на несуществующие классы, ViewModel, Model, Service, View, методы, свойства, "
    "изображения и зависимости. Перед выводом результата проведи внутреннюю проверку импортов, типов, "
    "инициализаторов, Binding, State, StateObject, EnvironmentObject, async/await и маршрутов навигации. "
    "Возвращай полный проект без пропусков, псевдокода и фраз вроде 'остальной код аналогичен'. "
    "Если проект большой, продолжай последовательно до завершения всех файлов. Используй Swift 5.9+, "
    "SwiftUI, MVVM, NavigationStack и современные API Apple. Для финансовых значений предпочитай Decimal. "
    "Всегда перечисляй дерево файлов и предоставляй полный код каждого файла отдельно. "
    "Отвечай на русском языке. Не утверждай, что проект реально собран в Xcode, если сборка не выполнялась."
)

REVIEW_SYSTEM_PROMPT = (
    "Ты строгий senior code reviewer для Swift и SwiftUI. "
    "Проверяй только подтверждённые кодом ошибки компиляции, архитектуру, состояния интерфейса, async/await, "
    "утечки памяти, безопасность и соответствие современным практикам Apple. "
    "Отделяй реальные ошибки от рекомендаций. Если часть файлов не предоставлена, прямо указывай, "
    "что вывод требует проверки остальных файлов. Давай конкретные исправления и итоговый вердикт. "
    "Отвечай на русском языке."
)

logging.basicConfig(level=logging.INFO)

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


async def request_ai(system_prompt: str, user_prompt: str) -> str:
    response = await openrouter_client.chat.completions.create(
        model=settings.openrouter_model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.2,
    )

    content = response.choices[0].message.content
    if not content:
        raise RuntimeError("Модель вернула пустой ответ")
    return content.strip()


async def send_long(message: types.Message, text: str) -> None:
    for start in range(0, len(text), 4000):
        await message.answer(text[start : start + 4000])


async def show_ai_error(status: types.Message, exc: Exception) -> None:
    logging.exception("AI request failed")

    if isinstance(exc, RateLimitError):
        text = "❌ OpenRouter временно ограничил запрос. Повторите немного позже."
    elif isinstance(exc, APIConnectionError):
        text = "❌ Не удалось подключиться к OpenRouter. Повторите запрос позже."
    elif isinstance(exc, APIStatusError):
        text = f"❌ Ошибка OpenRouter: HTTP {exc.status_code}."
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
        "👋 Я команда ИИ-агентов для разработки iPhone-приложений.\n\n"
        "Команды:\n"
        "/newproject Название — создать проект\n"
        "/requirements Текст — сохранить требования\n"
        "/status — показать состояние проекта\n"
        "/generate — подготовить SwiftUI-код\n"
        "/review — проверить созданный код\n\n"
        "После создания проекта требования можно отправлять обычным текстом без команды."
    )


@dp.message(Command("newproject"))
async def new_project_handler(message: types.Message) -> None:
    name = (message.text or "").partition(" ")[2].strip()
    if not name:
        await message.answer("Укажите название: /newproject Kolibri App")
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
        await message.answer(
            "📝 Отправьте требования следующим обычным сообщением без команды."
        )
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
        "Создай полноценную рабочую MVP-версию. Перечисли дерево файлов и дай полный код каждого файла. "
        "Перед выводом проверь зависимости и отсутствие ссылок на несуществующие типы."
    )

    try:
        project.generated_code = await request_ai(MANAGER_SYSTEM_PROMPT, prompt)
        store.save(project)
        await status.delete()
        await send_long(message, project.generated_code)
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
        "Проведи строгое ревью следующего SwiftUI-проекта:\n\n"
        + project.generated_code
    )

    try:
        project.review = await request_ai(REVIEW_SYSTEM_PROMPT, prompt)
        store.save(project)
        await status.delete()
        await send_long(message, project.review)
    except Exception as exc:
        await show_ai_error(status, exc)


@dp.message(F.text)
async def text_handler(message: types.Message) -> None:
    text = (message.text or "").strip()

    if not text:
        return

    if text.startswith("/"):
        await message.answer("❌ Неизвестная команда. Используйте /start для списка команд.")
        return

    project = store.get(message.from_user.id)
    if project is None:
        await message.answer(
            "Сначала создайте проект командой:\n/newproject НазваниеПроекта"
        )
        return

    append = bool(project.requirements)
    save_requirements_text(message.from_user.id, text, append=append)

    if append:
        await message.answer(
            "✅ Дополнительное требование добавлено. Для новой генерации используйте /generate"
        )
    else:
        await message.answer(
            "✅ Требования сохранены. Для генерации используйте /generate"
        )


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
    logging.info("Health server started on port %s", port)
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
