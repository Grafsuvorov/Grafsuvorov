# api/models/api_roles.py
from enum import Enum

class APIRole(str, Enum):
    """Роли API клиентов"""
    USER = "user"           # Базовый API доступ
    PREMIUM = "premium"     # Расширенный API
    BUSINESS = "business"   # Коммерческие данные
    ADMIN = "admin"         # Полный доступ

class AccessLevel(str, Enum):
    """Уровни доступа к эндпоинтам"""
    PUBLIC = "public"        # Только через сайт
    USER_AUTH = "user_auth"  # Для авторизованных пользователей сайта
    API_ACCESS = "api"       # Требует API ключ
    PREMIUM = "premium"      # Требует премиум API
    BUSINESS = "business"    # Требует бизнес API

# Маппинг ролей на лимиты запросов
API_RATE_LIMITS = {
    APIRole.USER: "100/hour",
    APIRole.PREMIUM: "1000/hour", 
    APIRole.BUSINESS: "10000/hour",
    APIRole.ADMIN: "unlimited"
}

# Маппинг ролей на месячные квоты
API_MONTHLY_QUOTAS = {
    APIRole.USER: 1000,
    APIRole.PREMIUM: 10000,
    APIRole.BUSINESS: 100000,
    APIRole.ADMIN: -1  # Безлимит
}
