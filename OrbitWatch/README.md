# Orbit Watch App

Это Apple Watch приложение для просмотра ответов от DeepSeek.

## Установка

1. Откройте проект Orbit.xcodeproj в Xcode
2. Добавьте новый target для watchOS:
   - File → New → Target
   - Выберите "watchOS" → "App"
   - Назовите его "OrbitWatch"
   - Bundle Identifier: `com.orbit.app.watchkitapp`
3. Скопируйте файлы из папки `OrbitWatch` в новый target
4. Настройте App Group (опционально, для обмена данными):
   - В настройках macOS приложения добавьте App Group: `group.com.orbit.app`
   - В настройках watchOS приложения добавьте тот же App Group
   - Включите App Groups capability в обоих targets

## Использование

- Свайп влево/вправо для переключения между ответами
- Или используйте кнопки навигации внизу экрана

## Примечание

Для полноценной работы App Group требуется Apple Developer аккаунт. Без него приложение будет использовать стандартный UserDefaults, что может не работать для обмена данными между macOS и watchOS приложениями.



