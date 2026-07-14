import os
from pathlib import Path
from dotenv import load_dotenv

# Всегда грузим .test_env из каталога api/ (рядом с этим файлом)
HERE = Path(__file__).resolve().parent         # .../api/core
API_DIR = HERE.parent                          # .../api
ENV_PATHS = [
    API_DIR / ".test_env",
    API_DIR / ".env_test",
    API_DIR / ".env",
]

loaded_path = None
for p in ENV_PATHS:
    if p.exists():
        load_dotenv(p)
        loaded_path = p
        break

if not loaded_path:
    # Последняя попытка — переменные уже есть в окружении (Docker/IDE)
    pass
else:
    print(f"[ENV] loaded: {loaded_path}")

def _required(name: str) -> str:
    v = os.getenv(name)
    if not v or not v.strip():
        raise RuntimeError(f"[CONFIG] REQUIRED env var '{name}' is missing")
    return v.strip()

def _optional(name: str, default: str = "") -> str:
    v = os.getenv(name)
    if v is None or not v.strip():
        return default
    return v.strip()

class Settings:
    # требуем строго DATABASE_URL
    DATABASE_URL: str = _required("DATABASE_URL")
    DWH_DATABASE_URL: str = _optional("DWH_DATABASE_URL", DATABASE_URL)

    # остальное опционально
    SECRET_KEY: str = os.getenv("SECRET_KEY", "change-me")
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    REFRESH_TOKEN_EXPIRE_DAYS: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30"))

    SENDGRID_API_KEY: str = os.getenv("SENDGRID_API_KEY", os.getenv("BREVO_API_KEY", ""))
    UNISENDER_API_KEY: str = os.getenv("UNISENDER_API_KEY", "")
    UNISENDER_LOGIN: str = os.getenv("UNISENDER_LOGIN", "")

    FROM_EMAIL: str = os.getenv("FROM_EMAIL", os.getenv("SENDER_EMAIL", os.getenv("SMTP_LOGIN", "")))
    SMTP_SERVER: str = os.getenv("SMTP_SERVER", "smtp.yandex.ru")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", "587"))
    SMTP_LOGIN: str = os.getenv("SMTP_LOGIN", "")
    SMTP_PASS: str = os.getenv("SMTP_PASS", os.getenv("YANDEX_APP_PASSWORD", ""))
    FRONTEND_URL: str = os.getenv("FRONTEND_URL", "http://localhost:3000")
    _raw_cors_origins = [
        origin.strip()
        for origin in os.getenv(
            "CORS_ALLOW_ORIGINS",
            "http://localhost:3000,http://localhost:3001",
        ).split(",")
        if origin.strip()
    ]
    _native_cors_origins = [
        "capacitor://localhost",
        "ionic://localhost",
        "http://localhost",
        "https://localhost",
    ]
    CORS_ALLOW_ORIGINS: list[str] = list(dict.fromkeys(_raw_cors_origins + _native_cors_origins))
    YANDEX_APP_PASSWORD: str = os.getenv("YANDEX_APP_PASSWORD", os.getenv("SMTP_PASS", ""))

    TESTING: bool = os.getenv("TESTING", "False").lower() == "true"
    ENABLE_TEST_ROUTES: bool = os.getenv("ENABLE_TEST_ROUTES", "False").lower() == "true"
    ENABLE_DEBUG_ROUTES: bool = os.getenv("ENABLE_DEBUG_ROUTES", "False").lower() == "true"
    LOG_ROUTES_ON_STARTUP: bool = os.getenv("LOG_ROUTES_ON_STARTUP", "False").lower() == "true"

settings = Settings()
print(f"[CONFIG] DATABASE_URL = {settings.DATABASE_URL}")
