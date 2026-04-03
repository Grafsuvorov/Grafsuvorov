# Football App - API Аутентификации

## Описание

Система аутентификации для Football App с использованием JWT токенов, подтверждением email через Unisender и полным набором функций для управления пользователями.

## Возможности

- ✅ Регистрация пользователей
- ✅ Вход в систему с JWT токенами
- ✅ Подтверждение email через Unisender
- ✅ Сброс пароля
- ✅ Повторная отправка email для верификации
- ✅ Защищенные эндпоинты
- ✅ Автоматические тесты

## Установка и настройка

### 1. Установка зависимостей

```bash
pip install -r requirements.txt
```

### 2. Настройка переменных окружения

Создайте файл `.env_test` в корне проекта:

```env
# Database
DATABASE_URL=sqlite:///./app.db

# JWT Settings
SECRET_KEY=your-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Unisender API
UNISENDER_API_KEY=63u1pjxgfwz37e4d9rwuok6zbrrtqhtb4ds4wcaa
UNISENDER_LOGIN=support@edgescore.pro

# Email Settings
FROM_EMAIL=support@edgescore.pro
FRONTEND_URL=http://localhost:3000

# Test Settings
TESTING=True
```

### 3. Запуск приложения

```bash
cd api
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## API Эндпоинты

### Аутентификация

#### POST /auth/register
Регистрация нового пользователя

**Тело запроса:**
```json
{
  "email": "user@example.com",
  "username": "username",
  "password": "password123"
}
```

**Ответ:**
```json
{
  "message": "Registration successful. Please check your email to verify your account."
}
```

#### POST /auth/login
Вход в систему

**Тело запроса:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Ответ:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "username": "username",
    "is_verified": true,
    "created_at": "2024-01-01T00:00:00"
  }
}
```

#### POST /auth/verify
Подтверждение email

**Тело запроса:**
```json
{
  "token": "verification-token-from-email"
}
```

**Ответ:**
```json
{
  "message": "Email verified successfully. You can now log in."
}
```

#### POST /auth/forgot-password
Запрос на сброс пароля

**Тело запроса:**
```json
{
  "email": "user@example.com"
}
```

**Ответ:**
```json
{
  "message": "If the email exists, a password reset link has been sent."
}
```

#### POST /auth/reset-password
Сброс пароля по токену

**Тело запроса:**
```json
{
  "token": "reset-token-from-email",
  "new_password": "newpassword123"
}
```

**Ответ:**
```json
{
  "message": "Password reset successfully."
}
```

#### GET /auth/me
Получение информации о текущем пользователе

**Заголовки:**
```
Authorization: Bearer <access_token>
```

**Ответ:**
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "username",
  "is_verified": true,
  "created_at": "2024-01-01T00:00:00"
}
```

#### POST /auth/resend-verification
Повторная отправка email для верификации

**Параметры:**
```
email=user@example.com
```

**Ответ:**
```json
{
  "message": "Verification email sent successfully."
}
```

## Безопасность

- Пароли хешируются с использованием bcrypt
- JWT токены имеют ограниченное время жизни
- Email верификация обязательна для входа
- Токены верификации и сброса пароля имеют срок действия
- Защищенные эндпоинты требуют валидный JWT токен

## Тестирование

### Запуск автотестов

```bash
python test_auth_api.py
```

### Запуск с pytest

```bash
pytest test_auth_api.py -v
```

## Структура проекта

```
api/
├── auth.py                 # Основные эндпоинты аутентификации
├── core/
│   ├── config.py          # Конфигурация приложения
│   └── security.py        # Функции безопасности
├── models/
│   └── user.py            # Модель пользователя
├── schemas/
│   └── auth.py            # Pydantic схемы
├── services/
│   └── email.py           # Сервис отправки email
└── database.py            # Настройки базы данных
```

## Интеграция с Unisender

Система использует Unisender API для отправки email:

- Подтверждение регистрации
- Сброс пароля
- HTML форматирование писем
- Обработка ошибок API

## База данных

- SQLite для разработки и тестирования
- SQLAlchemy ORM
- Автоматическое создание таблиц
- Миграции через Alembic (опционально)

## Логирование

Все операции логируются с различными уровнями:
- INFO: Успешные операции
- WARNING: Проблемы с отправкой email
- ERROR: Ошибки системы

## Развертывание

### Продакшн

1. Измените `SECRET_KEY` на безопасный
2. Настройте PostgreSQL или MySQL
3. Обновите `FRONTEND_URL`
4. Настройте HTTPS
5. Добавьте rate limiting
6. Настройте мониторинг

### Docker

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Поддержка

При возникновении проблем:

1. Проверьте логи приложения
2. Убедитесь в корректности переменных окружения
3. Проверьте подключение к базе данных
4. Проверьте доступность Unisender API

## Лицензия

MIT License
