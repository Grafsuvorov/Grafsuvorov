from __future__ import annotations

import json
import re
from typing import Any

from ..config import (
    CORP_AI_API_KEY,
    CORP_AI_BASE_URL,
    CORP_AI_MODEL,
    CORP_AI_SSL_VERIFY,
    CORP_AI_TIMEOUT_SEC,
)

try:
    import httpx
    from openai import OpenAI
except ImportError:  # pragma: no cover - optional runtime dependency
    OpenAI = None
    httpx = None


def _env_flag(value: str) -> bool:
    return str(value or "").strip().lower() in {"1", "true", "yes", "on"}


def corp_ai_is_configured() -> bool:
    return bool(CORP_AI_API_KEY.strip() and CORP_AI_BASE_URL.strip() and OpenAI and httpx)


def _strip_code_fences(value: str) -> str:
    text = str(value or "").strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    return text.strip()


def _extract_text_content(response: Any) -> str:
    choices = getattr(response, "choices", None) or []
    if not choices:
        return ""
    message = getattr(choices[0], "message", None)
    if message is None:
        return ""
    content = getattr(message, "content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict):
                text_value = item.get("text")
                if text_value:
                    parts.append(str(text_value))
            else:
                text_value = getattr(item, "text", None)
                if text_value:
                    parts.append(str(text_value))
        return "\n".join(parts).strip()
    return str(content or "").strip()


def enhance_assistant_response(
    *,
    question: str,
    context: dict[str, Any] | None,
    local_response: dict[str, Any],
) -> dict[str, Any] | None:
    if not corp_ai_is_configured():
        return None

    verify_value: bool | str = _env_flag(CORP_AI_SSL_VERIFY)
    http_client = httpx.Client(verify=verify_value, timeout=CORP_AI_TIMEOUT_SEC)
    client = OpenAI(
        api_key=CORP_AI_API_KEY,
        base_url=CORP_AI_BASE_URL,
        http_client=http_client,
    )

    system_prompt = (
        "Ты корпоративный ассистент DWH-приложения. "
        "Твоя задача: улучшить ответ локального ассистента, но не выдумывать факты. "
        "Используй только вопрос пользователя, контекст страницы и внутренний ответ приложения. "
        "Верни только JSON-объект формата "
        '{"title":"...","answer":"...","suggestions":["..."]}. '
        "answer должен быть кратким, конкретным и на русском языке. "
        "Если внутренний ответ уже хороший, просто аккуратно перепиши его."
    )

    user_payload = {
        "question": question,
        "context": context or {},
        "internal_answer": {
            "title": local_response.get("title"),
            "answer": local_response.get("answer"),
            "tables": local_response.get("tables") or [],
            "stats": local_response.get("stats") or [],
            "suggestions": local_response.get("suggestions") or [],
            "mode": local_response.get("mode"),
        },
    }

    try:
        response = client.chat.completions.create(
            model=CORP_AI_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": json.dumps(user_payload, ensure_ascii=False)},
            ],
        )
        raw_text = _extract_text_content(response)
        if not raw_text:
            return None
        parsed = json.loads(_strip_code_fences(raw_text))
        if not isinstance(parsed, dict):
            return None

        answer = str(parsed.get("answer") or "").strip()
        title = str(parsed.get("title") or local_response.get("title") or "Ответ").strip()
        suggestions = parsed.get("suggestions")
        if not isinstance(suggestions, list):
            suggestions = local_response.get("suggestions") or []

        return {
            **local_response,
            "title": title,
            "answer": answer or str(local_response.get("answer") or "").strip(),
            "suggestions": [str(item).strip() for item in suggestions if str(item).strip()][:6],
            "llm_provider": "corp_ai",
        }
    except Exception:
        return None
    finally:
        http_client.close()
