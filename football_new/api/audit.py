import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from api.auth_dwh import get_current_user_dwh
from api.database import get_db
from api.models.user_activity import UserActivityLog


router = APIRouter(prefix="/api/audit", tags=["Audit"])


def _allowed_audit_admin_emails() -> list[str]:
    raw = os.getenv("AUDIT_ADMIN_EMAILS", "").strip()
    if not raw:
        raw = os.getenv("ROI_ADMIN_EMAILS", "").strip()
    if not raw:
        env_path = Path(__file__).resolve().parent / ".env"
        if env_path.exists():
            try:
                for line in env_path.read_text(encoding="utf-8").splitlines():
                    if not line or line.strip().startswith("#") or "=" not in line:
                        continue
                    key, value = line.split("=", 1)
                    if key.strip() in {"AUDIT_ADMIN_EMAILS", "ROI_ADMIN_EMAILS"} and value.strip():
                        raw = value.strip()
                        break
            except Exception:
                pass
    return [x.strip().lower() for x in raw.split(",") if x.strip()]


def require_audit_admin(current_user=Depends(get_current_user_dwh)):
    allowed = _allowed_audit_admin_emails()
    if not allowed:
        raise HTTPException(status_code=404, detail="Not found")
    email = (getattr(current_user, "email", None) or "").lower()
    if email not in allowed:
        raise HTTPException(status_code=404, detail="Not found")
    return current_user


def _row_to_dict(row: UserActivityLog) -> dict:
    return {
        "id": row.id,
        "user_id": row.user_id,
        "user_email": row.user_email,
        "username": row.username,
        "event_type": row.event_type,
        "method": row.method,
        "path": row.path,
        "query_string": row.query_string,
        "response_status": row.response_status,
        "response_time_ms": row.response_time_ms,
        "ip_address": row.ip_address,
        "referer": row.referer,
        "user_agent": row.user_agent,
        "metadata": json.loads(row.metadata_json) if row.metadata_json else None,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


@router.post("/page-view")
def record_page_view(
    payload: dict,
    current_user=Depends(get_current_user_dwh),
    db: Session = Depends(get_db),
):
    event = UserActivityLog(
        user_id=getattr(current_user, "id", None),
        user_email=getattr(current_user, "email", None),
        username=getattr(current_user, "username", None),
        event_type="page_view",
        method="NAVIGATE",
        path=str(payload.get("path") or "/"),
        ip_address=str(payload.get("ip_address")) if payload.get("ip_address") else None,
        user_agent=payload.get("user_agent"),
        referer=payload.get("referrer"),
        metadata_json=json.dumps(
            {
                "title": payload.get("title"),
                "source": payload.get("source", "frontend"),
            },
            ensure_ascii=False,
        ),
    )
    db.add(event)
    db.commit()
    return {"ok": True}


@router.get("/me/recent")
def get_my_recent_activity(
    limit: int = Query(default=100, ge=1, le=500),
    current_user=Depends(get_current_user_dwh),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(UserActivityLog)
        .filter(UserActivityLog.user_id == getattr(current_user, "id", None))
        .order_by(UserActivityLog.created_at.desc())
        .limit(limit)
        .all()
    )
    return [_row_to_dict(row) for row in rows]


@router.get("/me/summary")
def get_my_activity_summary(
    days: int = Query(default=30, ge=1, le=365),
    current_user=Depends(get_current_user_dwh),
    db: Session = Depends(get_db),
):
    since = datetime.now(timezone.utc) - timedelta(days=days)
    rows = (
        db.query(UserActivityLog)
        .filter(
            UserActivityLog.user_id == getattr(current_user, "id", None),
            UserActivityLog.created_at >= since,
        )
        .all()
    )
    unique_paths = sorted({row.path for row in rows if row.path})
    return {
        "days": days,
        "total_events": len(rows),
        "page_views": sum(1 for row in rows if row.event_type == "page_view"),
        "api_requests": sum(1 for row in rows if row.event_type == "api_request"),
        "unique_paths": unique_paths,
        "last_seen_at": (
            max((row.created_at for row in rows), default=None).isoformat()
            if rows
            else None
        ),
    }


@router.get("/admin/recent")
def get_admin_recent_activity(
    limit: int = Query(default=200, ge=1, le=1000),
    days: int = Query(default=7, ge=1, le=365),
    user_email: str | None = Query(default=None),
    path: str | None = Query(default=None),
    event_type: str | None = Query(default=None),
    current_user=Depends(require_audit_admin),
    db: Session = Depends(get_db),
):
    since = datetime.now(timezone.utc) - timedelta(days=days)
    q = db.query(UserActivityLog).filter(UserActivityLog.created_at >= since)
    if user_email:
        q = q.filter(UserActivityLog.user_email.ilike(user_email.strip()))
    if path:
        q = q.filter(UserActivityLog.path.ilike(f"%{path.strip()}%"))
    if event_type:
        q = q.filter(UserActivityLog.event_type == event_type.strip())
    rows = q.order_by(UserActivityLog.created_at.desc()).limit(limit).all()
    return {
        "days": days,
        "count": len(rows),
        "items": [_row_to_dict(row) for row in rows],
    }


@router.get("/admin/summary")
def get_admin_activity_summary(
    days: int = Query(default=7, ge=1, le=365),
    current_user=Depends(require_audit_admin),
    db: Session = Depends(get_db),
):
    since = datetime.now(timezone.utc) - timedelta(days=days)
    rows = db.query(UserActivityLog).filter(UserActivityLog.created_at >= since).all()
    unique_users = sorted({row.user_email for row in rows if row.user_email})
    top_paths: dict[str, int] = {}
    top_users: dict[str, int] = {}
    for row in rows:
        if row.path:
            top_paths[row.path] = top_paths.get(row.path, 0) + 1
        if row.user_email:
            top_users[row.user_email] = top_users.get(row.user_email, 0) + 1
    return {
        "days": days,
        "total_events": len(rows),
        "page_views": sum(1 for row in rows if row.event_type == "page_view"),
        "api_requests": sum(1 for row in rows if row.event_type == "api_request"),
        "unique_users_count": len(unique_users),
        "unique_users": unique_users,
        "top_paths": sorted(top_paths.items(), key=lambda x: x[1], reverse=True)[:20],
        "top_users": sorted(top_users.items(), key=lambda x: x[1], reverse=True)[:20],
        "last_seen_at": (
            max((row.created_at for row in rows), default=None).isoformat()
            if rows
            else None
        ),
    }
