# iOS Agent Bot

Telegram-бот с несколькими ИИ-агентами для проектирования и создания iPhone-приложений на SwiftUI.

## Первая версия

- Telegram-интерфейс на aiogram 3
- главный агент — iOS Project Manager
- агент-разработчик — iOS Developer
- агент-проверяющий — Code Reviewer
- OpenAI Agents SDK

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

5. Создайте файл `.env` на основе `.env.example` и заполните:

```env
BOT_TOKEN=...
OPENAI_API_KEY=...
OPENAI_MODEL=gpt-5.2
```

6. Запустите бота:

```bash
python bot.py
```

## Безопасность

Не загружайте `.env`, токены Telegram и ключи OpenAI в GitHub.
