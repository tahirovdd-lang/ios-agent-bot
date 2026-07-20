# iOS Agent Bot

Telegram-бот для проектирования и создания iPhone-приложений на SwiftUI через официальный OpenAI API.

## Возможности

- Telegram-интерфейс на aiogram 3
- генерация SwiftUI-проекта командой `/generate`
- проверка созданного кода командой `/review`
- хранение проектов в SQLite
- официальный OpenAI Python SDK
- `/generate` использует GPT-5
- `/review` использует GPT-5 mini

## Локальный запуск

1. Установите Python 3.11 или новее.
2. Создайте виртуальное окружение:

```bash
python -m venv .venv
```

3. Активируйте его.

Windows PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

4. Установите зависимости:

```bash
pip install -r requirements.txt
```

5. Создайте файл `.env` на основе `.env.example`:

```env
BOT_TOKEN=...
OPENAI_API_KEY=...
OPENAI_GENERATE_MODEL=gpt-5
OPENAI_REVIEW_MODEL=gpt-5-mini
DB_PATH=/app/data/ios_agent.db
```

6. Запустите бота:

```bash
python bot.py
```

## Настройка Bothost

Добавьте переменные окружения:

```env
BOT_TOKEN=ваш_токен_Telegram
OPENAI_API_KEY=ваш_ключ_OpenAI
OPENAI_GENERATE_MODEL=gpt-5
OPENAI_REVIEW_MODEL=gpt-5-mini
DB_PATH=/app/data/ios_agent.db
```

Переменные `OPENROUTER_API_KEY`, `OPENROUTER_GENERATE_MODEL` и `OPENROUTER_REVIEW_MODEL` больше не используются.

После изменения переменных выполните Redeploy.

## Безопасность

Не загружайте `.env`, токены Telegram и ключи OpenAI в GitHub. Если ключ был опубликован в чате или репозитории, отзовите его и создайте новый.
