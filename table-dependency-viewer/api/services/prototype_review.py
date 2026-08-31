from __future__ import annotations

import json
import re
import ssl
import time
import uuid
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
DROP_TARGET_PATTERNS = [
    re.compile(r"\bdrop\s+(?:table|view)\s+(?:if\s+exists\s+)?([a-zA-Z0-9_`\"\.]+)", re.IGNORECASE),
]
CREATE_OBJECT_PATTERNS = [
    re.compile(r"\bcreate\s+(?:or\s+replace\s+)?table\s+(?:if\s+not\s+exists\s+)?([a-zA-Z0-9_`\"\.]+)", re.IGNORECASE),
    re.compile(r"\bcreate\s+(?:or\s+replace\s+)?view\s+([a-zA-Z0-9_`\"\.]+)", re.IGNORECASE),
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
        r"Бизнес[- ]ключ.*?:\s*(.+?)(?:\n\s*\n|\n[А-ЯA-Z][^:\n]{0,80}:|\nсвязана с|\nподзадача для|\Z)",
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


def _is_clickhouse_sql_path(path_value: str) -> bool:
    normalized = str(path_value or "").replace("\\", "/").lower()
    return "/clickhouse/" in normalized or normalized.startswith("clickhouse/")


def _sql_execution_priority(path_value: str) -> tuple[int, str]:
    name = str(path_value or "").replace("\\", "/").split("/")[-1].lower()
    if name.endswith("_recreate.sql") or "recreate" in name:
        return (0, name)
    if name.endswith("_insert_init.sql") or "insert_init" in name:
        return (1, name)
    return (2, name)


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
    source_sha = str(
        (mr or {}).get("sha")
        or ((mr or {}).get("diff_refs") or {}).get("head_sha")
        or source_branch
        or ""
    ).strip()
    files = []
    for item in changes or []:
        path_value = str(item.get("new_path") or item.get("old_path") or "").strip()
        if not path_value or not SQL_FILE_RE.search(path_value):
            continue
        encoded_path = urlparse.quote(path_value, safe="")
        raw_url = (
            f"{gitlab_api_url.rstrip('/')}/projects/"
            f"{urlparse.quote(mr_ref.project, safe='')}/repository/files/{encoded_path}/raw"
            f"?ref={urlparse.quote(source_sha, safe='')}"
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
            "source_sha": source_sha,
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


def infer_review_targets(files: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, dict[str, Any]] = {}
    order: list[str] = []
    for item in files:
        path_value = str(item.get("path") or "").strip()
        sql_text = str(item.get("sql") or "")
        statements = item.get("statements") or []
        targets: list[str] = []
        object_type = None
        has_create = False
        has_drop = False
        has_self_mutation = False

        for statement in statements:
            for pattern in TARGET_PATTERNS:
                for match in pattern.finditer(statement):
                    normalized = _normalize_fqn(match.group(1))
                    if normalized:
                        targets.append(normalized)
            for pattern in CREATE_OBJECT_PATTERNS:
                for match in pattern.finditer(statement):
                    normalized = _normalize_fqn(match.group(1))
                    if normalized:
                        targets.append(normalized)
                        has_create = True
                        if " view " in statement.lower() or statement.lower().lstrip().startswith("create view") or "or replace view" in statement.lower():
                            object_type = "VIEW"
                        elif object_type is None:
                            object_type = "TABLE"
            for pattern in DROP_TARGET_PATTERNS:
                for match in pattern.finditer(statement):
                    normalized = _normalize_fqn(match.group(1))
                    if normalized:
                        targets.append(normalized)
                        has_drop = True

        deduped_targets: list[str] = []
        seen: set[str] = set()
        for target in targets:
            if target not in seen:
                seen.add(target)
                deduped_targets.append(target)
        target_fqn = deduped_targets[-1] if deduped_targets else None
        if target_fqn:
            lowered_sql = _strip_sql_comments(sql_text).lower()
            has_self_mutation = any(
                token in lowered_sql
                for token in (
                    f"truncate table {target_fqn}",
                    f"truncate {target_fqn}",
                    f"delete from {target_fqn}",
                    f"drop table if exists {target_fqn}",
                    f"drop table {target_fqn}",
                    f"drop view if exists {target_fqn}",
                    f"drop view {target_fqn}",
                )
            )
        if object_type is None and target_fqn:
            object_type = "VIEW" if target_fqn.split(".", 1)[0].endswith("_view") else "TABLE"
        group_key = target_fqn or f"__path__:{path_value}"
        if group_key not in grouped:
            grouped[group_key] = {
                "path": path_value,
                "paths": [],
                "target_fqn": target_fqn,
                "all_targets": [],
                "object_type": object_type or "TABLE",
                "has_create": False,
                "has_drop": False,
                "has_self_mutation": False,
                "execution_paths": [],
                "skip_dev_execution": True,
            }
            order.append(group_key)
        group = grouped[group_key]
        group["paths"].append(path_value)
        group["all_targets"] = list(dict.fromkeys([*(group.get("all_targets") or []), *deduped_targets]))
        group["has_create"] = bool(group.get("has_create") or has_create)
        group["has_drop"] = bool(group.get("has_drop") or has_drop)
        group["has_self_mutation"] = bool(group.get("has_self_mutation") or has_self_mutation)
        if str(object_type or "").upper() == "VIEW":
            group["object_type"] = "VIEW"
        if not _is_clickhouse_sql_path(path_value):
            group["execution_paths"].append(path_value)
            group["skip_dev_execution"] = False
    result: list[dict[str, Any]] = []
    for group_key in order:
        group = grouped[group_key]
        target_fqn = str(group.get("target_fqn") or "").strip() or None
        execution_paths = sorted(list(dict.fromkeys(group.get("execution_paths") or [])), key=_sql_execution_priority)
        object_type = str(group.get("object_type") or "TABLE").upper()
        requires_pretruncate = bool(
            target_fqn
            and execution_paths
            and not group.get("has_create")
            and not group.get("has_drop")
            and not group.get("has_self_mutation")
            and object_type == "TABLE"
        )
        result.append(
            {
                "path": "\n".join(group.get("paths") or []),
                "paths": list(group.get("paths") or []),
                "target_fqn": target_fqn,
                "all_targets": list(group.get("all_targets") or []),
                "object_type": object_type,
                "requires_pretruncate": requires_pretruncate,
                "execution_paths": execution_paths,
                "skip_dev_execution": bool(group.get("skip_dev_execution")),
            }
        )
    return result


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


def execute_sql_review_items_in_dev(
    *,
    dev_database_url: str,
    files: list[dict[str, Any]],
    review_targets: list[dict[str, Any]],
    progress_callback=None,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    if not dev_database_url:
        raise ValueError("Не настроен DEV_DATABASE_URL")
    file_map = {str(item.get("path") or "").strip(): item for item in files}
    preparation_rows: list[dict[str, Any]] = []
    execution_rows: list[dict[str, Any]] = []
    exec_engine = create_engine(dev_database_url)
    connection = None
    cursor = None
    try:
        connection = exec_engine.raw_connection()
        cursor = connection.cursor()
        total = len(review_targets)
        for index, review_item in enumerate(review_targets, start=1):
            path_value = str(review_item.get("path") or "").strip()
            execution_paths = [str(item).strip() for item in (review_item.get("execution_paths") or []) if str(item).strip()]
            target_fqn = str(review_item.get("target_fqn") or "").strip()
            if callable(progress_callback):
                progress_callback(
                    {
                        "stage": "running_file",
                        "current": index,
                        "total": total,
                        "path": path_value,
                        "target_fqn": target_fqn or None,
                    }
                )
            if review_item.get("skip_dev_execution"):
                preparation_rows.append(
                    {
                        "status": "skipped",
                        "action": "truncate",
                        "target_fqn": target_fqn or None,
                        "message": "DEV выполнение не требуется для ClickHouse-объекта",
                        "duration_sec": 0.0,
                    }
                )
                execution_rows.append(
                    {
                        "path": path_value,
                        "target_fqn": target_fqn or None,
                        "status": "skipped",
                        "duration_sec": 0.0,
                        "message": "ClickHouse SQL не выполняется в DEV prototype review",
                    }
                )
                continue
            if review_item.get("requires_pretruncate") and target_fqn:
                try:
                    preparation_rows.append(
                        prepare_target_table_in_dev(
                            dev_database_url=dev_database_url,
                            target_fqn=target_fqn,
                        )
                    )
                except Exception as exc:
                    preparation_rows.append(
                        {
                            "status": "error",
                            "action": "truncate",
                            "target_fqn": target_fqn or None,
                            "message": f"Не удалось выполнить предварительную очистку: {exc}",
                            "duration_sec": 0.0,
                        }
                    )
            else:
                preparation_rows.append(
                    {
                        "status": "skipped",
                        "action": "truncate",
                        "target_fqn": target_fqn or None,
                        "message": "Предварительная очистка не требуется",
                        "duration_sec": 0.0,
                    }
                )
            if not execution_paths:
                execution_rows.append({"path": path_value, "target_fqn": target_fqn or None, "status": "skipped", "duration_sec": 0.0})
                continue
            total_duration = 0.0
            try:
                for exec_path in execution_paths:
                    file_item = file_map.get(exec_path) or {}
                    sql_text = str(file_item.get("sql") or "").strip()
                    if not sql_text:
                        continue
                    started = time.perf_counter()
                    cursor.execute(sql_text)
                    connection.commit()
                    total_duration += time.perf_counter() - started
                execution_rows.append(
                    {
                        "path": path_value,
                        "target_fqn": target_fqn or None,
                        "status": "ok",
                        "duration_sec": round(total_duration, 3),
                    }
                )
                if callable(progress_callback):
                    progress_callback(
                        {
                            "stage": "file_done",
                            "current": index,
                            "total": total,
                            "path": path_value,
                            "target_fqn": target_fqn or None,
                            "status": "ok",
                        }
                    )
            except Exception as exc:
                if connection is not None:
                    try:
                        connection.rollback()
                    except Exception:
                        pass
                execution_rows.append(
                    {
                        "path": path_value,
                        "target_fqn": target_fqn or None,
                        "status": "error",
                        "duration_sec": round(time.perf_counter() - started, 3),
                        "error_message": str(exc),
                    }
                )
                if callable(progress_callback):
                    progress_callback(
                        {
                            "stage": "file_done",
                            "current": index,
                            "total": total,
                            "path": path_value,
                            "target_fqn": target_fqn or None,
                            "status": "error",
                            "error_message": str(exc),
                        }
                    )
                continue
    except Exception as exc:
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
    return preparation_rows, execution_rows


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
    estimate_field_name: str = "Оценка (чел./час.)",
    card_type_field_name: str = "Тип карточки",
    card_type_value: str = "Task",
    assignee_field_name: str = "Assignee",
    assignee_query: str = "Suvorov Nikita",
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
    project_custom_fields = _get_ytrack_project_custom_fields(
        base_url=base_url,
        token=token,
        project_id=resolved_project_id,
        ssl_verify=ssl_verify,
    )
    custom_fields_payload: list[dict[str, Any]] = []

    estimate_field = _resolve_ytrack_custom_field(
        items=project_custom_fields,
        field_name=estimate_field_name,
        fallback_contains="оценк",
    )
    if estimate_field:
        custom_fields_payload.append(
            _build_ytrack_estimate_payload(
                estimate_field=estimate_field,
                default_estimate_minutes=default_estimate_minutes,
            )
        )

    card_type_field = _resolve_ytrack_custom_field(
        items=project_custom_fields,
        field_name=card_type_field_name,
    )
    if card_type_field and str(card_type_value or "").strip():
        custom_fields_payload.append(
            _build_ytrack_named_value_payload(
                field_item=card_type_field,
                raw_value=str(card_type_value).strip(),
            )
        )

    assignee_field = _resolve_ytrack_custom_field(
        items=project_custom_fields,
        field_name=assignee_field_name,
    )
    if assignee_field and str(assignee_query or "").strip():
        user_value = _resolve_ytrack_user_value(
            base_url=base_url,
            token=token,
            ssl_verify=ssl_verify,
            user_query=str(assignee_query).strip(),
        )
        if user_value:
            custom_fields_payload.append(
                _build_ytrack_user_payload(
                    field_item=assignee_field,
                    user_value=user_value,
                )
            )

    if custom_fields_payload:
        payload["customFields"] = custom_fields_payload
    req = urlrequest.Request(
        f"{base_url.rstrip('/')}/api/issues?fields=id,idReadable,key,summary",
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
    issue_id = data.get("idReadable") or data.get("key") or data.get("id")
    return {
        "status": "created",
        "issue_id": issue_id,
        "url": data.get("self"),
        "raw": data,
    }


def add_ytrack_issue_comment(
    *,
    base_url: str,
    token: str,
    issue_id: str,
    ssl_verify: str,
    text: str,
) -> dict[str, Any]:
    issue_value = str(issue_id or "").strip()
    comment_text = str(text or "").strip()
    if not issue_value:
        raise ValueError("Не передан issue_id для комментария YTrack")
    if not comment_text:
        raise ValueError("Пустой текст комментария YTrack")
    req = urlrequest.Request(
        (
            f"{base_url.rstrip('/')}/api/issues/"
            f"{urlparse.quote(issue_value, safe='')}/comments?fields=id,text,created"
        ),
        data=json.dumps({"text": comment_text}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    try:
        with _urlopen_without_proxy(req, timeout=30, ssl_verify=_normalize_bool(ssl_verify, default=True)) as resp:
            body = resp.read().decode("utf-8")
            return json.loads(body) if body else {}
    except urlerror.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise ValueError(f"YTrack comments вернул {exc.code}: {body}") from exc
    except Exception as exc:
        raise ValueError(f"Не удалось добавить комментарий в YTrack: {exc}") from exc


def _sanitize_attachment_name(value: str) -> str:
    name = str(value or "").strip().lower()
    if not name:
        return "prototype_review"
    sanitized = re.sub(r"[^a-z0-9._-]+", "_", name).strip("._-")
    return sanitized or "prototype_review"


def attach_ytrack_issue_files(
    *,
    base_url: str,
    token: str,
    issue_id: str,
    ssl_verify: str,
    files: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    issue_value = str(issue_id or "").strip()
    if not issue_value:
        raise ValueError("Не передан issue_id для вложений YTrack")
    upload_items = []
    for item in files or []:
        filename = str((item or {}).get("filename") or "").strip()
        content = (item or {}).get("content")
        if not filename or content in (None, ""):
            continue
        mime_type = str((item or {}).get("mime_type") or "text/plain; charset=utf-8").strip()
        upload_items.append(
            {
                "filename": filename,
                "content": str(content),
                "mime_type": mime_type,
            }
        )
    if not upload_items:
        return []

    boundary = f"----CodexYouTrackBoundary{uuid.uuid4().hex}"
    body = bytearray()
    for index, item in enumerate(upload_items, start=1):
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        disposition = (
            f'Content-Disposition: form-data; name="upload{index}"; '
            f'filename="{item["filename"]}"\r\n'
        )
        body.extend(disposition.encode("utf-8"))
        body.extend(f"Content-Type: {item['mime_type']}\r\n\r\n".encode("utf-8"))
        body.extend(item["content"].encode("utf-8"))
        body.extend(b"\r\n")
    body.extend(f"--{boundary}--\r\n".encode("utf-8"))

    req = urlrequest.Request(
        (
            f"{base_url.rstrip('/')}/api/issues/"
            f"{urlparse.quote(issue_value, safe='')}/attachments?fields=id,name,url,mimeType,size"
        ),
        data=bytes(body),
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
        method="POST",
    )
    try:
        with _urlopen_without_proxy(req, timeout=60, ssl_verify=_normalize_bool(ssl_verify, default=True)) as resp:
            payload = resp.read().decode("utf-8")
            return json.loads(payload) if payload else []
    except urlerror.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise ValueError(f"YTrack attachments вернул {exc.code}: {body}") from exc
    except Exception as exc:
        raise ValueError(f"Не удалось прикрепить файлы к задаче YTrack: {exc}") from exc


def _get_ytrack_project_custom_fields(
    *,
    base_url: str,
    token: str,
    project_id: str,
    ssl_verify: str,
) -> list[dict[str, Any]]:
    req = urlrequest.Request(
        (
            f"{base_url.rstrip('/')}/api/admin/projects/{urlparse.quote(project_id, safe='')}/customFields"
            "?fields=id,$type,canBeEmpty,field(name,fieldType(id,valueType))"
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
            return json.loads(body) if body else []
    except Exception:
        return []

def _resolve_ytrack_custom_field(
    *,
    items: list[dict[str, Any]],
    field_name: str,
    fallback_contains: str = "",
) -> dict[str, str] | None:
    configured_name = str(field_name or "").strip()
    configured_name_lower = configured_name.lower()
    fallback_match = None
    for item in items or []:
        item_id = str((item or {}).get("id") or "").strip()
        project_field_type = str((item or {}).get("$type") or "").strip()
        field = (item or {}).get("field") or {}
        field_name = str(field.get("name") or "").strip()
        field_type = field.get("fieldType") or {}
        field_type_id = str(field_type.get("id") or field_type.get("valueType") or "").strip().lower()
        field_value_type = str(field_type.get("valueType") or field_type.get("id") or "").strip().lower()
        if not field_name:
            continue
        issue_custom_field_type = _normalize_ytrack_issue_custom_field_type(project_field_type, field_type_id)
        if field_name.lower() == configured_name_lower:
            return {
                "id": item_id,
                "name": field_name,
                "issue_custom_field_type": issue_custom_field_type,
                "field_type_id": field_type_id,
                "field_value_type": field_value_type,
            }
        if fallback_match is None and fallback_contains and fallback_contains in field_name.lower():
            fallback_match = {
                "id": item_id,
                "name": field_name,
                "issue_custom_field_type": issue_custom_field_type,
                "field_type_id": field_type_id,
                "field_value_type": field_value_type,
            }
    return fallback_match


def _normalize_ytrack_issue_custom_field_type(project_field_type: str, field_type_id: str) -> str:
    # Re-pushed marker: backend YouTrack custom field mapping refreshed on 2026-08-26.
    if project_field_type == "EnumProjectCustomField":
        return "SingleEnumIssueCustomField"
    if project_field_type == "OwnedProjectCustomField":
        return "SingleOwnedIssueCustomField"
    if project_field_type == "UserProjectCustomField":
        return "SingleUserIssueCustomField"
    if project_field_type == "StateProjectCustomField":
        return "StateIssueCustomField"
    if project_field_type == "VersionProjectCustomField":
        return "SingleVersionIssueCustomField"
    if project_field_type.endswith("ProjectCustomField"):
        return f"{project_field_type[:-18]}IssueCustomField"
    if field_type_id == "period":
        return "PeriodIssueCustomField"
    return "SimpleIssueCustomField"


def _build_ytrack_estimate_payload(*, estimate_field: dict[str, str], default_estimate_minutes: int) -> dict[str, Any]:
    issue_custom_field_type = str(estimate_field.get("issue_custom_field_type") or "SimpleIssueCustomField").strip()
    field_value_type = str(estimate_field.get("field_value_type") or estimate_field.get("field_type_id") or "").strip().lower()
    minutes = max(1, int(default_estimate_minutes or 60))

    if field_value_type == "period" or issue_custom_field_type == "PeriodIssueCustomField":
        value: Any = {"minutes": minutes}
    elif field_value_type in {"integer", "int"}:
        value = minutes
    else:
        value = f"{minutes // 60 if minutes % 60 == 0 else round(minutes / 60, 2)}ч"

    payload = {
        "name": str(estimate_field.get("name") or "").strip(),
        "$type": issue_custom_field_type,
        "value": value,
    }
    field_id = str(estimate_field.get("id") or "").strip()
    if field_id:
        payload["id"] = field_id
    return payload


def _build_ytrack_named_value_payload(*, field_item: dict[str, str], raw_value: str) -> dict[str, Any]:
    payload = {
        "name": str(field_item.get("name") or "").strip(),
        "$type": str(field_item.get("issue_custom_field_type") or "SimpleIssueCustomField").strip(),
        "value": {"name": raw_value},
    }
    field_id = str(field_item.get("id") or "").strip()
    if field_id:
        payload["id"] = field_id
    return payload


def _build_ytrack_user_payload(*, field_item: dict[str, str], user_value: dict[str, str]) -> dict[str, Any]:
    payload = {
        "name": str(field_item.get("name") or "").strip(),
        "$type": str(field_item.get("issue_custom_field_type") or "SingleUserIssueCustomField").strip(),
        "value": user_value,
    }
    field_id = str(field_item.get("id") or "").strip()
    if field_id:
        payload["id"] = field_id
    return payload


def _resolve_ytrack_user_value(
    *,
    base_url: str,
    token: str,
    ssl_verify: str,
    user_query: str,
) -> dict[str, str] | None:
    query = str(user_query or "").strip()
    if not query:
        return None
    req = urlrequest.Request(
        (
            f"{base_url.rstrip('/')}/api/users"
            f"?fields=id,login,name,fullName,email&query={urlparse.quote(query, safe='')}"
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
        return None

    normalized_query = query.lower()
    for item in items or []:
        login = str((item or {}).get("login") or "").strip()
        name = str((item or {}).get("name") or "").strip()
        full_name = str((item or {}).get("fullName") or "").strip()
        email = str((item or {}).get("email") or "").strip()
        if normalized_query in {login.lower(), name.lower(), full_name.lower(), email.lower()}:
            return {"login": login} if login else {"name": full_name or name}

    first = (items or [None])[0]
    if not first:
        return None
    login = str((first or {}).get("login") or "").strip()
    name = str((first or {}).get("fullName") or (first or {}).get("name") or "").strip()
    return {"login": login} if login else {"name": name} if name else None


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
