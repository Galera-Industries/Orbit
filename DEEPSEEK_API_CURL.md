# DeepSeek API - cURL примеры

## Базовый запрос

```bash
curl -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY_HERE" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {
        "role": "user",
        "content": "Привет! Как дела?"
      }
    ],
    "max_tokens": 20000
  }'
```

## Запрос с промптом для извлечения заданий

```bash
curl -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY_HERE" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {
        "role": "user",
        "content": "извлеки отсюда условия заданий и варианты ответов [ваш текст здесь]"
      }
    ],
    "max_tokens": 20000
  }'
```

## Запрос с пользовательским промптом

```bash
curl -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY_HERE" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {
        "role": "user",
        "content": "напиши ответы на вопросы в формате 1) a и тд. Не нужно объяснений\n\n[ваш текст здесь]"
      }
    ],
    "max_tokens": 20000
  }'
```

## Красивый вывод (с jq)

Если у вас установлен `jq`, можете использовать его для красивого вывода:

```bash
curl -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY_HERE" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {
        "role": "user",
        "content": "Привет!"
      }
    ],
    "max_tokens": 20000
  }' | jq '.choices[0].message.content'
```

## Только текст ответа (без JSON)

```bash
curl -s -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY_HERE" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {
        "role": "user",
        "content": "Привет!"
      }
    ],
    "max_tokens": 20000
  }' | jq -r '.choices[0].message.content'
```

## Пример с сохранением ответа в файл

```bash
curl -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY_HERE" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {
        "role": "user",
        "content": "извлеки отсюда условия заданий и варианты ответов [ваш текст]"
      }
    ],
    "max_tokens": 20000
  }' > response.json
```

## Получение API ключа

1. Перейдите на https://platform.deepseek.com
2. Зарегистрируйтесь или войдите
3. Перейдите в раздел API Keys
4. Создайте новый ключ
5. Скопируйте ключ и замените `YOUR_API_KEY_HERE` в командах выше

## Модели DeepSeek

- `deepseek-chat` - основная модель для чата
- `deepseek-coder` - модель для программирования

## Параметры запроса

- `model` (обязательно) - модель для использования
- `messages` (обязательно) - массив сообщений в формате `[{role: "user", content: "текст"}]`
- `max_tokens` (опционально) - максимальное количество токенов в ответе (по умолчанию 2000)
- `temperature` (опционально) - температура для генерации (0.0-1.0, по умолчанию 1.0)
- `stream` (опционально) - потоковый ответ (true/false)

## Пример с температурой

```bash
curl -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY_HERE" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {
        "role": "user",
        "content": "Привет!"
      }
    ],
    "max_tokens": 20000,
    "temperature": 0.7
  }'
```


