from __future__ import annotations

import json
import re
import ssl
import time
from dataclasses import dataclass
from typing import Any, Optional
from urllib import parse as urlparse
from urllib import request as urlrequest
from urllib import error as urlerror

from sqlalchemy import create_engine, text

from .entity_dev_meta import _gitlab_json_request, _parse_gitlab_project, _urlopen_without_proxy


SQL_FILE_RE = re.compile(r"\.sql$", re.IGNORECASE)
TARGET_PATTERNS = [
    re.compile(r"\binsert\s+into\s+([a-zA-Z0-9_`\"\.]+)", re.IGNORECASE),
    re.compile(r"\binsert\s+overwrite(?:\s+table)?\s+([a-zA-Z0-9_`\"\.]+)", re.IGNORECASE),
    re.compile(r"\bcreate\s+(?:or\s+replace\s+)?table\s+([a-zA-Z0-9_`\"\.]+)", re.IGNORECASE),
]
DEPENDENCY_PATTERNS = [
    re.compile(r"\bfrom\s+([a-zA-Z0-9_`\"\.]+)", re.IGNORECASE),
    re.compile(r"\bjoin\s+([a-zA-Z0-9_`\"\.]+)", re.IGNORECASE),
    re.compile(r"\bupdate\s+([a-zA-Z0-9_`\"\.]+)", re.IGNORECASE),
]


@dataclass
class PrototypeGitLabRef:
    project: str
    mr_iid: int


def _normalize_bool(value: str, default: bool = True) -> bool:
    text_value = str(value or "").strip().lower()
    if not text_value:
        return default
    return text_value not in {"0", "false", "no", "off"}


def _clean_identifier(value: str) -> str:
    text_value = str(value or "").strip().strip(";")
    if not text_value:
        return ""
    if text_value.startswith("("):
        return ""
    return text_value.replace("`", "").replace('"', "")


def _normalize_fqn(value: str) -> Optional[str]:
    clean = _clean_identifier(value)
    if not clean or "." not in clean:
        return None
    schema_name, table_name = clean.split(".", 1)
    schema_name = schema_name.strip()
    table_name = table_name.strip()
    if not schema_name or not table_name:
        return None
    return f"{schema_name.lower()}.{table_name.lower()}"


def _split_sql_statements(sql_text: str) -> list[str]:
    text_value = str(sql_text or "")
    statements: list[str] = []
    current: list[str] = []
    in_single = False
    in_double = False
    for char in text_value:
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        if char == ";" and not in_single and not in_double:
            candidate = "".join(current).strip()
            if candidate:
                statements.append(candidate)
            current = []
            continue
        current.append(char)
    tail = "".join(current).strip()
    if tail:
        statements.append(tail)
    return statements


def parse_prototype_gitlab_ref(value: str, default_project: str) -> PrototypeGitLabRef:
    raw_value = str(value or "").strip()
    if not raw_value:
        raise ValueError("Укажите MR URL или IID")
    if raw_value.isdigit():
        project = _parse_gitlab_project(default_project)
        if not project:
            raise ValueError("Не настроен ANALYST_GITLAB_PROJECT / GITLAB_PROJECT")
        return PrototypeGitLabRef(project=project, mr_iid=int(raw_value))
    match = re.search(r"/([^/]+/[^/]+)/-/merge_requests/(\d+)", raw_value)
    if match:
        return PrototypeGitLabRef(project=match.group(1), mr_iid=int(match.group(2)))
    match = re.search(r"/merge_requests/(\d+)", raw_value)
    if match:
        project = _parse_gitlab_project(default_project)
        if not project:
            raise ValueError("Не настроен ANALYST_GITLAB_PROJECT / GITLAB_PROJECT")
        return PrototypeGitLabRef(project=project, mr_iid=int(match.group(1)))
    raise ValueError("Не удалось распознать MR. Используйте URL или IID")


def load_merge_request_sql_bundle(
    *,
    gitlab_api_url: str,
    gitlab_project: str,
    gitlab_token: str,
    gitlab_ssl_verify: str,
    mr_input: str,
    default_project: str,
) -> dict[str, Any]:
    project_default = default_project or gitlab_project
    mr_ref = parse_prototype_gitlab_ref(mr_input, project_default)
    ssl_verify = _normalize_bool(gitlab_ssl_verify, default=True)
    mr = _gitlab_json_request(
        api_url=gitlab_api_url,
        project=mr_ref.project,
        token=gitlab_token,
        ssl_verify=ssl_verify,
        path=f"merge_requests/{mr_ref.mr_iid}",
    )
    changes_payload = _gitlab_json_request(
        api_url=gitlab_api_url,
        project=mr_ref.project,
        token=gitlab_token,
        ssl_verify=ssl_verify,
        path=f"merge_requests/{mr_ref.mr_iid}/changes",
    )
    changes = changes_payload.get("changes") if isinstance(changes_payload, dict) else []
    source_branch = str((mr or {}).get("source_branch") or "").strip()
    files = []
    for item in changes or []:
        path_value = str(item.get("new_path") or item.get("old_path") or "").strip()
        if not path_value or not SQL_FILE_RE.search(path_value):
            continue
        encoded_path = urlparse.quote(path_value, safe="")
        raw_url = (
            f"{gitlab_api_url.rstrip('/')}/projects/"
            f"{urlparse.quote(mr_ref.project, safe='')}/repository/files/{encoded_path}/raw"
            f"?ref={urlparse.quote(source_branch, safe='')}"
        )
        req = urlrequest.Request(
            raw_url,
            headers={
                "Accept": "text/plain",
                "PRIVATE-TOKEN": gitlab_token,
            },
            method="GET",
        )
        with _urlopen_without_proxy(req, timeout=30, ssl_verify=ssl_verify) as resp:
            sql_text = resp.read().decode("utf-8", errors="ignore")
        files.append(
            {
                "path": path_value,
                "sql": sql_text,
                "statements": _split_sql_statements(sql_text),
            }
        )
    if not files:
        raise ValueError("В MR не найдено изменённых .sql файлов")
    return {
        "mr": {
            "project": mr_ref.project,
            "iid": mr_ref.mr_iid,
            "title": (mr or {}).get("title"),
            "web_url": (mr or {}).get("web_url"),
            "source_branch": source_branch,
            "target_branch": (mr or {}).get("target_branch"),
            "author": ((mr or {}).get("author") or {}).get("name"),
        },
        "files": files,
    }


def infer_final_target(files: list[dict[str, Any]]) -> Optional[str]:
    targets: list[str] = []
    for item in files:
        for statement in item.get("statements") or []:
            for pattern in TARGET_PATTERNS:
                match = pattern.search(statement)
                if match:
                    normalized = _normalize_fqn(match.group(1))
                    if normalized:
                        targets.append(normalized)
    return targets[-1] if targets else None


def extract_sql_dependencies(files: list[dict[str, Any]]) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for item in files:
        for statement in item.get("statements") or []:
            for pattern in DEPENDENCY_PATTERNS:
                for match in pattern.finditer(statement):
                    normalized = _normalize_fqn(match.group(1))
                    if normalized and normalized not in seen:
                        seen.add(normalized)
                        result.append(normalized)
    return result


def execute_sql_files_in_dev(
    *,
    dev_database_url: str,
    files: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    if not dev_database_url:
        raise ValueError("Не настроен DEV_DATABASE_URL")
    exec_engine = create_engine(dev_database_url)
    connection = None
    cursor = None
    results: list[dict[str, Any]] = []
    try:
        connection = exec_engine.raw_connection()
        cursor = connection.cursor()
        for item in files:
            sql_text = str(item.get("sql") or "").strip()
            if not sql_text:
                results.append({"path": item.get("path"), "status": "skipped", "duration_sec": 0.0})
                continue
            started = time.perf_counter()
            cursor.execute(sql_text)
            connection.commit()
            results.append(
                {
                    "path": item.get("path"),
                    "status": "ok",
                    "duration_sec": round(time.perf_counter() - started, 3),
                }
            )
    except Exception as exc:
        if connection is not None:
            try:
                connection.rollback()
            except Exception:
                pass
        raise ValueError(f"Не удалось выполнить SQL в DEV: {exc}") from exc
    finally:
        if cursor is not None:
            try:
                cursor.close()
            except Exception:
                pass
        if connection is not None:
            try:
                connection.close()
            except Exception:
                pass
        exec_engine.dispose()
    return results


def query_dev_table_checks(
    *,
    dev_database_url: str,
    target_fqn: str,
    key_attributes: list[str],
) -> dict[str, Any]:
    if not dev_database_url:
        raise ValueError("Не настроен DEV_DATABASE_URL")
    normalized = _normalize_fqn(target_fqn)
    if not normalized:
        raise ValueError("Не удалось определить финальную таблицу")
    schema_name, table_name = normalized.split(".", 1)
    exec_engine = create_engine(dev_database_url)
    row_count = None
    duplicate_count = None
    try:
        with exec_engine.connect() as conn:
            row_count = conn.execute(
                text(f'SELECT COUNT(*) FROM "{schema_name}"."{table_name}"')
            ).scalar()
            normalized_keys = [str(item).strip() for item in (key_attributes or []) if str(item).strip()]
            if normalized_keys:
                group_by = ", ".join(f'"{item}"' for item in normalized_keys)
                duplicate_count = conn.execute(
                    text(
                        f"""
                        SELECT COUNT(*)
                        FROM (
                            SELECT {group_by}
                            FROM "{schema_name}"."{table_name}"
                            GROUP BY {group_by}
                            HAVING COUNT(*) > 1
                        ) dup
                        """
                    )
                ).scalar()
    finally:
        exec_engine.dispose()
    return {
        "row_count": int(row_count or 0),
        "duplicate_groups": int(duplicate_count or 0) if duplicate_count is not None else None,
    }


def create_ytrack_issue(
    *,
    api_url: str,
    oauth_token: str,
    org_id: str,
    cloud_org_id: str,
    queue: str,
    issue_type: str,
    ssl_verify: str,
    summary: str,
    description: str,
) -> dict[str, Any]:
    if not oauth_token or not queue:
        return {"status": "not_configured", "issue_id": None, "url": None}
    headers = {
        "Authorization": f"OAuth {oauth_token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if org_id:
        headers["X-Org-ID"] = org_id
    if cloud_org_id:
        headers["X-Cloud-Org-ID"] = cloud_org_id
    payload = {
        "queue": queue,
        "summary": summary,
        "description": description,
        "type": issue_type or "task",
    }
    req = urlrequest.Request(
        f"{api_url.rstrip('/')}/issues/",
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with _urlopen_without_proxy(req, timeout=30, ssl_verify=_normalize_bool(ssl_verify, default=True)) as resp:
            body = resp.read().decode("utf-8")
            data = json.loads(body) if body else {}
    except urlerror.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise ValueError(f"YTrack вернул {exc.code}: {body}") from exc
    except Exception as exc:
        raise ValueError(f"Не удалось создать задачу в YTrack: {exc}") from exc
    issue_id = data.get("key") or data.get("id")
    return {
        "status": "created",
        "issue_id": issue_id,
        "url": data.get("self"),
        "raw": data,
    }
