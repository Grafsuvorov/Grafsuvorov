from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
import os

from api.dwh_database import get_user_by_verification_token, update_user_verification_in_dwh
from api.core.security import verify_token

router = APIRouter()

# Путь к статическим файлам
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")

@router.get("/verify")
async def verify_page(token: str = None):
    """Страница верификации email - новая архитектура"""
    
    if not token:
        # Если токен не передан, показываем страницу с ошибкой
        return FileResponse(os.path.join(STATIC_DIR, "verify_error.html"))
    
    try:
        # Ищем пользователя по токену
        user = get_user_by_verification_token(token)
        
        if user:
            # Обновляем статус верификации
            success = update_user_verification_in_dwh(user.email, True)
            
            if success:
                # Показываем страницу успеха
                return FileResponse(os.path.join(STATIC_DIR, "verify_success.html"))
            else:
                # Показываем страницу ошибки
                return FileResponse(os.path.join(STATIC_DIR, "verify_error.html"))
        else:
            # Токен не найден или истек
            return FileResponse(os.path.join(STATIC_DIR, "verify_error.html"))
            
    except Exception as e:
        # Ошибка при верификации
        return FileResponse(os.path.join(STATIC_DIR, "verify_error.html"))

@router.get("/")
async def home_page():
    """Главная страница"""
    return {"message": "Football App API", "docs": "/docs"}
