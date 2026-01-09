# api/middleware/request_checker.py
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response
import time
from typing import Callable

from api.core.api_auth import is_from_your_website, get_client_ip

class RequestSourceCheckerMiddleware(BaseHTTPMiddleware):
    """Middleware для проверки источника запросов"""
    
    def __init__(self, app, allowed_paths: list = None):
        super().__init__(app)
        # Пути, которые доступны только через сайт
        self.website_only_paths = allowed_paths or [
            "/public/",
            "/user/",
            "/auth-dwh/",
            "/subscriptions/",
            "/verify",
            "/"
        ]
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.time()
        
        # Проверяем только для API путей
        if request.url.path.startswith("/api/"):
            # Если запрос не с вашего сайта - требуем API ключ
            if not is_from_your_website(request):
                api_key = request.headers.get("X-API-Key")
                if not api_key:
                    raise HTTPException(
                        status_code=403,
                        detail={
                            "error": "API access requires authentication",
                            "message": "This API endpoint requires an API key. Please provide X-API-Key header.",
                            "documentation": "https://your-website.com/api-docs"
                        }
                    )
        
        # Проверяем пути только для сайта
        for path in self.website_only_paths:
            if request.url.path.startswith(path):
                if not is_from_your_website(request):
                    raise HTTPException(
                        status_code=403,
                        detail="This endpoint is only accessible through the website"
                    )
                break
        
        # Выполняем запрос
        response = await call_next(request)
        
        # Логируем время выполнения
        process_time = time.time() - start_time
        response.headers["X-Process-Time"] = str(process_time)
        
        return response
