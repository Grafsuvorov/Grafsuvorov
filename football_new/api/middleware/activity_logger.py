import json
import time
from typing import Optional

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

from api.core.security import verify_access_token
from api.database import SessionLocal
from api.dwh_database import get_user_by_email
from api.models.user_activity import UserActivityLog


class ActivityLoggerMiddleware(BaseHTTPMiddleware):
    def __init__(self, app):
        super().__init__(app)
        self.skip_prefixes = (
            "/docs",
            "/openapi.json",
            "/redoc",
            "/favicon.ico",
            "/_debug",
        )
        self.skip_paths = {
            "/health",
            "/api/audit/page-view",
        }

    def _should_skip(self, path: str) -> bool:
        if path in self.skip_paths:
            return True
        return any(path.startswith(prefix) for prefix in self.skip_prefixes)

    def _extract_user(self, request: Request) -> tuple[Optional[int], Optional[str], Optional[str]]:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return None, None, None

        token = auth_header.removeprefix("Bearer ").strip()
        if not token:
            return None, None, None

        email = verify_access_token(token)
        if not email:
            return None, None, None

        user = get_user_by_email(email)
        if not user:
            return None, email, None
        return getattr(user, "id", None), getattr(user, "email", email), getattr(user, "username", None)

    def _get_ip(self, request: Request) -> Optional[str]:
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        real_ip = request.headers.get("x-real-ip")
        if real_ip:
            return real_ip.strip()
        if request.client:
            return request.client.host
        return None

    async def dispatch(self, request: Request, call_next) -> Response:
        if self._should_skip(request.url.path):
            return await call_next(request)

        started_at = time.perf_counter()
        response = await call_next(request)
        duration_ms = int((time.perf_counter() - started_at) * 1000)

        try:
            user_id, user_email, username = self._extract_user(request)
            payload = UserActivityLog(
                user_id=user_id,
                user_email=user_email,
                username=username,
                event_type="api_request",
                method=request.method,
                path=request.url.path,
                query_string=request.url.query or None,
                ip_address=self._get_ip(request),
                user_agent=request.headers.get("user-agent"),
                referer=request.headers.get("referer"),
                response_status=response.status_code,
                response_time_ms=duration_ms,
                metadata_json=json.dumps(
                    {
                        "route": request.scope.get("route").path if request.scope.get("route") else None,
                    },
                    ensure_ascii=False,
                ),
            )
            with SessionLocal() as db:
                db.add(payload)
                db.commit()
        except Exception:
            # Audit must never break the request path.
            pass

        return response
