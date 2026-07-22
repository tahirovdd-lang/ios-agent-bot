# CaseonePOS Manager for iPhone

SwiftUI-приложение для владельцев и администраторов заведений CaseonePOS.

## Уже реализовано

- фирменная палитра `#068562` и `#013F4A`;
- нижняя навигация для iPhone;
- главный Dashboard;
- оборот, количество продаж, средний чек, наличные и карты;
- экран аналитики со Swift Charts;
- разбивка по способам оплаты и официантам;
- экран текущей смены и X/Z-отчётов;
- история чеков и поиск;
- разделы склада, кухни, официантов, уведомлений и безопасности;
- базовый API-клиент на async/await.

## Запуск

1. Установить XcodeGen:
   ```bash
   brew install xcodegen
   ```
2. Открыть папку проекта:
   ```bash
   cd CaseonePOS-iOS
   ```
3. Создать Xcode-проект:
   ```bash
   xcodegen generate
   ```
4. Открыть `CaseonePOSManager.xcodeproj` в Xcode.
5. Выбрать симулятор iPhone и нажать Run.

## Подключение реального сервера

В `Sources/APIClient.swift` заменить тестовый адрес:

```swift
https://api.example.caseonepos.uz
```

на фактический адрес API CaseonePOS.

Планируемые методы API:

- `POST /api/auth/login`
- `GET /api/dashboard`
- `GET /api/analytics`
- `GET /api/shifts/current`
- `GET /api/receipts`
- `GET /api/stock/low`

До подключения API приложение использует демонстрационные данные из интерфейсного файла.
