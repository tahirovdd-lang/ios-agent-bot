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

MANAGER_SYSTEM_PROMPT = (
    "Ты — Senior iOS Engineer и Software Architect с опытом коммерческой разработки более 15 лет. "
    "Создавай полноценные, логически завершённые iOS-проекты для Xcode на Swift и SwiftUI. "
    "Запрещено ссылаться на несуществующие классы, ViewModel, Model, Service, View, методы, свойства, "
    "изображения и зависимости. Перед выводом результата проведи внутреннюю проверку импортов, типов, "
    "инициализаторов, Binding, State, StateObject, EnvironmentObject, async/await и маршрутов навигации. "
    "Возвращай полный проект без пропусков, псевдокода и фраз вроде 'остальной код аналогичен'. "
    "Если проект большой, продолжай последовательно до завершения всех файлов. Используй Swift 5.9+, "
    "SwiftUI, MVVM, NavigationStack и современные API Apple. Для финансовых значений предпочитай Decimal. "
    "Всегда перечисляй дерево файлов и предоставляй полный код каждого файла отдельно. "
    "Отвечай на русском языке. Не утверждай, что проект реально собран в Xcode, если сборка не выполнялась."
)

REVIEW_SYSTEM_PROMPT = """
Ты — Principal iOS Engineer и Senior Code Reviewer с опытом более 15 лет.
Проводи максимально строгий аудит предоставленного Swift-проекта.

ГЛАВНОЕ ПРАВИЛО
Не предполагай, не додумывай и не фантазируй.
Если чего-то нет в предоставленном коде, прямо так и напиши.
Никогда не утверждай, что проект компилируется или успешно запускается, если фактическая сборка не выполнялась.
Каждое замечание должно опираться на конкретный фрагмент предоставленного кода.

ЗАПРЕЩЕНО В ОТВЕТЕ
- Не показывай внутренний план анализа или скрытые рассуждения.
- Не пиши фразы вида “We need to ensure...”, “I need to check...” и похожие служебные заметки.
- Не повторяй одинаковые строки, требования, выводы или замечания.
- Не придумывай отсутствующие файлы, типы, зависимости и номера строк.
- Не называй архитектурную рекомендацию критической ошибкой.

КАТЕГОРИИ ПРОВЕРКИ

1. Критические ошибки
Включай только подтверждённые кодом проблемы, которые приводят к:
- ошибке компиляции;
- крашу;
- бесконечному циклу;
- утечке памяти;
- нарушению логики приложения;
- невозможности запуска.
Не включай сюда архитектурные советы.

2. Возможные проблемы
Указывай только то, что действительно может вызвать проблему.
Когда вывод зависит от файлов, которых нет в предоставленном коде, обязательно напиши:
“Требуется проверить остальные файлы проекта.”

3. Архитектурные замечания
Проверяй MVVM, Dependency Injection, SOLID, Clean Architecture, Repository, Coordinator,
SwiftData и CoreData только тогда, когда соответствующий подход действительно используется в коде.
Не навязывай Clean Architecture и не предлагай масштабную перестройку без подтверждённой необходимости.

4. Стиль и корректность Swift
Проверяй Swift API Design Guidelines, naming, access control, mutability, let/var,
@MainActor, async/await, Task, cancellation и memory management.

5. Производительность
Проверяй LazyVGrid, LazyVStack, Image, NavigationStack, ObservableObject, StateObject,
EnvironmentObject, SwiftData и CoreData только в местах, где они реально присутствуют.

6. Безопасность
Проверяй Keychain, UserDefaults, PII, пароли, токены и API-ключи только при их наличии в коде.

ПРОВЕРКА КОМПИЛЯЦИИ
Перед каждым замечанием проверь, есть ли прямое подтверждение в предоставленном коде.
Если подтверждения нет, не заявляй ошибку как факт.

Неправильно:
“ProductCard отсутствует.”

Правильно:
“В предоставленных файлах ProductCard не найден. Если он отсутствует в проекте — возникнет ошибка компиляции. Требуется проверить остальные файлы проекта.”

ФОРМАТ ОТВЕТА
Раздели результат на разделы:
- Критические ошибки
- Возможные проблемы
- Архитектурные замечания
- Стиль кода
- Производительность
- Безопасность

Для каждого найденного замечания используй таблицу:
| Severity | Файл | Строка | Проблема | Исправление |

Допустимые Severity:
Critical, Major, Minor, Info.

Если точный номер строки невозможно определить из предоставленного текста, напиши “не указана”.
Не придумывай номер строки.
Если в категории нет подтверждённых замечаний, напиши: “Подтверждённых замечаний не обнаружено.”

После каждой таблицы покажи только минимально необходимый исправленный фрагмент кода.
Не переписывай файл полностью, если достаточно изменить несколько строк.

ИТОГ
В конце обязательно выведи:
Критических ошибок: X
Потенциальных проблем: X
Архитектурных рекомендаций: X
Ошибок компиляции, подтвержденных кодом: X
Ошибок компиляции, требующих проверки остальных файлов: X

Степень готовности проекта:
🟥 Не собирается — только при наличии подтверждённой ошибки компиляции или невозможности запуска.
🟨 Требует исправлений — при подтверждённых проблемах без доказанной невозможности сборки.
🟩 Готов к сборке — только если предоставлены все необходимые файлы и подтверждённых препятствий не найдено; это не означает, что сборка реально выполнена.

Если предоставлены не все файлы, обязательно напиши:
“Невозможно подтвердить готовность проекта, поскольку предоставлены не все файлы.”

Перед отправкой ответа проверь, что одинаковые предложения и абзацы не повторяются.
Отвечай только на русском языке.
""".strip()

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


def has_excessive_repetition(text: str) -> bool:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if len(lines) < 20:
        return False

    counts = Counter(lines)
    repeated_line_count = sum(count - 1 for count in counts.values() if count > 1)
    unique_ratio = len(counts) / len(lines)
    most_common_count = counts.most_common(1)[0][1]

    return (
        unique_ratio < 0.55
        or repeated_line_count >= 10
        or most_common_count >= 5
    )


async def request_ai(system_prompt: str, user_prompt: str) -> str:
    retry_instruction = (
        "\n\nВАЖНО: предыдущая попытка содержала чрезмерные повторы. "
        "Сформируй ответ заново, без повторяющихся строк и без внутреннего плана анализа."
    )

    for attempt in range(2):
        current_user_prompt = user_prompt
        if attempt == 1:
            current_user_prompt += retry_instruction

        response = await openrouter_client.chat.completions.create(
            model=settings.openrouter_model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": current_user_prompt},
            ],
            temperature=0.1,
            max_tokens=8000,
        )

        content = response.choices[0].message.content
        if not content:
            raise RuntimeError("Модель вернула пустой ответ")

        content = content.strip()
        if not has_excessive_repetition(content):
            return content

        logging.warning("AI returned repetitive content, attempt %s", attempt + 1)

    raise RuntimeError(
        "Модель дважды вернула зацикленный ответ. Повторите запрос позже или выберите другую модель."
    )


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
        "Проведи строгое ревью следующего SwiftUI-проекта. "
        "Считай предоставленными только файлы и код, которые находятся ниже:\n\n"
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
