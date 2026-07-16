from agents import Agent


def create_manager_agent(model: str) -> Agent:
    ios_developer = Agent(
        name="iOS Developer",
        model=model,
        instructions=(
            "Ты senior iOS-разработчик. Создавай код на Swift и SwiftUI. "
            "Используй MVVM, async/await и понятную структуру проекта. "
            "Всегда перечисляй создаваемые файлы и отдавай полный код каждого файла."
        ),
    )

    reviewer = Agent(
        name="Code Reviewer",
        model=model,
        instructions=(
            "Ты проверяешь Swift и SwiftUI код. Ищи ошибки компиляции, "
            "проблемы архитектуры, состояния интерфейса и безопасности. "
            "Дай конкретные исправления и итоговый вердикт."
        ),
    )

    return Agent(
        name="iOS Project Manager",
        model=model,
        instructions=(
            "Ты управляешь созданием iPhone-приложения. Сначала уточни требования, "
            "затем составь краткий план. Когда пользователь просит написать код, "
            "вызови iOS-разработчика. После получения кода обязательно вызови ревьюера. "
            "Отвечай на русском языке и не утверждай, что проект собран в Xcode, "
            "если реальная сборка не выполнялась."
        ),
        tools=[
            ios_developer.as_tool(
                tool_name="create_ios_code",
                tool_description="Создать SwiftUI-код по требованиям проекта",
            ),
            reviewer.as_tool(
                tool_name="review_ios_code",
                tool_description="Проверить SwiftUI-код и предложить исправления",
            ),
        ],
    )
