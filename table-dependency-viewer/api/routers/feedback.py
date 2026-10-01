import json
import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from ..auth import get_current_user_from_request
from ..config import TABLE_APP_FEEDBACK
from ..runtime import engine
from ..services.feedback import list_feedback, save_feedback

logger = logging.getLogger(__name__)
router = APIRouter(tags=["feedback"])


class FeedbackPayload(BaseModel):
    topic: str
    message: str
    contact_email: Optional[str] = None
    page_path: Optional[str] = None


def _optional_user(request: Request):
    try:
        return get_current_user_from_request(request)
    except Exception:
        return None


@router.post("/api/feedback")
def submit_feedback(payload: FeedbackPayload, request: Request):
    user = _optional_user(request)
    try:
        return save_feedback(
            engine=engine,
            table_name=TABLE_APP_FEEDBACK,
            topic=payload.topic,
            message=payload.message,
            user_email=getattr(user, "email", "") if user else "",
            user_name=getattr(user, "username", "") if user else "",
            contact_email=payload.contact_email or (getattr(user, "email", "") if user else ""),
            page_path=payload.page_path or request.url.path,
            meta_json=json.dumps({
                "user_role": getattr(user, "role", None) if user else None,
                "referer": request.headers.get("referer"),
                "user_agent": request.headers.get("user-agent"),
            }, ensure_ascii=False),
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/api/admin/feedback")
def get_feedback(request: Request, days: int = 30, topic: str = "", limit: int = 200):
    user = get_current_user_from_request(request)
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    try:
        items = list_feedback(engine=engine, table_name=TABLE_APP_FEEDBACK, days=days, topic=topic, limit=limit)
    except Exception as exc:
        logger.exception("Could not load feedback")
        raise HTTPException(status_code=500, detail="Не удалось загрузить обратную связь") from exc
    return {
        "items": items,
        "days": max(1, min(int(days or 30), 365)),
        "topic": str(topic or "").strip(),
        "limit": max(1, min(int(limit or 200), 1000)),
    }
