# VK API - Примеры curl запросов

## Отправка сообщения (messages.send)

### Базовый пример
```bash
curl -X POST "https://api.vk.com/method/messages.send" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "peer_id=YOUR_PEER_ID" \
  -d "message=Тестовое сообщение из Orbit" \
  -d "random_id=$(date +%s)" \
  -d "access_token=YOUR_ACCESS_TOKEN" \
  -d "v=5.131"
```

### Пример с конкретными значениями
```bash
curl -X POST "https://api.vk.com/method/messages.send" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "peer_id=123456789" \
  -d "message=🤖 ChatGPT\n\nЭто тестовое сообщение" \
  -d "random_id=1234567890" \
  -d "access_token=your_access_token_here" \
  -d "v=5.131"
```

### Одной строкой (для копирования)
```bash
curl -X POST "https://api.vk.com/method/messages.send" -H "Content-Type: application/x-www-form-urlencoded" -d "peer_id=YOUR_PEER_ID" -d "message=Тестовое сообщение" -d "random_id=$(date +%s)" -d "access_token=YOUR_ACCESS_TOKEN" -d "v=5.131"
```

**Важно:** `random_id` - обязательный параметр! Это уникальный идентификатор для предотвращения повторной отправки сообщения. Можно использовать timestamp или любое случайное число.

## Проверка токена (users.get)

### Проверка валидности access_token
```bash
curl -X POST "https://api.vk.com/method/users.get" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "access_token=YOUR_ACCESS_TOKEN" \
  -d "v=5.131"
```

### Одной строкой
```bash
curl -X POST "https://api.vk.com/method/users.get" -H "Content-Type: application/x-www-form-urlencoded" -d "access_token=YOUR_ACCESS_TOKEN" -d "v=5.131"
```

## Получение информации о себе (для проверки токена и получения user_id)

```bash
curl -X POST "https://api.vk.com/method/users.get" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "access_token=YOUR_ACCESS_TOKEN" \
  -d "fields=id,first_name,last_name" \
  -d "v=5.131"
```

## Как получить параметры:

### 1. Access Token
1. Перейдите на https://vk.com/dev
2. Создайте новое приложение типа "Standalone"
3. Получите `client_id`
4. Сформируйте URL для получения токена:
   ```
   https://oauth.vk.com/authorize?client_id=YOUR_CLIENT_ID&display=page&redirect_uri=https://oauth.vk.com/blank.html&scope=messages&response_type=token&v=5.131
   ```
5. Авторизуйтесь и скопируйте `access_token` из URL после редиректа

### 2. Peer ID
- Для личных сообщений: используйте ваш `user_id` (можно получить через `users.get`)
- Для беседы: ID беседы (обычно начинается с `2000000000`)
- Для группы: `-group_id` (с минусом)

### Пример успешного ответа messages.send:
```json
{
  "response": 12345
}
```
Где `12345` - это ID отправленного сообщения.

### Пример ошибки:
```json
{
  "error": {
    "error_code": 100,
    "error_msg": "One of the parameters specified was missing or invalid"
  }
}
```

## Типичные ошибки:

- **901**: Can't send messages for users without permission
  - Решение: Пользователь должен начать диалог с вашим приложением/ботом первым

- **100**: One of the parameters specified was missing or invalid
  - Решение: Проверьте правильность всех параметров

- **5**: User authorization failed
  - Решение: Токен невалидный или истёк, получите новый

- **113**: Invalid user id
  - Решение: Проверьте правильность peer_id

