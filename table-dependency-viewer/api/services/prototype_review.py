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
IGNORED_DEPENDENCY_SCHEMAS = {"information_schema", "pg_catalog", "pg_temp"}
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


def _split_lines_block(value: str) -> list[str]:
    return [line.strip() for line in str(value or "").splitlines() if line.strip()]


def _strip_sql_comments(sql: str) -> str:
    cleaned = re.sub(r"/\*.*?\*/", " ", str(sql or ""), flags=re.DOTALL)
    cleaned = re.sub(r"(?m)--.*?$", " ", cleaned)
    return cleaned


def _is_valid_dependency_fqn(value: Optional[str], known_schemas: Optional[set[str]] = None) -> bool:
    if not value or "." not in value:
        return False
    schema_name, table_name = value.split(".", 1)
    schema_name = schema_name.strip().lower()
    table_name = table_name.strip().lower()
    if not schema_name or not table_name:
        return False
    if schema_name in IGNORED_DEPENDENCY_SCHEMAS:
        return False
    if schema_name.startswith("pg_temp"):
        return False
    if known_schemas and schema_name not in known_schemas:
        return False
    return True


def parse_prototype_task_text(task_text: str) -> dict[str, Any]:
    raw_text = str(task_text or "").strip()
    if not raw_text:
        return {}
    lines = _split_lines_block(raw_text)
    result: dict[str, Any] = {
        "summary": lines[0] if lines else None,
        "source_name": None,
        "source_schema": None,
        "source_table": None,
        "source_key": None,
        "source_access": None,
        "target_table_fqn": None,
        "entity_name": None,
        "subject_area": None,
        "git_reference": None,
        "load_mode": None,
        "load_condition": None,
        "environments": [],
        "dependent_views": [],
        "copy_to_clickhouse": None,
        "clickhouse_keys": [],
        "business_key": [],
        "script_runtime": None,
        "release_article_url": None,
        "pseudo_increment_steps": None,
        "linked_issues": [],
        "parent_issue": None,
        "dashboard_name": None,
    }

    field_patterns = {
        "source_name": r"Источник:\s*(.+)",
        "source_schema": r"Название схемы на источнике:\s*(.+)",
        "source_table": r"Название таблицы на источнике:\s*(.+)",
        "source_key": r"Ключ на источнике:\s*(.+)",
        "source_access": r"Доступ к таблице на источнике:\s*(.+)",
        "target_table_fqn": r"(?:Название таблицы Greenplum|Название таблицы в таргете):\s*(.+)",
        "entity_name": r"Сущность загрузки:\s*(.+)",
        "subject_area": r"Предметная область:\s*(.+)",
        "git_reference": r"(?:Ссылка на гит|Ссылка на описание шаблона):\s*(.+)",
        "load_mode": r"Способ обновления:\s*(.+)",
        "load_condition": r"Условие при загрузке:\s*(.+)",
        "environments": r"Стенд:\s*(.+)",
        "dependent_views": r"(?:Зависимые представления|Зависимые представление):\s*(.+)",
        "dashboard_name": r"Дашборд КХД/Направление\s*(.+)",
        "script_runtime": r"Время работы скрипта:\s*(.+)",
        "release_article_url": r"Ссылка на статью релиза:\s*(.+)",
    }
    for field_name, pattern in field_patterns.items():
        match = re.search(pattern, raw_text, re.IGNORECASE)
        if not match:
            continue
        value = match.group(1).strip()
        if field_name == "target_table_fqn":
            result[field_name] = _normalize_fqn(value)
        elif field_name == "environments":
            result[field_name] = [item.strip().upper() for item in re.split(r"[/,;]", value) if item.strip()]
        elif field_name == "dependent_views":
            result[field_name] = [
                item for item in (_normalize_fqn(part) for part in re.split(r"[,;\s]+", value)) if item
            ]
        else:
            result[field_name] = value

    copy_match = re.search(r"Копировать в ClickHouse:\s*(.+)", raw_text, re.IGNORECASE)
    if copy_match:
        result["copy_to_clickhouse"] = "не нужно" not in copy_match.group(1).strip().lower()

    clickhouse_keys_match = re.search(
        r"Ключевые поля.*?:\s*(.+?)(?:\n\s*\n|\n[А-ЯA-Z][^:\n]{0,80}:|\nсвязана с|\nподзадача для|\Z)",
        raw_text,
        re.IGNORECASE | re.DOTALL,
    )
    if clickhouse_keys_match:
        clickhouse_keys: list[str] = []
        for line in clickhouse_keys_match.group(1).splitlines():
            key = str(line or "").strip(" \t-•")
            if key:
                clickhouse_keys.append(key)
        result["clickhouse_keys"] = clickhouse_keys

    business_key_match = re.search(
        r"Бизнес-ключ.*?:\s*(.+?)(?:\n\s*\n|\n[А-ЯA-Z][^:\n]{0,80}:|\nсвязана с|\nподзадача для|\Z)",
        raw_text,
        re.IGNORECASE | re.DOTALL,
    )
    if business_key_match:
        business_keys: list[str] = []
        for line in business_key_match.group(1).splitlines():
            key = str(line or "").strip(" \t-•,;")
            if key:
                business_keys.append(key)
        result["business_key"] = business_keys

    pseudo_increment_match = re.search(
        r"Последовательность действий при \(псевдо\)инкрементальном обновлении таблицы:\s*(.+?)(?:\n\s*\n|\n[А-ЯA-Z][^:\n]{0,80}:|\Z)",
        raw_text,
        re.IGNORECASE | re.DOTALL,
    )
    if pseudo_increment_match:
        result["pseudo_increment_steps"] = pseudo_increment_match.group(1).strip()

    related = []
    for issue_id in re.findall(r"\b[A-Z]+-\d+\b", raw_text):
        if issue_id not in related:
            related.append(issue_id)
    result["linked_issues"] = related
    parent_match = re.search(r"подзадача для.*?\b([A-Z]+-\d+)\b", raw_text, re.IGNORECASE | re.DOTALL)
    if parent_match:
        result["parent_issue"] = parent_match.group(1)

    if not result.get("target_table_fqn"):
        for line in lines[:5]:
            maybe_fqn = re.search(r"\b([a-zA-Z_][\w]*)\.([a-zA-Z_][\w]*)\b", line)
            if maybe_fqn:
                result["target_table_fqn"] = _normalize_fqn(maybe_fqn.group(0))
                break
    return result


def validate_prototype_sql(files: list[dict[str, Any]]) -> dict[str, list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    for item in files:
        path_value = str(item.get("path") or "")
        sql_text = str(item.get("sql") or "")
        normalized_sql = _strip_sql_comments(sql_text).lower()
        if re.search(r"\buserdata\b", normalized_sql):
            errors.append(f"В `{path_value}` найдена ссылка на `userdata`; такие объекты запрещены для prototype review")
    return {"errors": errors, "warnings": warnings}


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

    short_match = re.fullmatch(r"[#!]\s*(\d+)", raw_value)
    if short_match:
        project = _parse_gitlab_project(default_project)
        if not project:
            raise ValueError("Не настроен ANALYST_GITLAB_PROJECT / GITLAB_PROJECT")
        return PrototypeGitLabRef(project=project, mr_iid=int(short_match.group(1)))

    project_ref_match = re.fullmatch(r"(.+?)[!/](\d+)", raw_value)
    if project_ref_match and "/" in project_ref_match.group(1):
        return PrototypeGitLabRef(
            project=project_ref_match.group(1).strip("/"),
            mr_iid=int(project_ref_match.group(2)),
        )

    parsed = urlparse.urlparse(raw_value)
    path_value = urlparse.unquote(parsed.path or "")

    match = re.search(r"/(.+?)/-/merge_requests/(\d+)(?:/.*)?$", path_value)
    if match:
        return PrototypeGitLabRef(project=match.group(1).strip("/"), mr_iid=int(match.group(2)))

    match = re.search(r"^(.+?)/-/merge_requests/(\d+)(?:/.*)?$", path_value or raw_value)
    if match:
        return PrototypeGitLabRef(project=match.group(1).strip("/"), mr_iid=int(match.group(2)))

    match = re.search(r"/merge_requests/(\d+)(?:/.*)?$", path_value or raw_value)
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


def extract_sql_dependencies(
    files: list[dict[str, Any]],
    *,
    known_schemas: Optional[set[str]] = None,
    exclude_fqns: Optional[set[str]] = None,
) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    excluded = {str(item).strip().lower() for item in (exclude_fqns or set()) if str(item).strip()}
    for item in files:
        for statement in item.get("statements") or []:
            for pattern in DEPENDENCY_PATTERNS:
                for match in pattern.finditer(statement):
                    normalized = _normalize_fqn(match.group(1))
                    if (
                        normalized
                        and normalized not in seen
                        and normalized not in excluded
                        and _is_valid_dependency_fqn(normalized, known_schemas=known_schemas)
                    ):
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


def prepare_target_table_in_dev(
    *,
    dev_database_url: str,
    target_fqn: str,
) -> dict[str, Any]:
    normalized = _normalize_fqn(target_fqn)
    if not dev_database_url:
        raise ValueError("Не настроен DEV_DATABASE_URL")
    if not normalized:
        return {"status": "skipped", "action": "truncate", "message": "Финальная таблица не определена"}
    schema_name, table_name = normalized.split(".", 1)
    exec_engine = create_engine(dev_database_url)
    started = time.perf_counter()
    try:
        with exec_engine.begin() as conn:
            row = conn.execute(
                text(
                    """
                    SELECT table_type
                    FROM information_schema.tables
                    WHERE table_schema = :schema_name
                      AND table_name = :table_name
                    LIMIT 1
                    """
                ),
                {"schema_name": schema_name, "table_name": table_name},
            ).mappings().first()
            if not row:
                return {
                    "status": "warning",
                    "action": "truncate",
                    "target_fqn": normalized,
                    "message": "Целевая таблица не найдена в DEV, предварительный TRUNCATE пропущен",
                    "duration_sec": round(time.perf_counter() - started, 3),
                }
            if str(row.get("table_type") or "").upper() != "BASE TABLE":
                return {
                    "status": "warning",
                    "action": "truncate",
                    "target_fqn": normalized,
                    "message": f"Целевой объект имеет тип `{row.get('table_type')}`, TRUNCATE пропущен",
                    "duration_sec": round(time.perf_counter() - started, 3),
                }
            conn.execute(text(f'TRUNCATE TABLE "{schema_name}"."{table_name}"'))
            return {
                "status": "ok",
                "action": "truncate",
                "target_fqn": normalized,
                "message": "Целевая таблица очищена перед выполнением SQL",
                "duration_sec": round(time.perf_counter() - started, 3),
            }
    finally:
        exec_engine.dispose()


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
    base_url: str,
    project_id: str,
    project: str,
    token: str,
    queue: str,
    issue_type: str,
    ssl_verify: str,
    summary: str,
    description: str,
    default_estimate_minutes: int = 60,
) -> dict[str, Any]:
    if not token or not queue:
        return {"status": "not_configured", "issue_id": None, "url": None}
    resolved_project_id = _resolve_ytrack_project_id(
        base_url=base_url,
        token=token,
        project_id=project_id,
        project=project,
        ssl_verify=ssl_verify,
    )
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    payload = {
        "project": {"id": resolved_project_id},
        "queue": queue,
        "summary": summary,
        "description": description,
        "type": issue_type or "task",
    }
    required_period_fields = _load_required_ytrack_period_fields(
        base_url=base_url,
        token=token,
        project_id=resolved_project_id,
        ssl_verify=ssl_verify,
    )
    if required_period_fields:
        payload["customFields"] = [
            {
                "name": field_name,
                "$type": "PeriodIssueCustomField",
                "value": {"minutes": max(1, int(default_estimate_minutes or 60))},
            }
            for field_name in required_period_fields
        ]
    req = urlrequest.Request(
        f"{base_url.rstrip('/')}/api/issues",
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


def _load_required_ytrack_period_fields(
    *,
    base_url: str,
    token: str,
    project_id: str,
    ssl_verify: str,
) -> list[str]:
    req = urlrequest.Request(
        (
            f"{base_url.rstrip('/')}/api/admin/projects/{urlparse.quote(project_id, safe='')}/customFields"
            "?fields=canBeEmpty,field(name,fieldType(id,valueType))"
        ),
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
        method="GET",
    )
    try:
        with _urlopen_without_proxy(req, timeout=30, ssl_verify=_normalize_bool(ssl_verify, default=True)) as resp:
            body = resp.read().decode("utf-8")
            items = json.loads(body) if body else []
    except Exception:
        return []

    result: list[str] = []
    for item in items or []:
        if (item or {}).get("canBeEmpty", True):
            continue
        field = (item or {}).get("field") or {}
        field_name = str(field.get("name") or "").strip()
        field_type = field.get("fieldType") or {}
        field_type_id = str(field_type.get("id") or field_type.get("valueType") or "").strip().lower()
        if field_name and field_type_id == "period":
            result.append(field_name)
    return result


def _resolve_ytrack_project_id(
    *,
    base_url: str,
    token: str,
    project_id: str,
    project: str,
    ssl_verify: str,
) -> str:
    explicit_id = str(project_id or "").strip()
    if explicit_id:
        return explicit_id

    project_value = str(project or "").strip()
    if not project_value:
        raise ValueError("Не настроен YOUTRACK_PROJECT или YOUTRACK_PROJECT_ID")
    if re.fullmatch(r"\d+-\d+", project_value):
        return project_value

    req = urlrequest.Request(
        f"{base_url.rstrip('/')}/api/admin/projects?fields=id,shortName,name",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
        method="GET",
    )
    try:
        with _urlopen_without_proxy(req, timeout=30, ssl_verify=_normalize_bool(ssl_verify, default=True)) as resp:
            body = resp.read().decode("utf-8")
            projects = json.loads(body) if body else []
    except urlerror.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise ValueError(f"Не удалось определить project.id в YTrack, admin/projects вернул {exc.code}: {body}") from exc
    except Exception as exc:
        raise ValueError(f"Не удалось определить project.id в YTrack: {exc}") from exc

    project_value_lower = project_value.lower()
    for item in projects or []:
        item_id = str((item or {}).get("id") or "").strip()
        short_name = str((item or {}).get("shortName") or "").strip()
        name = str((item or {}).get("name") or "").strip()
        if not item_id:
            continue
        if short_name.lower() == project_value_lower or name.lower() == project_value_lower:
            return item_id

    raise ValueError(
        f"Не удалось найти project.id для YTrack проекта `{project_value}`. "
        "Укажите YOUTRACK_PROJECT_ID или проверьте YOUTRACK_PROJECT."
    )
