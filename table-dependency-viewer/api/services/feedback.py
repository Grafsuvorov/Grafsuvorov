from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import text


def ensure_feedback_table(engine, table_name: str) -> None:
    ddl = f"""
    CREATE TABLE IF NOT EXISTS {table_name} (
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        user_email TEXT,
        user_name TEXT,
        contact_email TEXT,
        topic TEXT NOT NULL,
        message TEXT NOT NULL,
        page_path TEXT,
        meta_json TEXT
    )
    DISTRIBUTED RANDOMLY
    """
    with engine.begin() as conn:
        conn.execute(text(ddl))


def save_feedback(
    *,
    engine,
    table_name: str,
    topic: str,
    message: str,
    user_email: str = "",
    user_name: str = "",
    contact_email: str = "",
    page_path: str = "",
    meta_json: str = "",
) -> dict[str, Any]:
    ensure_feedback_table(engine, table_name)
    topic_norm = str(topic or "").strip()
    message_norm = str(message or "").strip()
    if not topic_norm:
        raise ValueError("Укажите тему обращения")
    if not message_norm:
        raise ValueError("Заполните сообщение")
    if len(message_norm) < 10:
        raise ValueError("Сообщение слишком короткое")

    payload = {
        "user_email": str(user_email or "").strip() or None,
        "user_name": str(user_name or "").strip() or None,
        "contact_email": str(contact_email or "").strip() or None,
        "topic": topic_norm,
        "message": message_norm,
        "page_path": str(page_path or "").strip() or None,
        "meta_json": str(meta_json or "").strip() or None,
    }
    with engine.begin() as conn:
        conn.execute(
            text(
                f"""
                INSERT INTO {table_name} (
                    user_email,
                    user_name,
                    contact_email,
                    topic,
                    message,
                    page_path,
                    meta_json
                ) VALUES (
                    :user_email,
                    :user_name,
                    :contact_email,
                    :topic,
                    :message,
                    :page_path,
                    :meta_json
                )
                """
            ),
            payload,
        )
    return {
        "status": "ok",
        "saved_at": datetime.utcnow().isoformat(),
        "topic": topic_norm,
    }


def list_feedback(
    *,
    engine,
    table_name: str,
    days: int = 30,
    topic: str = "",
    limit: int = 200,
) -> list[dict[str, Any]]:
    days_norm = max(1, min(int(days or 30), 365))
    limit_norm = max(1, min(int(limit or 200), 1000))
    topic_norm = str(topic or "").strip()

    where_parts = ["created_at >= now() - (:days || ' days')::interval"]
    params: dict[str, Any] = {
        "days": str(days_norm),
        "limit": limit_norm,
    }
    if topic_norm:
        where_parts.append("topic = :topic")
        params["topic"] = topic_norm

    query = f"""
        select
            created_at,
            user_email,
            user_name,
            contact_email,
            topic,
            message,
            page_path,
            meta_json
        from {table_name}
        where {' and '.join(where_parts)}
        order by created_at desc
        limit :limit
    """
    with engine.begin() as conn:
        rows = conn.execute(text(query), params).mappings().all()
    return [dict(row) for row in rows]
