from __future__ import annotations

from fastapi import FastAPI, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import List, Dict, Tuple, Set, Union, Any
from collections import deque
from pydantic import BaseModel
import os
import yaml

from datetime import datetime
from sqlalchemy import create_engine, text, bindparam
from typing import Optional
from pathlib import Path
from openpyxl import load_workbook
import traceback
from datetime import datetime, date, timedelta
from decimal import Decimal
import time
from typing import List, Dict, Tuple
from datetime import datetime
from sqlalchemy import text
import re
import json
import hashlib
import subprocess
import tempfile
from itertools import combinations

from fastapi import APIRouter, HTTPException



from .config import (
    TABLE_LOADING_HISTORY,
    TABLE_ENTITIES_META,
    TABLE_TABLES_META,
    TABLE_TABLE_COMPARE,
    TABLE_YT_SLA,
    TABLE_YTREK_INCIDENTS,
    TABLE_TABLES_META_CLICK,
    TABLE_DATA_QUALITY,
    TABLE_RELEASE_LOG,
    TABLE_RELEASE_OBJECTS,
    TABLE_YT_ISSUE_SNAPSHOT,
    TABLE_YT_ISSUE_CUSTOM,
    TABLE_YT_ISSUE_TIMELINE,
    TABLE_YT_ISSUE_WORKLOG,
    TABLE_YT_ISSUE_COMMENT,
    TABLE_CLICK_LOAD_RUN,
    TABLE_CLICK_LOAD_STAGE,
    CLICK_META_DIR,
    DEV_CLICK_META_DIR,
    ADMIN_CICD_SCRIPT,
    YTRACK_ISSUE_URL,
    DATABASE_URL,
    DEV_DATABASE_URL,
    DEV_META_DEPLOY_BASE_DIR,
    DEV_META_DEPLOY_HOST,
    DEV_META_DEPLOY_PASSWORD,
    DEV_META_DEPLOY_PORT,
    DEV_META_DEPLOY_SSH_KEY_PATH,
    DEV_META_DEPLOY_STRICT_HOST_KEY,
    DEV_META_DEPLOY_USER,
    AIRFLOW_DEV_BASE_URL,
    AIRFLOW_DEV_DAG_ID,
    AIRFLOW_DEV_USERNAME,
    AIRFLOW_DEV_PASSWORD,
    DEV_META_LOCK_TTL_MIN,
)


from .services.admin import refresh_application_caches, run_ci_cd_script
from .services.entities import fetch_entities
from .services.dev_meta import (
    acquire_dev_meta_lock,
    assert_dev_meta_lock_owner,
    deploy_dev_meta_file,
    generate_dev_meta_yaml,
    get_dev_meta_files,
    get_dev_meta_status,
    read_dev_meta_file,
    release_dev_meta_lock,
    save_dev_meta_file,
    trigger_airflow_dev_dag,
    validate_dev_meta_content,
)




from .auth import auth_middleware, init_auth, router as auth_router, get_current_user_from_request


app = FastAPI()
# CORS для взаимодействия с фронтом
app.add_middleware(
  CORSMiddleware,
  allow_origins=[
      "http://rgm-s-dwhapp01.hq.root.ad:15312",
      "http://rgm-s-dwhapp01.hq.root.ad",
  ],
  allow_credentials=True,
  allow_methods=["*"],
  allow_headers=["*"],
)

# Подключение
engine = create_engine(DATABASE_URL)
from fastapi import APIRouter, HTTPException

router = APIRouter()
print("BOOT FILE:", __file__)

init_auth()
app.middleware("http")(auth_middleware)
app.include_router(auth_router)

# admin ci_cd status (in-memory)
_ci_cd_status = {
    "last_run_at": None,
    "status": None,
    "return_code": None,
    "stdout": None,
    "stderr": None,
}


class DevMetaFilePayload(BaseModel):
    schema_name: str
    file_name: str
    source: Optional[str] = "dev"


class DevMetaLockPayload(BaseModel):
    schema_name: str
    file_name: str


class DevMetaSavePayload(BaseModel):
    schema_name: str
    file_name: str
    content: str


class DevMetaDagPayload(BaseModel):
    schema_name: str
    file_name: str


class DevMetaDeployPayload(BaseModel):
    schema_name: str
    file_name: str
    content: str


class DevMetaGeneratePayload(BaseModel):
    schema_name_gp: str
    object_name: str
    schema_name_click: str = "dm"
    greenplum_table_name: Optional[str] = None
    order_by: List[str]





@app.get("/api/health")
def healthcheck():
    return {"status": "ok"}


@router.post("/api/admin/refresh-cache")
def refresh_cache(request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")

    globals()["_cached_meta_index"] = None
    globals()["_cache_timestamp"] = 0
    globals()["_order_breaches_cache"] = None
    globals()["_order_breaches_ts"] = 0
    globals()["_graph_snapshot"] = None
    globals()["_graph_snapshot_ts"] = 0
    globals()["_graph_snapshot_hash"] = None
    globals()["_graph_cache"].clear()
    globals()["_graph_cache_ts"] = 0
    globals()["_graph_cache_meta_ts"] = 0
    globals()["_logic_audit_cache_payload"] = None
    globals()["_logic_audit_cache_ts"] = 0

    try:
        get_cached_meta_and_index()
        get_cached_order_breaches()
        get_graph_snapshot()
        _build_logic_audit_cache()
    except Exception as exc:
        print("❌ refresh cache error:", exc)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось обновить кеш")

    return {"status": "ok"}


@router.post("/api/admin/run-ci-cd")
def run_ci_cd(request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")

    script_path = Path(ADMIN_CICD_SCRIPT)
    if not script_path.is_absolute():
        script_path = (BASE_DIR / script_path).resolve()

    if not script_path.exists():
        raise HTTPException(status_code=404, detail=f"Скрипт не найден: {script_path}")
    if not script_path.is_file():
        raise HTTPException(status_code=400, detail="Путь скрипта должен указывать на файл")

    _ci_cd_status.update(
        {
            "last_run_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "status": "running",
            "return_code": None,
            "stdout": None,
            "stderr": None,
        }
    )

    try:
        result = subprocess.run(
            ["bash", str(script_path)],
            capture_output=True,
            text=True,
            timeout=900,
            cwd=str(script_path.parent),
            env=os.environ.copy(),
        )
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=500, detail="Скрипт выполняется слишком долго (timeout)")
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Не удалось запустить скрипт: {exc}")

    response = {
        "status": "ok" if result.returncode == 0 else "failed",
        "return_code": result.returncode,
        "stdout": (result.stdout or "").strip()[:2000],
        "stderr": (result.stderr or "").strip()[:2000],
        "last_run_at": _ci_cd_status.get("last_run_at"),
    }
    _ci_cd_status.update(response)
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=response)
    return response


@router.get("/api/admin/ci-cd/status")
def get_ci_cd_status(request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return _ci_cd_status


@router.get("/api/admin/dev-meta/status")
def get_admin_dev_meta_status(request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return get_dev_meta_status(
        engine=engine,
        base_dir=BASE_DIR,
        prod_root_value=CLICK_META_DIR,
        dev_root_value=DEV_CLICK_META_DIR,
        airflow_base_url=AIRFLOW_DEV_BASE_URL,
        airflow_dag_id=AIRFLOW_DEV_DAG_ID,
        lock_ttl_minutes=DEV_META_LOCK_TTL_MIN,
        dev_database_url=DEV_DATABASE_URL,
    )

@router.get("/api/admin/dev-meta/files")
def get_admin_dev_meta_files(request: Request, schema_name: str = Query("dm")):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    if schema_name not in {"dm", "dm_view"}:
        raise HTTPException(status_code=400, detail="schema_name must be dm or dm_view")
    return get_dev_meta_files(
        engine=engine,
        base_dir=BASE_DIR,
        prod_root_value=CLICK_META_DIR,
        dev_root_value=DEV_CLICK_META_DIR,
        schema_name=schema_name,
    )


@router.post("/api/admin/dev-meta/file")
def get_admin_dev_meta_file(payload: DevMetaFilePayload, request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    root = DEV_CLICK_META_DIR if payload.source != "prod" else CLICK_META_DIR
    try:
        return read_dev_meta_file(
            base_dir=BASE_DIR,
            root_value=root,
            schema_name=payload.schema_name,
            file_name=payload.file_name,
        )
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Файл не найден")


@router.post("/api/admin/dev-meta/generate")
def generate_admin_dev_meta(payload: DevMetaGeneratePayload, request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    try:
        result = generate_dev_meta_yaml(
            database_url=DEV_DATABASE_URL or DATABASE_URL,
            schema_name_gp=payload.schema_name_gp,
            object_name=payload.object_name,
            schema_name_click=payload.schema_name_click,
            greenplum_table_name=payload.greenplum_table_name,
            order_by=payload.order_by,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"status": "ok", **result}


@router.post("/api/admin/dev-meta/lock")
def lock_admin_dev_meta_file(payload: DevMetaLockPayload, request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    try:
        return acquire_dev_meta_lock(
            engine=engine,
            schema_name=payload.schema_name,
            file_name=payload.file_name,
            author=user.email,
            ttl_minutes=DEV_META_LOCK_TTL_MIN,
        )
    except PermissionError as exc:
        raise HTTPException(status_code=409, detail=str(exc))


@router.post("/api/admin/dev-meta/unlock")
def unlock_admin_dev_meta_file(payload: DevMetaLockPayload, request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    release_dev_meta_lock(
        engine=engine,
        schema_name=payload.schema_name,
        file_name=payload.file_name,
        author=user.email,
    )
    return {"status": "ok"}


@router.post("/api/admin/dev-meta/validate")
def validate_admin_dev_meta(payload: DevMetaSavePayload, request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return validate_dev_meta_content(
        content=payload.content,
        schema_name=payload.schema_name,
        dev_database_url=DEV_DATABASE_URL,
    )


@router.post("/api/admin/dev-meta/save")
def save_admin_dev_meta(payload: DevMetaSavePayload, request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    try:
        result = save_dev_meta_file(
            engine=engine,
            base_dir=BASE_DIR,
            dev_root_value=DEV_CLICK_META_DIR,
            schema_name=payload.schema_name,
            file_name=payload.file_name,
            content=payload.content,
            author=user.email,
            dev_database_url=DEV_DATABASE_URL,
        )
    except PermissionError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"status": "ok", **result}


@router.post("/api/admin/dev-meta/run-dag")
def run_admin_dev_meta_dag(payload: DevMetaDagPayload, request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    try:
        assert_dev_meta_lock_owner(
            engine=engine,
            schema_name=payload.schema_name,
            file_name=payload.file_name,
            author=user.email,
        )
        data = trigger_airflow_dev_dag(
            engine=engine,
            airflow_base_url=AIRFLOW_DEV_BASE_URL,
            dag_id=AIRFLOW_DEV_DAG_ID,
            username=AIRFLOW_DEV_USERNAME,
            password=AIRFLOW_DEV_PASSWORD,
            schema_name=payload.schema_name,
            file_name=payload.file_name,
            author=user.email,
        )
    except PermissionError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"status": "ok", "response": data}


@router.post("/api/admin/dev-meta/deploy")
def deploy_admin_dev_meta(payload: DevMetaDeployPayload, request: Request):
    user = get_current_user_from_request(request)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    try:
        result = deploy_dev_meta_file(
            engine=engine,
            base_dir=BASE_DIR,
            dev_root_value=DEV_CLICK_META_DIR,
            schema_name=payload.schema_name,
            file_name=payload.file_name,
            content=payload.content,
            author=user.email,
            dev_database_url=DEV_DATABASE_URL,
            host=DEV_META_DEPLOY_HOST,
            port=DEV_META_DEPLOY_PORT,
            user=DEV_META_DEPLOY_USER,
            password=DEV_META_DEPLOY_PASSWORD,
            remote_base_dir=DEV_META_DEPLOY_BASE_DIR,
            ssh_key_path=DEV_META_DEPLOY_SSH_KEY_PATH,
            strict_host_key=DEV_META_DEPLOY_STRICT_HOST_KEY,
        )
    except PermissionError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"status": "ok", **result}

# Модель для ответа зависимостей
class DependencyItem(BaseModel):
    step: int
    schema: str
    table_name: str
    entity_id: int
    entity_name: str = None
    start_time: str = None
    avg_duration_minutes: Optional[float] = None
    depth: int = 0
    path: Optional[List[str]] = None


TOP_DIRS = [
    "BI_FI",
    "BI_INVESTMENT",
    "BI_TAXES",
    "CASE_4",
    "DICT_LOADER",
    "MISHKADEV_TABLES",
    "FI_COUNTERPARTY",
    "ISUIP_INVESTMENT",
    "LOGISTICS",
    "TRANSPORTATION",
    "BI_SB_WUC",
    "BI_FI_FACT_PAYMENTS",
    "STG_LOADER",
    "SD_STOCKS",
    "SALES_SHIPMENT_FROM_PLANT",
    "SALES_MM",
    "SALES_MARGIN",
    "MANAGEMENT_REPORTING_1",
    "TEST_SAP_ODATA_DELTA",
    "SALES_2HOUR",
]

ENTITY_GROUP_SUFFIX_RE = re.compile(r"^(.*?)(?:[_-]\d+)$", re.IGNORECASE)


def _normalize_entity_group(name: Optional[str]) -> Optional[str]:
    if not name:
        return None
    cleaned = str(name).strip()
    if not cleaned:
        return None
    lowered = cleaned.lower()
    match = ENTITY_GROUP_SUFFIX_RE.match(lowered)
    if match:
        base = match.group(1).strip()
        return base or lowered
    return lowered

_cached_meta_index = None
_cache_timestamp = 0

_graph_snapshot = None
_graph_snapshot_ts = 0
_graph_snapshot_hash = None
_GRAPH_SNAPSHOT_TTL = 86400  # 24 часа
_CACHE_TTL = 86400  # 24 часа

_order_breaches_cache = None
_order_breaches_ts = 0
_ORDER_BREACHES_TTL = 300  # 5 минут

_graph_cache = {}
_graph_cache_ts = 0
_GRAPH_CACHE_TTL = 86400  # 24 часа
_graph_cache_meta_ts = 0

_logic_audit_cache_payload = None
_logic_audit_cache_ts = 0
_LOGIC_AUDIT_CACHE_TTL = 86400

SQL_STOPWORDS = {
    "select", "from", "where", "join", "left", "right", "inner", "outer", "full", "on",
    "and", "or", "not", "null", "is", "as", "case", "when", "then", "else", "end",
    "group", "by", "order", "limit", "with", "distinct", "union", "all", "into", "insert",
    "create", "table", "truncate", "having", "over", "partition", "rows", "range",
}

SQL_FUNCTION_BLACKLIST = {
    "select", "from", "where", "group", "order", "when", "then", "else", "end", "and", "or",
    "in", "on", "over", "partition", "by", "as",
}

SQL_FUNCTION_COMMON_PREFIXES = (
    "util_text_to_",
)


def _strip_sql_comments(sql_text: str) -> str:
    if not sql_text:
        return ""
    text_wo_block = re.sub(r"/\*.*?\*/", " ", sql_text, flags=re.S)
    text_wo_inline = re.sub(r"--.*?$", " ", text_wo_block, flags=re.M)
    return text_wo_inline


def _normalize_sql(sql_text: str) -> str:
    text = _strip_sql_comments(sql_text).lower()
    text = text.replace("`", "").replace('"', "")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _tokenize_sql(sql_text: str) -> set[str]:
    tokens = set(re.findall(r"[a-z_][a-z0-9_]*", sql_text))
    return {t for t in tokens if t not in SQL_STOPWORDS and len(t) > 2}


def _canonical_source_name(name: str) -> str:
    raw = (name or "").strip().strip(",")
    if not raw:
        return ""
    raw = raw.split()[0]
    # remove typical temporary table patterns to group stable base logic
    raw = re.sub(r"^(tmp_|temp_|cte_)", "", raw)
    raw = re.sub(r"(_tmp|_temp)$", "", raw)
    raw = re.sub(r"_[0-9]{6,}$", "", raw)
    raw = raw.replace('"', "").replace("`", "")
    return raw


def _extract_source_tables(normalized_sql: str) -> set[str]:
    tables = set()
    for match in re.finditer(r"\b(from|join)\s+([a-z0-9_./]+)", normalized_sql):
        cleaned = _canonical_source_name(match.group(2) or "")
        if cleaned and cleaned not in {"select"}:
            tables.add(cleaned)
    return tables


def _extract_functions(normalized_sql: str) -> set[str]:
    funcs = set()
    for fn in re.findall(r"\b([a-z_][a-z0-9_]*)\s*\(", normalized_sql):
        if fn not in SQL_FUNCTION_BLACKLIST:
            funcs.add(fn)
    return funcs


def _is_common_function(fn: str, freq_map: dict[str, int], total_objects: int) -> bool:
    if not fn:
        return True
    if any(fn.startswith(prefix) for prefix in SQL_FUNCTION_COMMON_PREFIXES):
        return True
    if total_objects <= 0:
        return False
    frequency = freq_map.get(fn, 0) / total_objects
    return frequency >= 0.35


def _extract_where_clause(normalized_sql: str) -> str:
    match = re.search(r"\bwhere\b(.*?)(\bgroup\s+by\b|\border\s+by\b|\blimit\b|$)", normalized_sql, flags=re.S)
    return (match.group(1) or "").strip() if match else ""


def _split_top_level(text: str) -> list[str]:
    if not text:
        return []
    parts = []
    buf = []
    level = 0
    for ch in text:
        if ch == "(":
            level += 1
        elif ch == ")" and level > 0:
            level -= 1
        if ch == "," and level == 0:
            piece = "".join(buf).strip()
            if piece:
                parts.append(piece)
            buf = []
            continue
        buf.append(ch)
    tail = "".join(buf).strip()
    if tail:
        parts.append(tail)
    return parts


def _extract_select_targets(normalized_sql: str) -> list[dict]:
    match = re.search(r"\bselect\b(.*?)(\bfrom\b)", normalized_sql, flags=re.S)
    if not match:
        return []
    body = (match.group(1) or "").strip()
    targets = []
    for expr in _split_top_level(body):
        alias_match = re.search(r"\bas\s+([a-z_][a-z0-9_]*)\s*$", expr)
        alias = alias_match.group(1) if alias_match else None
        targets.append({
            "expression": expr,
            "alias": alias,
        })
    return targets


def _expression_signature(expr: str) -> tuple[str, set[str]]:
    normalized = re.sub(r"\s+", " ", (expr or "").strip().lower())
    normalized = normalized.replace('"', "").replace("`", "")
    tokens = _tokenize_sql(normalized)
    expr_hash = hashlib.sha1(normalized.encode("utf-8")).hexdigest()
    return expr_hash, tokens


def _jaccard_similarity(a: set[str], b: set[str]) -> float:
    if not a and not b:
        return 1.0
    if not a or not b:
        return 0.0
    inter = len(a & b)
    union = len(a | b)
    return inter / union if union else 0.0


def _build_story(obj: dict) -> str:
    checks = obj.get("verification") or []
    keys = obj.get("key_attributes") or []
    sources = sorted(obj.get("source_tables") or [])
    funcs = sorted(obj.get("signal_functions") or obj.get("functions") or [])
    depends_on = obj.get("depends_on") or {}
    layers = ", ".join(sorted(depends_on.keys())) if depends_on else "не заданы"
    parts = [
        f"{obj.get('fqn')} ({obj.get('entity_name') or 'UNKNOWN'})",
        f"Режим загрузки: {obj.get('table_load_mode') or 'N/A'}",
        f"Слои зависимостей: {layers}",
        f"Ключевые поля: {', '.join(keys[:8]) if keys else 'не указаны'}",
        f"Проверки: {', '.join(checks) if checks else 'не указаны'}",
        f"SQL-функции: {', '.join(funcs[:10]) if funcs else 'не найдены'}",
        f"Источники SQL: {', '.join(sources[:8]) if sources else 'не найдены'}",
    ]
    return " | ".join(parts)


def _extract_field_descriptions(meta: dict) -> list[dict]:
    result = []
    for key in ("columns", "fields", "attributes", "column_descriptions"):
        value = meta.get(key)
        if isinstance(value, list):
            for item in value:
                if not isinstance(item, dict):
                    continue
                name = item.get("name") or item.get("column") or item.get("field")
                descr = item.get("description") or item.get("comment") or item.get("caption")
                if name and descr:
                    result.append({"name": str(name), "description": str(descr)})
        elif isinstance(value, dict):
            for name, descr in value.items():
                if name and descr:
                    result.append({"name": str(name), "description": str(descr)})
    dedup = {}
    for row in result:
        dedup[row["name"]] = row["description"]
    return [{"name": k, "description": v} for k, v in dedup.items()]


def _build_diff_hints(left: dict, right: dict) -> list[str]:
    hints = []
    src_left = left.get("source_tables") or set()
    src_right = right.get("source_tables") or set()
    fn_left = left.get("signal_functions") or set()
    fn_right = right.get("signal_functions") or set()
    where_left = left.get("where_clause") or ""
    where_right = right.get("where_clause") or ""
    if src_left != src_right:
        hints.append("Разные источники в FROM/JOIN")
    if fn_left != fn_right:
        hints.append("Отличаются используемые SQL-функции")
    if where_left != where_right:
        hints.append("Отличаются условия WHERE")
    if not hints:
        hints.append("Логика почти идентична, различия минимальны")
    return hints


def _build_pair_comparison(left: dict, right: dict) -> dict:
    left_sources = left.get("source_tables") or set()
    right_sources = right.get("source_tables") or set()
    left_functions = left.get("signal_functions") or set()
    right_functions = right.get("signal_functions") or set()

    left_aliases = {x.get("alias") for x in (left.get("select_targets") or []) if x.get("alias")}
    right_aliases = {x.get("alias") for x in (right.get("select_targets") or []) if x.get("alias")}

    left_keys = {str(x).lower() for x in (left.get("key_attributes") or []) if str(x).strip()}
    right_keys = {str(x).lower() for x in (right.get("key_attributes") or []) if str(x).strip()}

    left_where = (left.get("where_clause") or "").strip()
    right_where = (right.get("where_clause") or "").strip()

    left_common_fields = {
        str(row.get("name")).strip().lower()
        for row in (left.get("field_descriptions") or [])
        if row.get("name")
    }
    right_common_fields = {
        str(row.get("name")).strip().lower()
        for row in (right.get("field_descriptions") or [])
        if row.get("name")
    }

    same = []
    if left_sources & right_sources:
        same.append({"label": "Общие источники", "items": sorted(left_sources & right_sources)[:14]})
    if left_functions & right_functions:
        same.append({"label": "Общие бизнес-функции", "items": sorted(left_functions & right_functions)[:14]})
    if left_aliases & right_aliases:
        same.append({"label": "Одинаковые алиасы в SELECT", "items": sorted(left_aliases & right_aliases)[:14]})
    if left_keys & right_keys:
        same.append({"label": "Общие ключевые поля", "items": sorted(left_keys & right_keys)[:14]})
    if left_common_fields & right_common_fields:
        same.append({"label": "Совпадающие описанные поля", "items": sorted(left_common_fields & right_common_fields)[:14]})
    if left_where and right_where and left_where == right_where:
        same.append({"label": "WHERE совпадает", "items": [left_where[:220]]})

    different = []
    if left_sources - right_sources:
        different.append({"label": "Источники только в левом объекте", "items": sorted(left_sources - right_sources)[:14]})
    if right_sources - left_sources:
        different.append({"label": "Источники только в правом объекте", "items": sorted(right_sources - left_sources)[:14]})
    if left_functions - right_functions:
        different.append({"label": "Функции только в левом объекте", "items": sorted(left_functions - right_functions)[:14]})
    if right_functions - left_functions:
        different.append({"label": "Функции только в правом объекте", "items": sorted(right_functions - left_functions)[:14]})
    if left_aliases - right_aliases:
        different.append({"label": "Алиасы только в левом объекте", "items": sorted(left_aliases - right_aliases)[:14]})
    if right_aliases - left_aliases:
        different.append({"label": "Алиасы только в правом объекте", "items": sorted(right_aliases - left_aliases)[:14]})
    if left_where != right_where:
        if left_where:
            different.append({"label": "WHERE (левый объект)", "items": [left_where[:220]]})
        if right_where:
            different.append({"label": "WHERE (правый объект)", "items": [right_where[:220]]})

    return {
        "same": same,
        "different": different,
    }


def _build_pair_explanation(record: dict, left: dict, right: dict, comparison: dict) -> dict:
    score = record.get("score") or 0
    expr_overlap = record.get("expression_overlap_count") or 0
    merge_potential = record.get("merge_potential") or "LOW"
    diff_hints = record.get("diff_hints") or []

    if merge_potential == "HIGH":
        decision = "Пара выглядит как хороший кандидат на объединение в один расчёт."
    elif merge_potential == "MEDIUM":
        decision = "Логику лучше унифицировать, но сначала сверить бизнес-правила."
    else:
        decision = "Пока лучше оставить отдельно и явно зафиксировать различия."

    left_fields = left.get("field_descriptions") or []
    right_fields = right.get("field_descriptions") or []
    common_field_names = sorted(
        {row.get("name") for row in left_fields if row.get("name")}
        & {row.get("name") for row in right_fields if row.get("name")}
    )

    same_labels = [x.get("label") for x in (comparison.get("same") or []) if x.get("label")]
    diff_labels = [x.get("label") for x in (comparison.get("different") or []) if x.get("label")]
    diff_text = ", ".join(diff_labels[:2]) if diff_labels else ", ".join(diff_hints[:2]) or "критичных отличий не видно"
    summary = (
        f"{left.get('fqn')} и {right.get('fqn')} похожи на {round(score * 100)}%. "
        f"Совпадающих выражений SELECT: {expr_overlap}. "
        f"Совпадает: {', '.join(same_labels[:2]) if same_labels else 'базовый SQL-паттерн'}. "
        f"Отличается: {diff_text}."
    )

    return {
        "summary": summary,
        "decision": decision,
        "common_fields": common_field_names[:12],
        "left_field_docs_count": len(left_fields),
        "right_field_docs_count": len(right_fields),
    }


def _calc_logic_similarity(left: dict, right: dict) -> float:
    token_sim = _jaccard_similarity(left["tokens"], right["tokens"])
    source_sim = _jaccard_similarity(left["source_tables"], right["source_tables"])
    function_sim = _jaccard_similarity(left.get("signal_functions") or set(), right.get("signal_functions") or set())
    expr_exact_count = len((left.get("expr_hashes") or set()) & (right.get("expr_hashes") or set()))
    expr_exact_den = max(min(len(left.get("expr_hashes") or []), len(right.get("expr_hashes") or [])), 1)
    expr_exact_sim = expr_exact_count / expr_exact_den
    expr_token_sim = _jaccard_similarity(left.get("expr_token_union") or set(), right.get("expr_token_union") or set())
    expr_sim = 0.6 * expr_exact_sim + 0.4 * expr_token_sim

    score = 0.35 * token_sim + 0.25 * source_sim + 0.15 * function_sim + 0.25 * expr_sim
    if left["sql_hash"] == right["sql_hash"]:
        score = 1.0
    return round(score, 4), {
        "expr_exact_count": expr_exact_count,
        "expr_exact_sim": round(expr_exact_sim, 4),
        "expr_token_sim": round(expr_token_sim, 4),
    }


def _build_logic_object(meta_path: Path) -> Optional[dict]:
    try:
        meta = yaml.safe_load(meta_path.read_text("utf-8")) or {}
    except Exception:
        return None

    schema = (meta.get("table_schema") or "").strip().lower()
    table = (meta.get("table_name") or "").strip().lower()
    if not schema or not table:
        return None

    sql_candidates = [
        meta_path.parent / "sql_query_insert_init.sql",
        meta_path.parent / "sql_query_recreate_init.sql",
    ]
    sql_path = next((p for p in sql_candidates if p.exists()), None)
    sql_text = sql_path.read_text("utf-8", errors="ignore") if sql_path else ""
    normalized_sql = _normalize_sql(sql_text)
    if not normalized_sql:
        return None
    select_targets = _extract_select_targets(normalized_sql)[:25]
    expr_hashes = set()
    expr_token_union = set()
    for target in select_targets:
        expr_hash, expr_tokens = _expression_signature(target.get("expression") or "")
        expr_hashes.add(expr_hash)
        expr_token_union |= expr_tokens

    return {
        "fqn": f"{schema}.{table}",
        "schema": schema,
        "table": table,
        "entity_name": meta.get("entity_name"),
        "entity_id": meta.get("entity_id"),
        "table_id": meta.get("table_id"),
        "table_load_mode": meta.get("table_load_mode"),
        "depends_on": meta.get("depends_on") or {},
        "field_descriptions": _extract_field_descriptions(meta),
        "key_attributes": list(meta.get("key_attributes") or []),
        "verification": list(meta.get("verification") or []),
        "sql_path": str(sql_path) if sql_path else None,
        "sql_hash": hashlib.sha1(normalized_sql.encode("utf-8")).hexdigest(),
        "sql_preview": normalized_sql[:700],
        "tokens": _tokenize_sql(normalized_sql),
        "source_tables": _extract_source_tables(normalized_sql),
        "functions": _extract_functions(normalized_sql),
        "where_clause": _extract_where_clause(normalized_sql),
        "select_targets": select_targets,
        "expr_hashes": expr_hashes,
        "expr_token_union": expr_token_union,
    }


def _build_logic_audit_cache():
    global _logic_audit_cache_payload, _logic_audit_cache_ts
    now = time.time()
    if _logic_audit_cache_payload and now - _logic_audit_cache_ts < _LOGIC_AUDIT_CACHE_TTL:
        return _logic_audit_cache_payload

    objects = []
    for root_dir in iter_meta_dirs():
        for root, _, files in os.walk(root_dir):
            if "meta_data_file.yaml" not in files:
                continue
            obj = _build_logic_object(Path(root) / "meta_data_file.yaml")
            if obj:
                objects.append(obj)

    function_freq = {}
    total_objects = len(objects)
    for obj in objects:
        for fn in obj.get("functions") or set():
            function_freq[fn] = function_freq.get(fn, 0) + 1

    for obj in objects:
        filtered = {
            fn for fn in (obj.get("functions") or set())
            if not _is_common_function(fn, function_freq, total_objects)
        }
        obj["signal_functions"] = filtered
        obj["story"] = _build_story(obj)

    objects_index = {}
    for obj in objects:
        objects_index[obj["fqn"]] = {
            "fqn": obj.get("fqn"),
            "schema": obj.get("schema"),
            "table": obj.get("table"),
            "entity_name": obj.get("entity_name"),
            "table_load_mode": obj.get("table_load_mode"),
            "story": obj.get("story"),
            "source_tables": sorted(obj.get("source_tables") or []),
            "functions": sorted(obj.get("signal_functions") or []),
            "where_clause": obj.get("where_clause"),
            "select_targets": (obj.get("select_targets") or [])[:12],
            "field_descriptions": (obj.get("field_descriptions") or [])[:40],
            "sql_path": obj.get("sql_path"),
        }

    pairs = []
    pair_index = {}
    for left, right in combinations(objects, 2):
        if left["fqn"] == right["fqn"]:
            continue
        # dm_view рассматриваем только внутри dm_view (1-1 view слой)
        if (left["schema"] == "dm_view") != (right["schema"] == "dm_view"):
            continue
        # быстрый pre-filter
        if not (left["source_tables"] & right["source_tables"] or left["signal_functions"] & right["signal_functions"]):
            continue

        score, sim_meta = _calc_logic_similarity(left, right)
        if score < 0.72:
            continue

        if left["sql_hash"] == right["sql_hash"]:
            issue_type = "duplicate_exact"
            merge_potential = "HIGH"
        elif score >= 0.86:
            issue_type = "duplicate_candidate"
            merge_potential = "HIGH"
        elif score >= 0.78:
            issue_type = "similar_candidate"
            merge_potential = "MEDIUM"
        else:
            issue_type = "similar_candidate"
            merge_potential = "LOW"

        pair_key = "|".join(sorted([left["fqn"], right["fqn"]]))
        pair_id = hashlib.sha1(pair_key.encode("utf-8")).hexdigest()[:16]
        diff_hints = _build_diff_hints(left, right)
        record = {
            "pair_id": pair_id,
            "left_fqn": left["fqn"],
            "right_fqn": right["fqn"],
            "left_entity": left.get("entity_name"),
            "right_entity": right.get("entity_name"),
            "score": score,
            "expression_overlap_count": sim_meta.get("expr_exact_count", 0),
            "expression_overlap_score": sim_meta.get("expr_exact_sim", 0),
            "issue_type": issue_type,
            "merge_potential": merge_potential,
            "diff_hints": diff_hints,
        }
        pairs.append(record)
        comparison = _build_pair_comparison(left, right)
        explanation = _build_pair_explanation(record, left, right, comparison)
        pair_index[pair_id] = {
            **record,
            "explanation": explanation,
            "comparison": comparison,
            "left": {
                k: v for k, v in left.items()
                if k not in {"tokens", "source_tables", "functions", "expr_hashes", "expr_token_union"}
            },
            "right": {
                k: v for k, v in right.items()
                if k not in {"tokens", "source_tables", "functions", "expr_hashes", "expr_token_union"}
            },
            "left_features": {
                "tokens_count": len(left["tokens"]),
                "source_tables": sorted(left["source_tables"]),
                "functions": sorted(left.get("signal_functions") or []),
            },
            "right_features": {
                "tokens_count": len(right["tokens"]),
                "source_tables": sorted(right["source_tables"]),
                "functions": sorted(right.get("signal_functions") or []),
            },
        }

    pairs.sort(key=lambda row: (row["score"], row["merge_potential"]), reverse=True)
    payload = {
        "generated_at": datetime.utcnow().isoformat(),
        "objects_count": len(objects),
        "pairs_count": len(pairs),
        "pairs": pairs,
        "pair_index": pair_index,
        "objects_index": objects_index,
    }
    _logic_audit_cache_payload = payload
    _logic_audit_cache_ts = now
    return payload

def compute_order_breaches():
    """
    ТЯЖЁЛАЯ логика расчёта order breaches.
    НИЧЕГО НЕ ЗНАЕТ ПРО HTTP.
    """
    resp = get_dependency_violations()
    rows = json.loads(resp.body)

    entity_map = _entity_map_from_meta()
    grouped = {}

    for r in rows:
        target = f"{r['dependent_schema']}.{r['dependent_table']}"
        source = f"{r['source_schema']}.{r['source_table']}"

        src_time = datetime.fromisoformat(r["source_last_load"])
        tgt_time = datetime.fromisoformat(r["dependent_last_load"])
        gap_sec = (src_time - tgt_time).total_seconds()

        g = grouped.setdefault(target, {
            "target_fqn": target,
            "target_last_load": r["dependent_last_load"],
            "worst_upstream": None,
            "worst_upstream_time": None,
            "worst_gap_sec": 0,
            "violations": [],
            "_seen": set(),
        })

        dedupe_key = (source, r["source_last_load"], r["dependent_last_load"])
        if dedupe_key in g["_seen"]:
            continue
        g["_seen"].add(dedupe_key)

        g["violations"].append({
            "source_fqn": source,
            "gap_sec": gap_sec,
            "source_last_load": r["source_last_load"],
            "dependent_last_load": r["dependent_last_load"],
        })

        if gap_sec > g["worst_gap_sec"]:
            g["worst_gap_sec"] = gap_sec
            g["worst_upstream"] = source
            g["worst_upstream_time"] = r["source_last_load"]

    result = []
    for g in grouped.values():
        gap_min = g["worst_gap_sec"] / 60
        if gap_min > 30:
            sev = "CRITICAL"
        elif gap_min > 5:
            sev = "MAJOR"
        else:
            sev = "WARNING"

        g["severity"] = sev
        g["gap_minutes"] = round(gap_min, 1)
        g["violations_count"] = len(g["violations"])
        g.pop("_seen", None)
        result.append(g)

    result.sort(key=lambda x: x["worst_gap_sec"], reverse=True)
    return result

def get_cached_order_breaches():
    global _order_breaches_cache, _order_breaches_ts

    now = time.time()
    if _order_breaches_cache and now - _order_breaches_ts < _ORDER_BREACHES_TTL:
        return _order_breaches_cache

    print("⚠️ rebuilding orderbreaches cache")
    result = compute_order_breaches()

    _order_breaches_cache = result
    _order_breaches_ts = now
    return result

def get_cached_meta_and_index():
    global _cached_meta_index, _cache_timestamp
    now = time.time()
    if _cached_meta_index and now - _cache_timestamp < _CACHE_TTL:
        return _cached_meta_index

    all_meta = []
    seen = set()
    for entity_root in iter_meta_dirs():
        for root, _, files in os.walk(entity_root):
            if "meta_data_file.yaml" not in files:
                continue
            path = Path(root) / "meta_data_file.yaml"
            try:
                meta = yaml.safe_load(path.read_text("utf-8")) or {}
                schema = norm(meta.get("table_schema"))
                table = norm(meta.get("table_name"))
                if not schema or not table:
                    continue
                key = f"{schema}.{table}"
                seen.add(key)
                depends_on = {}
                for src_schema, tables in (meta.get("depends_on") or {}).items():
                    src_schema_norm = norm(src_schema)
                    if not src_schema_norm:
                        continue
                    cleaned = [norm(t) for t in (tables or []) if t]
                    depends_on[src_schema_norm] = [t for t in cleaned if t]
                all_meta.append({
                    "table_schema": schema,
                    "table_name": table,
                    "entity_id": meta.get("entity_id"),
                    "entity_name": meta.get("entity_name"),
                    "depends_on": depends_on,
                    "table_id": meta.get("table_id"),
                })
            except Exception as e:
                print("META ERROR:", path, e)

    print("META COUNT:", len(seen))
    print("META SAMPLE:", sorted(list(seen))[:30])

    meta_lookup = {
        (m.get("table_schema"), m.get("table_name"))
        for m in all_meta
        if m.get("table_schema") and m.get("table_name")
    }
    reverse = {}
    for m in all_meta:
        consumer = (m["table_schema"], m["table_name"])
        for src_schema, tables in m["depends_on"].items():
            for src_table in tables:
                if (src_schema or "").lower() in ("raw_ext", "dict_raw_ext"):
                    continue
                if (src_schema, src_table) not in meta_lookup:
                    print(
                        "❌ BROKEN DEP:",
                        f"{consumer[0]}.{consumer[1]}",
                        "depends on",
                        f"{src_schema}.{src_table}",
                        "BUT META NOT FOUND",
                    )
                reverse.setdefault((src_schema, src_table), []).append({
                    "schema": consumer[0],
                    "table_name": consumer[1],
                    "entity_id": m["entity_id"],
                    "entity_name": m["entity_name"],
                    "table_id": m["table_id"],
                })

    _cached_meta_index = (all_meta, reverse)
    _cache_timestamp = now
    return _cached_meta_index

def norm(s: Optional[str]) -> Optional[str]:
    return s.lower() if isinstance(s, str) else s


def _hash_meta(all_meta: list[dict]) -> str:
    items = []
    for m in all_meta:
        items.append({
            "table_schema": m.get("table_schema"),
            "table_name": m.get("table_name"),
            "entity_name": m.get("entity_name"),
            "depends_on": m.get("depends_on") or {},
            "table_id": m.get("table_id"),
        })
    payload = json.dumps(items, ensure_ascii=True, sort_keys=True)
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()


def _estimate_node_width(label: str, min_width: int = 160, max_width: int = 420) -> int:
    base = 120
    per_char = 7
    width = base + (len(label or "") * per_char)
    return max(min_width, min(max_width, width))


def _find_sccs(nodes: list[str], edges: list[dict]) -> list[list[str]]:
    adj = {n: [] for n in nodes}
    for e in edges:
        src = e.get("source")
        tgt = e.get("target")
        if src in adj and tgt:
            adj[src].append(tgt)

    index = 0
    stack = []
    on_stack = set()
    indices = {}
    lowlinks = {}
    sccs = []

    def strongconnect(v):
        nonlocal index
        indices[v] = index
        lowlinks[v] = index
        index += 1
        stack.append(v)
        on_stack.add(v)

        for w in adj.get(v, []):
            if w not in indices:
                strongconnect(w)
                lowlinks[v] = min(lowlinks[v], lowlinks[w])
            elif w in on_stack:
                lowlinks[v] = min(lowlinks[v], indices[w])

        if lowlinks[v] == indices[v]:
            scc = []
            while stack:
                w = stack.pop()
                on_stack.remove(w)
                scc.append(w)
                if w == v:
                    break
            sccs.append(scc)

    for n in nodes:
        if n not in indices:
            strongconnect(n)

    return sccs


def _layer_of_table(fqn: str) -> str:
    if not fqn or "." not in fqn:
        return "other"
    schema = fqn.split(".", 1)[0]
    schema_norm = schema.lower()
    if schema_norm in ("dict", "dict_stg", "dict_ods", "dict_dds"):
        if "dict_ods" in fqn or schema_norm == "dict_ods":
            return "dict_ods"
        if "dict_dds" in fqn or schema_norm == "dict_dds":
            return "dict_dds"
        return "dict_stg"
    if schema_norm in ("raw_ext", "dict_raw_ext"):
        return "raw_ext"
    if schema_norm in ("stg", "ods", "dds", "dm", "dm_calc", "dm_view", "landing", "raw_ext"):
        return schema_norm
    return "other"


def _grid_layout_table(table_nodes: dict, edges: list[dict]) -> dict:
    order = ["raw_ext", "landing", "dict_stg", "dict_ods", "dict_dds", "stg", "ods", "dds", "dm_calc", "dm", "dm_view", "other"]
    columns = {key: [] for key in order}
    for node_id in table_nodes:
        layer = _layer_of_table(node_id)
        columns.setdefault(layer, []).append(node_id)

    col_gap = 180
    row_gap = 140
    layout = {}
    cursor_x = 0
    layer_index = {layer: idx for idx, layer in enumerate(order)}
    neighbors = {node_id: [] for node_id in table_nodes}
    for edge in edges or []:
        src = edge.get("source")
        tgt = edge.get("target")
        if src in table_nodes and tgt in table_nodes:
            neighbors[src].append(layer_index.get(_layer_of_table(tgt), 0))
            neighbors[tgt].append(layer_index.get(_layer_of_table(src), 0))
    for layer in order:
        items = columns.get(layer) or []
        if not items:
            continue
        items.sort(key=lambda n: (sum(neighbors.get(n) or [0]) / max(len(neighbors.get(n) or [1]), 1), n))
        max_width = max(table_nodes[n].get("width") or 0 for n in items)
        column_center = cursor_x + (max_width / 2)
        for row_idx, node_id in enumerate(items):
            layout[node_id] = {"x": column_center, "y": row_idx * row_gap}
        cursor_x += max_width + col_gap

    return layout


def _grid_layout_subset(table_nodes: dict, edges: list[dict], node_ids: set) -> dict:
    subset = {nid: table_nodes[nid] for nid in node_ids if nid in table_nodes}
    subset_edges = [e for e in edges if e.get("source") in subset and e.get("target") in subset]
    return _grid_layout_table(subset, subset_edges)


def _normalize_layer_widths(nodes: list[dict]) -> list[dict]:
    if not nodes:
        return []
    layers = {}
    for node in nodes:
        layer = _layer_of_table(node.get("id") or "")
        layers.setdefault(layer, []).append(node)

    max_widths = {
        layer: max(n.get("width") or 0 for n in items)
        for layer, items in layers.items()
    }
    out = []
    for node in nodes:
        layer = _layer_of_table(node.get("id") or "")
        width = max_widths.get(layer) or node.get("width") or 200
        updated = dict(node)
        updated["width"] = width
        updated["height"] = 64
        out.append(updated)
    return out


def _dagre_layout(nodes: list[dict], edges: list[dict], rankdir: str = "LR") -> dict:
    if not nodes:
        return {}

    base_dir = Path(__file__).resolve().parent.parent
    script_path = base_dir / "scripts" / "dagre_layout.cjs"
    if not script_path.exists():
        raise FileNotFoundError(script_path)

    payload = {
        "nodes": nodes,
        "edges": edges,
        "rankdir": rankdir,
        "nodesep": 32,
        "ranksep": 90,
        "marginx": 20,
        "marginy": 20,
    }

    with tempfile.TemporaryDirectory() as tmpdir:
        input_path = Path(tmpdir) / "dagre_input.json"
        output_path = Path(tmpdir) / "dagre_output.json"
        input_path.write_text(json.dumps(payload), encoding="utf-8")

        result = subprocess.run(
            ["node", str(script_path), str(input_path), str(output_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise RuntimeError(f"dagre layout failed: {result.stderr.strip()}")

        out = json.loads(output_path.read_text(encoding="utf-8"))
        layout = out.get("nodes", {})

        # Normalize ranks to a grid to avoid excessive vertical drift.
        buckets = {}
        for node_id, pos in layout.items():
            if not pos:
                continue
            key = int(round(pos.get("x", 0)))
            buckets.setdefault(key, []).append((node_id, pos.get("y", 0)))

        if not buckets:
            return layout

        col_gap = 240
        row_gap = 90
        new_layout = {}
        for col_idx, x_key in enumerate(sorted(buckets.keys())):
            items = sorted(buckets[x_key], key=lambda item: item[1])
            for row_idx, (node_id, _y) in enumerate(items):
                new_layout[node_id] = {"x": col_idx * col_gap, "y": row_idx * row_gap}

        return new_layout


def build_graph_snapshot():
    all_meta, _ = get_cached_meta_and_index()
    meta_hash = _hash_meta(all_meta)

    entries = []
    meta_tables = set()
    for m in all_meta:
        schema = norm(m.get("table_schema"))
        table = norm(m.get("table_name"))
        entity = m.get("entity_name")
        if not schema or not table:
            continue
        if schema in ("raw_ext", "dict_raw_ext"):
            continue
        if isinstance(entity, str) and entity.lower() == "raw_ext":
            continue

        meta_tables.add(f"{schema}.{table}")
        depends = {}
        for src_schema, tables in (m.get("depends_on") or {}).items():
            src_schema_norm = norm(src_schema)
            if not src_schema_norm:
                continue
            cleaned = [norm(t) for t in (tables or []) if t]
            depends[src_schema_norm] = [t for t in cleaned if t]

        entries.append({
            "table_schema": schema,
            "table_name": table,
            "entity_name": entity or "UNKNOWN",
            "table_id": m.get("table_id"),
            "depends_on": depends,
        })

    table_entities: dict[str, set[str]] = {}
    table_info: dict[str, dict] = {}

    def register_table(fqn: str, schema: str, table: str, entity: str, table_id):
        if fqn not in table_info:
            table_info[fqn] = {
                "id": fqn,
                "schema": schema,
                "table": table,
                "table_id": table_id,
            }
        table_entities.setdefault(fqn, set()).add(entity)

    for m in entries:
        fqn = f"{m['table_schema']}.{m['table_name']}"
        register_table(fqn, m["table_schema"], m["table_name"], m["entity_name"], m.get("table_id"))

    edges_set: set[tuple[str, str]] = set()
    for m in entries:
        target = f"{m['table_schema']}.{m['table_name']}"
        for src_schema, tables in (m.get("depends_on") or {}).items():
            for src_table in tables:
                source = f"{src_schema}.{src_table}"
                edges_set.add((source, target))
                if source not in table_info:
                    schema_val, table_val = source.split(".", 1)
                    register_table(source, schema_val, table_val, "UNKNOWN", None)

    table_nodes = {}
    for fqn, info in table_info.items():
        entities = sorted(table_entities.get(fqn) or [])
        width = _estimate_node_width(fqn, min_width=200, max_width=520)
        table_nodes[fqn] = {
            "id": fqn,
            "schema": info["schema"],
            "table": info["table"],
            "entity": entities[0] if entities else "UNKNOWN",
            "entities": entities,
            "table_id": info.get("table_id"),
            "shared": len(entities) > 1,
            "width": width,
            "height": 64,
        }

    table_edges = [{"source": s, "target": t} for s, t in sorted(edges_set)]

    entity_nodes = {}
    entity_tables: dict[str, set[str]] = {}
    for fqn, entities in table_entities.items():
        for ent in entities:
            if not ent or ent == "UNKNOWN":
                continue
            entity_tables.setdefault(ent, set()).add(fqn)

    for ent, tables in entity_tables.items():
        node_id = f"ENTITY::{ent}"
        width = _estimate_node_width(ent, min_width=140, max_width=320)
        entity_nodes[node_id] = {
            "id": node_id,
            "label": ent,
            "tables_count": len(tables),
            "width": width,
            "height": 56,
        }

    entity_edges_set: set[tuple[str, str]] = set()
    for edge in edges_set:
        src, tgt = edge
        src_entities = table_entities.get(src) or set()
        tgt_entities = table_entities.get(tgt) or set()
        for src_ent in src_entities:
            for tgt_ent in tgt_entities:
                if (
                    not src_ent
                    or not tgt_ent
                    or src_ent == tgt_ent
                    or src_ent == "UNKNOWN"
                    or tgt_ent == "UNKNOWN"
                ):
                    continue
                if _normalize_entity_group(src_ent) == _normalize_entity_group(tgt_ent):
                    continue
                entity_edges_set.add((f"ENTITY::{src_ent}", f"ENTITY::{tgt_ent}"))

    entity_edges = [{"source": s, "target": t} for s, t in sorted(entity_edges_set)]

    entity_ids = list(entity_nodes.keys())
    sccs = _find_sccs(entity_ids, entity_edges)
    entity_cycles = []
    for scc in sccs:
        if len(scc) <= 1:
            continue
        labels = [entity_nodes.get(node_id, {}).get("label", node_id) for node_id in scc]
        entity_cycles.append({"nodes": labels, "size": len(labels)})

    edge_set = {(e["source"], e["target"]) for e in entity_edges}
    entity_mutual = []
    entity_mutual_any = []
    mutual_pairs = set()
    mutual_pairs_any = set()
    for src, tgt in edge_set:
        if (tgt, src) in edge_set:
            pair_key = tuple(sorted([src, tgt]))
            mutual_pairs_any.add(pair_key)

    table_pair_edges = {}
    table_pair_edges_rev = {}
    table_pair_edges_any = {}
    table_pair_edges_any_rev = {}
    exclusive_pair_edges = set()
    def is_exclusive_edge(src_ents: set, tgt_ents: set, left_ent: str, right_ent: str) -> bool:
        return (
            left_ent in src_ents
            and right_ent in tgt_ents
            and right_ent not in src_ents
            and left_ent not in tgt_ents
            and len(src_ents) == 1
            and len(tgt_ents) == 1
        )

    def is_pair_edge(src_ents: set, tgt_ents: set, left_ent: str, right_ent: str) -> bool:
        if _normalize_entity_group(left_ent) == _normalize_entity_group(right_ent):
            return False
        src_norm = {e.lower() for e in src_ents if isinstance(e, str)}
        tgt_norm = {e.lower() for e in tgt_ents if isinstance(e, str)}
        left_norm = left_ent.lower()
        right_norm = right_ent.lower()
        allowed = {left_norm, right_norm}
        return (
            left_norm in src_norm
            and right_norm in tgt_norm
            and left_norm not in tgt_norm
            and right_norm not in src_norm
            and src_norm.issubset(allowed)
            and tgt_norm.issubset(allowed)
        )

    for edge in table_edges:
        src = edge["source"]
        tgt = edge["target"]
        src_entities = table_entities.get(src) or set()
        tgt_entities = table_entities.get(tgt) or set()
        for src_ent in src_entities:
            for tgt_ent in tgt_entities:
                if not src_ent or not tgt_ent or src_ent == tgt_ent:
                    continue
                pair_key = (f"ENTITY::{src_ent}", f"ENTITY::{tgt_ent}")
                if tuple(sorted(pair_key)) in mutual_pairs_any and is_pair_edge(src_entities, tgt_entities, src_ent, tgt_ent):
                    table_pair_edges_any.setdefault(pair_key, set()).add((src, tgt))
                    table_pair_edges_any_rev.setdefault(tuple(sorted(pair_key)), {}).setdefault(pair_key, set()).add((src, tgt))
                if is_exclusive_edge(src_entities, tgt_entities, src_ent, tgt_ent):
                    exclusive_pair_edges.add(pair_key)
                    table_pair_edges.setdefault(pair_key, set()).add((src, tgt))
                    table_pair_edges_rev.setdefault(tuple(sorted(pair_key)), {}).setdefault(pair_key, set()).add((src, tgt))

    for src, tgt in exclusive_pair_edges:
        if (tgt, src) in exclusive_pair_edges:
            mutual_pairs.add(tuple(sorted([src, tgt])))

    for pair_key in sorted(mutual_pairs_any):
        left, right = pair_key
        edges_forward = sorted(table_pair_edges_any_rev.get(pair_key, {}).get((left, right), set()))
        edges_backward = sorted(table_pair_edges_any_rev.get(pair_key, {}).get((right, left), set()))
        entity_mutual_any.append({
            "a": entity_nodes.get(left, {}).get("label", left),
            "b": entity_nodes.get(right, {}).get("label", right),
            "edges_ab_count": len(edges_forward),
            "edges_ba_count": len(edges_backward),
            "edges_ab_sample": [{"source": s, "target": t} for s, t in edges_forward[:10]],
            "edges_ba_sample": [{"source": s, "target": t} for s, t in edges_backward[:10]],
        })

    for pair_key in sorted(mutual_pairs):
        left, right = pair_key
        edges_forward = sorted(table_pair_edges_rev.get(pair_key, {}).get((left, right), set()))
        edges_backward = sorted(table_pair_edges_rev.get(pair_key, {}).get((right, left), set()))
        entity_mutual.append({
            "a": entity_nodes.get(left, {}).get("label", left),
            "b": entity_nodes.get(right, {}).get("label", right),
            "edges_ab_count": len(edges_forward),
            "edges_ba_count": len(edges_backward),
            "edges_ab_sample": [{"source": s, "target": t} for s, t in edges_forward[:10]],
            "edges_ba_sample": [{"source": s, "target": t} for s, t in edges_backward[:10]],
        })

    table_ids = list(table_nodes.keys())
    table_sccs = _find_sccs(table_ids, table_edges)
    table_cycles = []
    for scc in table_sccs:
        if len(scc) <= 1:
            continue
        sample = sorted(scc)[:8]
        table_cycles.append({"size": len(scc), "nodes": sample})
    table_cycles.sort(key=lambda c: c["size"], reverse=True)
    table_cycles = table_cycles[:10]

    entity_layout_nodes = []
    for node_id, node in entity_nodes.items():
        label = node["label"]
        entity_layout_nodes.append({
            "id": node_id,
            "width": node.get("width") or _estimate_node_width(label, min_width=140, max_width=320),
            "height": node.get("height") or 56,
        })

    table_layout_nodes = []
    for fqn, node in table_nodes.items():
        label = fqn
        table_layout_nodes.append({
            "id": fqn,
            "width": node.get("width") or _estimate_node_width(label, min_width=170, max_width=460),
            "height": node.get("height") or 56,
        })

    entity_layout = _dagre_layout(entity_layout_nodes, entity_edges, rankdir="LR")
    table_layout = _grid_layout_table(table_nodes, table_edges)

    return {
        "meta_hash": meta_hash,
        "meta_ts": _cache_timestamp,
        "generated_at": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
        "table_graph": {"nodes": table_nodes, "edges": table_edges},
        "entity_graph": {"nodes": entity_nodes, "edges": entity_edges},
        "layouts": {"entity": entity_layout, "table": table_layout},
        "table_entity_map": {k: sorted(v) for k, v in table_entities.items()},
        "table_meta": sorted(meta_tables),
        "entity_cycles": entity_cycles,
        "entity_mutual": entity_mutual,
        "entity_mutual_any": entity_mutual_any,
        "table_cycles": table_cycles,
    }


def get_graph_snapshot():
    global _graph_snapshot, _graph_snapshot_ts, _graph_snapshot_hash
    now = time.time()

    if _graph_snapshot and now - _graph_snapshot_ts < _GRAPH_SNAPSHOT_TTL:
        if _graph_snapshot.get("meta_ts") == _cache_timestamp:
            return _graph_snapshot

    snapshot = build_graph_snapshot()
    _graph_snapshot = snapshot
    _graph_snapshot_ts = now
    _graph_snapshot_hash = snapshot.get("meta_hash")
    return snapshot


def _cap_graph(nodes: dict, edges: list, layout: dict, max_nodes: int, max_edges: int, sort_key: str = None):
    node_list = list(nodes.values())
    if sort_key:
        node_list.sort(key=lambda n: n.get(sort_key) or 0, reverse=True)
    node_ids = {n["id"] for n in node_list[:max_nodes]}

    truncated = len(nodes) > max_nodes
    filtered_edges = [e for e in edges if e["source"] in node_ids and e["target"] in node_ids]

    if len(filtered_edges) > max_edges:
        filtered_edges = filtered_edges[:max_edges]
        truncated = True

    filtered_nodes = {nid: nodes[nid] for nid in node_ids if nid in nodes}
    filtered_layout = {nid: layout.get(nid) for nid in node_ids if nid in layout}
    return filtered_nodes, filtered_edges, filtered_layout, truncated


def _compute_orphan_tables(snapshot: dict, final_schemas: set[str], meta_only: bool = False) -> dict:
    nodes = snapshot.get("table_graph", {}).get("nodes", {}) or {}
    edges = snapshot.get("table_graph", {}).get("edges", []) or []
    meta_tables = set(snapshot.get("table_meta") or [])
    if meta_only:
        nodes = {k: v for k, v in nodes.items() if k in meta_tables}
        edges = [e for e in edges if e.get("source") in meta_tables and e.get("target") in meta_tables]
    if not nodes:
        return {
            "final_schemas": sorted(final_schemas),
            "meta_only": meta_only,
            "total_tables": 0,
            "final_count": 0,
            "reachable_count": 0,
            "orphan_count": 0,
            "coverage_pct": 0.0,
            "orphans": [],
            "count_by_schema": {},
        }

    incoming = {}
    outgoing = {}
    reverse = {}
    for edge in edges:
        src = edge.get("source")
        tgt = edge.get("target")
        if not src or not tgt:
            continue
        outgoing[src] = outgoing.get(src, 0) + 1
        incoming[tgt] = incoming.get(tgt, 0) + 1
        reverse.setdefault(tgt, []).append(src)

    finals = {
        node_id
        for node_id, node in nodes.items()
        if node.get("schema") in final_schemas
    }

    reachable = set()
    stack = list(finals)
    while stack:
        current = stack.pop()
        if current in reachable:
            continue
        reachable.add(current)
        for parent in reverse.get(current, []):
            if parent not in reachable:
                stack.append(parent)

    orphans = [node_id for node_id in nodes.keys() if node_id not in reachable]
    count_by_schema = {}
    for node_id in orphans:
        schema = nodes[node_id].get("schema") or "unknown"
        count_by_schema[schema] = count_by_schema.get(schema, 0) + 1

    coverage_pct = (len(reachable) / len(nodes)) * 100 if nodes else 0.0
    return {
        "final_schemas": sorted(final_schemas),
        "meta_only": meta_only,
        "total_tables": len(nodes),
        "final_count": len(finals),
        "reachable_count": len(reachable),
        "orphan_count": len(orphans),
        "coverage_pct": round(coverage_pct, 2),
        "orphans": orphans,
        "count_by_schema": count_by_schema,
        "incoming": incoming,
        "outgoing": outgoing,
    }


@router.get("/api/entities/shared")
def get_shared_tables_by_entity(limit: int = Query(5, ge=0, le=50)):
    shared_map = {}
    try:
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    f"""
                    SELECT entity_id, table_schema, table_name
                    FROM {TABLE_TABLES_META}
                    WHERE entity_id IS NOT NULL
                    """
                )
            ).mappings().all()

        table_entity_map = {}
        for row in rows:
            entity_id = row.get("entity_id")
            schema = row.get("table_schema")
            table = row.get("table_name")
            if entity_id is None or not schema or not table:
                continue
            fqn = f"{schema}.{table}"
            table_entity_map.setdefault(fqn, set()).add(str(entity_id))

        for table_fqn, entity_ids in table_entity_map.items():
            if len(entity_ids) < 2:
                continue
            for entity_id in entity_ids:
                entry = shared_map.setdefault(entity_id, {"count": 0, "tables": []})
                entry["count"] += 1
                if limit and len(entry["tables"]) < limit:
                    entry["tables"].append(table_fqn)
    except Exception:
        shared_map = {}

    return JSONResponse(content=shared_map, media_type="application/json; charset=utf-8")


@router.get("/api/graph/orphans")
def get_orphan_tables(
    final_schemas: str = Query("dm"),
    meta_only: bool = Query(True),
    offset: int = Query(0, ge=0),
    limit: int = Query(40, ge=0, le=500),
):
    snapshot = get_graph_snapshot()
    requested = {norm(s) for s in (final_schemas or "").split(",") if s}
    final_set = {s for s in requested if s}
    data = _compute_orphan_tables(snapshot, final_set, meta_only=meta_only)

    table_nodes = snapshot.get("table_graph", {}).get("nodes", {}) or {}
    table_entity_map = snapshot.get("table_entity_map") or {}
    incoming = data.get("incoming", {})
    outgoing = data.get("outgoing", {})

    orphans_sorted = sorted(data["orphans"])
    total_orphans = len(orphans_sorted)
    start = min(offset, total_orphans)
    end = total_orphans if limit == 0 else min(start + limit, total_orphans)

    orphans = []
    for node_id in orphans_sorted[start:end]:
        node = table_nodes.get(node_id) or {}
        orphans.append({
            "id": node_id,
            "schema": node.get("schema"),
            "table": node.get("table"),
            "table_id": node.get("table_id"),
            "entities": table_entity_map.get(node_id, []),
            "incoming": incoming.get(node_id, 0),
            "outgoing": outgoing.get(node_id, 0),
        })
    has_more = end < total_orphans

    payload = {
        "final_schemas": data["final_schemas"],
        "meta_only": data["meta_only"],
        "total_tables": data["total_tables"],
        "final_count": data["final_count"],
        "reachable_count": data["reachable_count"],
        "orphan_count": data["orphan_count"],
        "coverage_pct": data["coverage_pct"],
        "count_by_schema": data["count_by_schema"],
        "offset": start,
        "limit": limit,
        "has_more": has_more,
        "orphans": orphans,
    }
    return JSONResponse(content=payload, media_type="application/json; charset=utf-8")

def normalize_fqn(table_fqn: str) -> tuple[str, str]:
    """
    Всегда возвращает (schema, table) в lowercase
    """
    s = table_fqn.strip().lower()

    if "/" in s and "." in s:
        schema, rest = s.split(".", 1)
        rest = rest.replace("/", "").replace("-", "").replace(" ", "")
        s = f"{schema}.{rest}"

    if "." not in s:
        raise ValueError("Expected schema.table")

    return tuple(s.split(".", 1))


def _parse_numeric(text_val: Optional[str]) -> Optional[float]:
    if text_val is None:
        return None
    match = re.search(r"-?\d+(?:\.\d+)?", str(text_val))
    if not match:
        return None
    try:
        return float(match.group(0))
    except ValueError:
        return None


def _entity_map_from_meta() -> dict:
    all_meta, _ = get_cached_meta_and_index()
    entity_map = {}
    for meta in all_meta:
        schema = norm(meta.get("table_schema"))
        table = norm(meta.get("table_name"))
        entity = meta.get("entity_name")
        if schema and table and entity:
            entity_map[f"{schema}.{table}"] = entity
    return entity_map


def _normalize_table_param(schema: str, table: str) -> tuple[Optional[str], Optional[str]]:
    schema_norm = norm(schema)
    table_norm = norm(table)
    if not table_norm:
        return schema_norm, table_norm
    table_norm = table_norm.strip()
    return schema_norm, table_norm


def _clean_table_name(table_norm: Optional[str]) -> Optional[str]:
    if not table_norm:
        return table_norm
    return table_norm.replace("/", "").replace("-", "").replace(" ", "")

@app.on_event("startup")
def warm_up_cache():
    try:
        get_cached_meta_and_index()
        get_cached_order_breaches()  # 🔥 прогрев orderbreaches
        get_graph_snapshot()
    except Exception as e:
        print("Ошибка при старте приложения:", e)


BASE_DIR = Path(__file__).resolve().parent.parent
# Можно переопределить путь к метаданным через переменную окружения:
# export META_PARENT_DIR=/path/to/meta_info/database/greenplum/schema_name/tech_etl/etl_load_entity
# Локальный Windows путь (раскомментируй на Win):
# META_PARENT_DIRS = [Path(r"C:\\GIT\\meta_info\\database\\greenplum\\schema_name\\tech_etl\\etl_load_entity")]
META_PARENT_DIRS = [Path(os.getenv("META_PARENT_DIR", BASE_DIR / "etl_loads_entity"))]

# ClickHouse meta configs (config_files/meta)
_click_meta_cache = None
_click_meta_ts = 0
_CLICK_META_TTL = 86400  # 24 часа


def _load_click_meta_index():
    root = Path(CLICK_META_DIR)
    if not root.is_absolute():
        root = (BASE_DIR / root).resolve()

    meta_index: Dict[Tuple[str, str], Dict[str, Any]] = {}
    view_sql_index: Dict[Tuple[str, str], str] = {}
    view_refs: Dict[Tuple[str, str], List[Dict[str, Any]]] = {}

    dm_dir = root / "dm"
    if dm_dir.exists():
        for path in dm_dir.rglob("*.yaml"):
            try:
                data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            except Exception:
                continue
            schema_gp = str(data.get("schema_name_gp") or "").strip().lower()
            obj_name = str(data.get("object_name") or "").strip().lower()
            if schema_gp and obj_name:
                meta_index[(schema_gp, obj_name)] = data

    dm_view_dir = root / "dm_view"
    if dm_view_dir.exists():
        for path in dm_view_dir.rglob("*.sql"):
            obj_name = path.stem.strip().lower()
            if obj_name:
                sql_text = path.read_text(encoding="utf-8")
                view_sql_index[("dm_view", obj_name)] = sql_text

                # parse FROM/JOIN references
                for match in re.finditer(
                    r"(from|join)\s+([A-Za-z0-9_\"/]+)\.([A-Za-z0-9_\"/]+)",
                    sql_text,
                    flags=re.IGNORECASE,
                ):
                    schema_ref = match.group(2).replace('"', "").strip().lower()
                    table_ref = match.group(3).replace('"', "").strip().lower()
                    schema_ref = schema_ref.replace("/", "")
                    table_ref = _clean_table_name(table_ref)
                    if not schema_ref or not table_ref:
                        continue
                    key = (schema_ref, table_ref)
                    view_refs.setdefault(key, []).append(
                        {
                            "view_schema": "dm_view",
                            "view_name": obj_name,
                            "reason": "from_match",
                        }
                    )

    return {"meta": meta_index, "view_sql": view_sql_index, "view_refs": view_refs, "root": str(root)}


def get_click_meta_index():
    global _click_meta_cache, _click_meta_ts
    now = time.time()
    if _click_meta_cache and now - _click_meta_ts < _CLICK_META_TTL:
        return _click_meta_cache
    _click_meta_cache = _load_click_meta_index()
    _click_meta_ts = now
    return _click_meta_cache


def iter_meta_dirs(targets: Optional[List[str]] = None):
    """Yield existing metadata directories, searching both root and project/* trees."""
    seen = set()
    for parent in META_PARENT_DIRS:
        if not parent.exists():
            continue
        if targets:
            names = targets
        else:
            names = [p.name for p in parent.iterdir() if p.is_dir()]
        for name in names:
            candidate = parent / name
            if not candidate.exists():
                continue
            real = candidate.resolve()
            if real in seen:
                continue
            seen.add(real)
            yield candidate


def normalize_excel_table_name(value: Optional[str]) -> Optional[str]:
    if not value:
        return None

    cleaned = (
        str(value)
        .strip()
        .replace('"', "")
        .replace("'", "")
        .replace("`", "")
        .replace("[", "")
        .replace("]", "")
        .replace(" ", "")
        .replace("\n", "")
    )

    if not cleaned or cleaned == "-":
        return None

    cleaned = cleaned.lower()
    cleaned = cleaned.replace("..", ".")

    if "." in cleaned:
        schema, table = cleaned.split(".", 1)
        schema = schema.strip()
        table = table.strip()
        if not schema or not table:
            return None
        return f"{schema}.{table}"

    return cleaned or None


def format_excel_datetime(value) -> Optional[str]:
    if not value:
        return None
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(value, date):
        return datetime.combine(value, datetime.min.time()).strftime("%Y-%m-%d %H:%M:%S")
    try:
        parsed = datetime.fromisoformat(str(value))
        return parsed.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return str(value)


def parse_ytrek_excel(file_path: Path) -> List[dict]:
    if not file_path.exists():
        raise FileNotFoundError(file_path)

    header_map = {
        "№": "index",
        "id задачи": "issue_id",
        "название задачи": "title",
        "дата начала сбоя": "start_at",
        "дата обнаружения": "detected_at",
        "дата окончания работ": "resolved_at",
        "ссылка на задачу": "link",
        "название таблицы": "table_raw",
        "название сущности": "entity_name",
    }

    def norm_header(value):
        return (value or "").strip().lower()

    workbook = load_workbook(file_path, read_only=True, data_only=True)
    sheet = workbook.active

    header_row = next(sheet.iter_rows(min_row=1, max_row=1, values_only=True))
    normalized_headers = [norm_header(h) for h in header_row]

    incidents = []
    for raw_row in sheet.iter_rows(min_row=2, values_only=True):
        record = {}
        for idx, cell_value in enumerate(raw_row):
            header_key = normalized_headers[idx] if idx < len(normalized_headers) else None
            mapped_key = header_map.get(header_key)
            if not mapped_key:
                continue
            record[mapped_key] = cell_value

        issue_id = str(record.get("issue_id") or "").strip()
        title = str(record.get("title") or "").strip()

        if not issue_id and not title:
            continue

        table_raw = str(record.get("table_raw") or "").strip()
        incidents.append(
            {
                "issue_id": issue_id,
                "title": title or "Без названия",
                "start_at": format_excel_datetime(record.get("start_at")),
                "detected_at": format_excel_datetime(record.get("detected_at")),
                "resolved_at": format_excel_datetime(record.get("resolved_at")),
                "link": record.get("link"),
                "table_raw": table_raw,
                "table_normalized": normalize_excel_table_name(table_raw),
                "entity_name": str(record.get("entity_name") or "").strip(),
            }
        )

    incidents.sort(key=lambda x: x.get("start_at") or "", reverse=True)
    return incidents


def build_tables_meta_index() -> tuple[dict, dict]:
    """Return lookup dictionaries for tables_meta: by fqn and by table name."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                f"""
                SELECT t.table_id, t.table_schema, t.table_name, t.entity_id, e.entity_name
                FROM {TABLE_TABLES_META} t
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE t.table_schema IS NOT NULL AND t.table_name IS NOT NULL
                """
            )
        ).mappings().all()

    by_fqn = {}
    by_name = {}

    for row in rows:
        schema = (row["table_schema"] or "").lower()
        table = (row["table_name"] or "").lower()
        if not schema or not table:
            continue
        key = f"{schema}.{table}"
        by_fqn[key] = row
        by_name.setdefault(table, []).append(row)

    return by_fqn, by_name


def ensure_ytrek_table_exists(conn) -> None:
    conn.execute(
        text(
            f"""
            CREATE TABLE IF NOT EXISTS {TABLE_YTREK_INCIDENTS} (
                issue_id TEXT PRIMARY KEY,
                title TEXT,
                start_at TIMESTAMP NULL,
                detected_at TIMESTAMP NULL,
                resolved_at TIMESTAMP NULL,
                link TEXT,
                table_raw TEXT,
                table_normalized TEXT,
                table_schema TEXT,
                table_name TEXT,
                table_id BIGINT,
                entity_name TEXT,
                inserted_at TIMESTAMP DEFAULT NOW()
            )
            """
        )
    )


def parse_timestamp_value(value):
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    try:
        return datetime.strptime(str(value), "%Y-%m-%d %H:%M:%S")
    except Exception:
        return None


def pick_table_match(table_normalized: Optional[str], entity_hint: Optional[str], by_fqn: dict, by_name: dict):
    if not table_normalized:
        return None

    normalized = table_normalized.lower()
    entity_hint = (entity_hint or "").lower()

    if "." in normalized and normalized in by_fqn:
        return by_fqn[normalized]

    # Fall back to table-name-only match
    table_name = normalized.split(".")[-1]
    candidates = by_name.get(table_name) or []
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]
    if entity_hint:
        filtered = [c for c in candidates if (c.get("entity_name") or "").lower() == entity_hint]
        if len(filtered) == 1:
            return filtered[0]
    return candidates[0]


def import_ytrek_from_excel(file_path: Union[str, Path]) -> int:
    """Load incidents from an Excel export into the database table."""
    path = Path(file_path)
    incidents = parse_ytrek_excel(path)
    by_fqn, by_name = build_tables_meta_index()

    rows = []
    for record in incidents:
        table_norm = record.get("table_normalized")
        entity_hint = record.get("entity_name")
        match = pick_table_match(table_norm, entity_hint, by_fqn, by_name)

        matched_schema = match.get("table_schema") if match else None
        matched_table = match.get("table_name") if match else None
        consolidated_entity = match.get("entity_name") if match else None
        if not consolidated_entity:
            consolidated_entity = entity_hint or None

        rows.append(
            {
                "issue_id": record.get("issue_id"),
                "title": record.get("title"),
                "start_at": parse_timestamp_value(record.get("start_at")),
                "detected_at": parse_timestamp_value(record.get("detected_at")),
                "resolved_at": parse_timestamp_value(record.get("resolved_at")),
                "link": record.get("link"),
                "table_raw": record.get("table_raw"),
                "table_normalized": table_norm,
                "table_schema": matched_schema,
                "table_name": matched_table,
                "table_id": match.get("table_id") if match else None,
                "entity_name": consolidated_entity,
            }
        )

    with engine.begin() as conn:
        ensure_ytrek_table_exists(conn)
        conn.execute(text(f"TRUNCATE TABLE {TABLE_YTREK_INCIDENTS}"))
        if rows:
            conn.execute(
                text(
                    f"""
                    INSERT INTO {TABLE_YTREK_INCIDENTS} (
                        issue_id, title, start_at, detected_at, resolved_at,
                        link, table_raw, table_normalized, table_schema, table_name,
                        table_id, entity_name
                    ) VALUES (
                        :issue_id, :title, :start_at, :detected_at, :resolved_at,
                        :link, :table_raw, :table_normalized, :table_schema, :table_name,
                        :table_id, :entity_name
                    )
                    """
                ),
                rows,
            )

    return len(rows)


def extract_incident_day(row: dict) -> Optional[date]:
    for key in ("start_at", "detected_at", "resolved_at"):
        value = row.get(key)
        if not value:
            continue
        if isinstance(value, datetime):
            return value.date()
        try:
            return datetime.fromisoformat(str(value)).date()
        except Exception:
            continue
    return None


def fetch_failure_lookup(conn, incident_rows):
    combos = []
    for row in incident_rows:
        table_id = row.get("table_id")
        if not table_id:
            continue
        day = extract_incident_day(row)
        if not day:
            continue
        combos.append((table_id, day))

    if not combos:
        return {}

    unique_ids = sorted({tid for tid, _ in combos})
    min_day = min(day for _, day in combos)
    max_day = max(day for _, day in combos)

    start_bound = datetime.combine(min_day, datetime.min.time())
    end_bound = datetime.combine(max_day + timedelta(days=1), datetime.min.time())

    placeholders = ", ".join(f":id{i}" for i in range(len(unique_ids)))
    params = {f"id{i}": tid for i, tid in enumerate(unique_ids)}
    params.update({"start_bound": start_bound, "end_bound": end_bound})

    query = text(
        f"""
        SELECT object_id, DATE(loading_finish_dttm) AS incident_day, COUNT(*) AS fail_count
        FROM {TABLE_LOADING_HISTORY}
        WHERE object_id IN ({placeholders})
          AND loading_state = 'FAILED'
          AND loading_finish_dttm >= :start_bound
          AND loading_finish_dttm < :end_bound
        GROUP BY object_id, DATE(loading_finish_dttm)
        """
    )

    rows = conn.execute(query, params).mappings().all()
    lookup = {}
    for row in rows:
        lookup[(row["object_id"], row["incident_day"])] = row["fail_count"]

    return lookup


def build_ytrek_dashboard(top_limit: int):
    with engine.begin() as conn:
        ensure_ytrek_table_exists(conn)

    with engine.connect() as conn:
        incident_rows = conn.execute(
            text(
                f"""
                SELECT issue_id, title, start_at, detected_at, resolved_at, link,
                       table_raw, table_normalized, table_schema, table_name,
                       table_id, entity_name
                FROM {TABLE_YTREK_INCIDENTS}
                ORDER BY COALESCE(start_at, detected_at, resolved_at) DESC NULLS LAST,
                         issue_id DESC
                """
            )
        ).mappings().all()

        timeline_rows = conn.execute(
            text(
                f"""
                SELECT DATE(COALESCE(start_at, detected_at, resolved_at)) AS incident_day,
                       COUNT(*) AS incidents_count
                FROM {TABLE_YTREK_INCIDENTS}
                WHERE COALESCE(start_at, detected_at, resolved_at) IS NOT NULL
                GROUP BY DATE(COALESCE(start_at, detected_at, resolved_at))
                ORDER BY incident_day DESC
                LIMIT 30
                """
            )
        ).mappings().all()

        top_tables_rows = conn.execute(
            text(
                f"""
                SELECT
                    table_schema,
                    table_name,
                    table_raw,
                    COUNT(*) AS incidents_count,
                    MAX(COALESCE(start_at, detected_at, resolved_at)) AS last_incident
                FROM {TABLE_YTREK_INCIDENTS}
                GROUP BY table_schema, table_name, table_raw
                ORDER BY incidents_count DESC, last_incident DESC
                LIMIT :limit
                """
            ),
            {"limit": top_limit},
        ).mappings().all()

        top_entities_rows = conn.execute(
            text(
                f"""
                SELECT
                    COALESCE(NULLIF(entity_name, ''), 'Не указано') AS entity_key,
                    COUNT(*) AS incidents_count,
                    MAX(COALESCE(start_at, detected_at, resolved_at)) AS last_incident
                FROM {TABLE_YTREK_INCIDENTS}
                GROUP BY entity_key
                ORDER BY incidents_count DESC, entity_key
                LIMIT :limit
                """
            ),
            {"limit": top_limit},
        ).mappings().all()

        failure_lookup = fetch_failure_lookup(conn, incident_rows)

    incidents = []
    tables_set = set()
    entities_set = set()
    mapped_count = 0
    db_matches = 0

    for row in incident_rows:
        table_schema = row.get("table_schema")
        table_name = row.get("table_name")
        table_fqn = None
        if table_schema and table_name:
            table_fqn = f"{table_schema}.{table_name}"
            tables_set.add(table_fqn)
            mapped_count += 1

        entity_value = row.get("entity_name")
        if isinstance(entity_value, str):
            entity_value = entity_value.strip()
        if entity_value:
            entities_set.add(entity_value)

        incident_day = extract_incident_day(row)
        day_key = incident_day.strftime("%Y-%m-%d") if incident_day else None
        failures = 0
        if row.get("table_id") and incident_day:
            failures = failure_lookup.get((row["table_id"], incident_day), 0)
        if failures:
            db_matches += 1

        incidents.append(
            {
                "issue_id": row["issue_id"],
                "title": row["title"],
                "link": row.get("link"),
                "start_at": serialize_datetime(row.get("start_at")),
                "detected_at": serialize_datetime(row.get("detected_at")),
                "resolved_at": serialize_datetime(row.get("resolved_at")),
                "table_raw": row.get("table_raw"),
                "table_normalized": row.get("table_normalized"),
                "table_schema": table_schema,
                "table_name": table_name,
                "table_fqn": table_fqn,
                "table_id": row.get("table_id"),
                "entity_name": row.get("entity_name"),
                "has_table": bool(table_fqn),
                "incident_day": day_key,
                "has_db_failures": failures > 0,
                "db_failures_count": failures,
            }
        )

    stats = {
        "total": len(incidents),
        "with_table": mapped_count,
        "unique_tables": len(tables_set),
        "unique_entities": len(entities_set),
        "with_db_failures": db_matches,
    }

    timeline = [
        {
            "day": row["incident_day"].strftime("%Y-%m-%d"),
            "count": row["incidents_count"],
        }
        for row in reversed(timeline_rows)
        if row.get("incident_day")
    ]

    top_tables = []
    for row in top_tables_rows:
        schema = row.get("table_schema")
        table = row.get("table_name")
        table_fqn = f"{schema}.{table}" if schema and table else None
        label = table_fqn or row.get("table_raw") or "—"
        top_tables.append(
            {
                "label": label,
                "table_fqn": table_fqn,
                "count": row["incidents_count"],
                "last_incident": serialize_datetime(row.get("last_incident")),
                "has_table": bool(table_fqn),
            }
        )

    top_entities = [
        {
            "label": row["entity_key"],
            "count": row["incidents_count"],
            "last_incident": serialize_datetime(row.get("last_incident")),
        }
        for row in top_entities_rows
    ]

    return {
        "stats": stats,
        "timeline": timeline,
        "top_tables": top_tables,
        "top_entities": top_entities,
        "incidents": incidents,
    }


def serialize_datetime(value):
    if not value:
        return None
    if isinstance(value, str):
        return value
    return value.strftime("%Y-%m-%d %H:%M:%S")


def _duration_minutes(value):
    if value is None:
        return None
    try:
        if isinstance(value, timedelta):
            return round(value.total_seconds() / 60.0, 2)
        if isinstance(value, (int, float)):
            return round(float(value) / 60.0, 2)
        return None
    except Exception:
        return None


def _round_minutes(value):
    if value is None:
        return None
    try:
        return round(float(value), 2)
    except Exception:
        return None


def _clickhouse_run_metrics(row):
    actual_seconds = float(row.get("actual_duration_seconds") or 0.0)
    elapsed_seconds = float(row.get("elapsed_duration_seconds") or 0.0)
    lag_seconds = max(elapsed_seconds - actual_seconds, 0.0)
    return {
        "actual_duration_min": round(actual_seconds / 60.0, 2),
        "elapsed_duration_min": round(elapsed_seconds / 60.0, 2),
        "lag_duration_min": round(lag_seconds / 60.0, 2),
        # Backward-compatible alias for old UI callers.
        "duration_min": round(actual_seconds / 60.0, 2),
    }


def _clickhouse_run_agg_cte(
    run_filter_sql: str = "",
    stage_filter_sql: str = "",
):
    return f"""
        WITH run_agg AS (
            SELECT
                r.run_uuid,
                r.schema_name,
                s.table_name,
                r.dag_name,
                r.dag_run,
                r.status,
                r.error_text,
                MAX(s.table_id) AS table_id,
                MIN(s.start_dttm) AS start_dttm,
                MAX(s.end_dttm) AS end_dttm,
                SUM(EXTRACT(EPOCH FROM s.duration)) AS actual_duration_seconds,
                EXTRACT(EPOCH FROM (MAX(s.end_dttm) - MIN(s.start_dttm))) AS elapsed_duration_seconds
            FROM {TABLE_CLICK_LOAD_RUN} r
            JOIN {TABLE_CLICK_LOAD_STAGE} s
              ON s.run_uuid = r.run_uuid
             AND s.table_id = r.table_id
            WHERE s.stage_name IN ('UPLOAD_TO_S3', 'CLICKHOUSE_LOAD')
              {run_filter_sql}
              {stage_filter_sql}
            GROUP BY
                r.run_uuid,
                r.schema_name,
                s.table_name,
                r.dag_name,
                r.dag_run,
                r.status,
                r.error_text
        )
    """


@router.get("/api/ytrek/incidents")
def get_ytrek_incidents(top_limit: int = Query(5, ge=1, le=50)):
    return build_ytrek_dashboard(top_limit)

def resolve_dependencies(schema: str, table: str) -> List[DependencyItem]:
    schema = (schema or "").strip().lower()
    table = (table or "").strip().lower()
    all_meta, reverse_index = get_cached_meta_and_index()

    start = (schema, table)
    visited = {start}
    parent = {}
    depth = {start: 0}
    meta_by_node = {}
    order = []

    queue = deque([start])
    while queue:
        node = queue.popleft()
        for dep in reverse_index.get(node, []):
            child = (dep["schema"], dep["table_name"])
            if child in visited:
                continue
            visited.add(child)
            parent[child] = node
            depth[child] = depth[node] + 1
            meta_by_node[child] = dep
            order.append(child)
            queue.append(child)

    out = []
    with engine.connect() as conn:
        for i, node in enumerate(order, 1):
            r = meta_by_node[node]
            avg = None
            if r.get("table_id"):
                avg = conn.execute(
                    text(f"""
                        SELECT round((avg(extract(epoch from (loading_finish_dttm-loading_start_dttm))/60))::numeric,2)
                        FROM {TABLE_LOADING_HISTORY}
                        WHERE object_id=:id AND loading_state='SUCCESS'
                    """),
                    {"id": r["table_id"]}
                ).scalar()

            path = []
            current = node
            while current != start:
                path.append(f"{current[0]}.{current[1]}")
                current = parent[current]
            path.append(f"{start[0]}.{start[1]}")
            path.reverse()

            out.append(DependencyItem(
                step=i,
                schema=r["schema"],
                table_name=r["table_name"],
                entity_id=r["entity_id"],
                entity_name=r.get("entity_name"),
                avg_duration_minutes=avg,
                depth=depth.get(node, 0),
                path=path,
            ))
    return out

@router.get("/api/routes")
def list_routes():
    return [route.path for route in app.routes]


@router.get("/ping")
def ping():
    return {"pong": True}





def find_all_meta_files(top_dirs: list[str]) -> list[dict]:
    all_meta = []

    for entity_root in iter_meta_dirs(top_dirs):
        for root, _, files in os.walk(entity_root):
            if "meta_data_file.yaml" not in files:
                continue

            path = Path(root) / "meta_data_file.yaml"
            try:
                meta = yaml.safe_load(path.read_text(encoding="utf-8")) or {}

                all_meta.append({
                    "table_schema": norm(meta.get("table_schema")),
                    "table_name": norm(meta.get("table_name")),
                    "entity_id": meta.get("entity_id"),
                    "entity_name": meta.get("entity_name"),
                    "table_id": meta.get("table_id"),
                    "depends_on": {
                        norm(k): [norm(t) for t in v]
                        for k, v in (meta.get("depends_on") or {}).items()
                    },
                })
            except Exception as e:
                print(f"[META ERROR] {path}: {e}")

    return all_meta



def build_reverse_index(all_meta: list[dict]) -> dict[tuple[str, str], list[dict]]:
    reverse = {}

    for m in all_meta:
        consumer = (m["table_schema"], m["table_name"])

        for src_schema, tables in (m.get("depends_on") or {}).items():
            for src_table in tables:
                key = (src_schema, src_table)

                reverse.setdefault(key, []).append({
                    "schema": consumer[0],
                    "table_name": consumer[1],
                    "entity_id": m.get("entity_id"),
                    "entity_name": m.get("entity_name"),
                    "table_id": m.get("table_id"),
                })

    return reverse




def recursive_reverse_search(
    schema: str,
    table: str,
    reverse_index: dict,
    visited: Optional[set] = None
):
    if visited is None:
        visited = set()

    key = (schema, table)
    if key in visited:
        return []

    visited.add(key)

    result = []
    for dep in reverse_index.get(key, []):
        result.append(dep)
        result.extend(
            recursive_reverse_search(
                dep["schema"],
                dep["table_name"],
                reverse_index,
                visited
            )
        )

    return result


@router.get("/api/dependencies", response_model=List[DependencyItem])
def get_dependencies(table: str = Query(...)):
    try:
        schema, table = table.split(".")
    except ValueError:
        return []
    return resolve_dependencies(schema, table)


@router.get("/api/failures")
def get_failed_tables():
    query = f"""
     SELECT
        table_schema as object_schema,
        object_name AS table_name,
        l1.object_type,
        message AS error_message,
        loading_finish_dttm AS error_time,
        (
            SELECT MAX(loading_finish_dttm)
            FROM {TABLE_LOADING_HISTORY} AS l2
            WHERE l2.object_name = l1.object_name
              AND l2.object_type = l1.object_type
              AND l2.loading_state = 'SUCCESS'
        ) AS last_success_time
    FROM {TABLE_LOADING_HISTORY} l1
    inner join {TABLE_TABLES_META} tm on l1.object_id = tm.table_id
    WHERE loading_state = 'FAILED' and l1.object_type='table'
    ORDER BY loading_finish_dttm DESC
    LIMIT 10
    """
    try:
        with engine.connect() as conn:
            rows = conn.execute(text(query)).mappings().all()

            cleaned = []
            for r in rows:
                row = dict(r)
                row["schema"] = row["object_schema"]
                row["error_time"] = row["error_time"].strftime("%Y-%m-%d %H:%M:%S") if row["error_time"] else None
                row["last_success_time"] = (
                    row["last_success_time"].strftime("%Y-%m-%d %H:%M:%S") if row["last_success_time"] else None
                )
                cleaned.append(row)

            return JSONResponse(content=cleaned, media_type="application/json; charset=utf-8")

    except Exception as e:
        print("❌ Ошибка при получении данных об ошибках:", str(e))
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/entities")
def get_entities():
    try:
        cleaned = fetch_entities(
            engine,
            table_loading_history=TABLE_LOADING_HISTORY,
            table_tables_meta=TABLE_TABLES_META,
            table_entities_meta=TABLE_ENTITIES_META,
        )
        return JSONResponse(content=cleaned, media_type="application/json; charset=utf-8")

    except Exception as e:
        print("❌ Ошибка при получении данных об ошибках:", str(e))
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/entities/timeline")
def get_entities_timeline(days: int = Query(7, ge=3, le=30)):
    try:
        query = f"""
            WITH latest_table_day_runs AS (
                SELECT
                    l.object_id,
                    DATE(COALESCE(l.loading_finish_dttm, l.loading_start_dttm)) AS load_day,
                    l.loading_start_dttm,
                    COALESCE(l.loading_finish_dttm, l.loading_start_dttm) AS loading_finish_dttm,
                    ROW_NUMBER() OVER (
                        PARTITION BY l.object_id, DATE(COALESCE(l.loading_finish_dttm, l.loading_start_dttm))
                        ORDER BY COALESCE(l.loading_finish_dttm, l.loading_start_dttm) DESC NULLS LAST
                    ) AS rn
                FROM {TABLE_LOADING_HISTORY} l
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'SUCCESS'
                  AND l.loading_start_dttm IS NOT NULL
            ),
            base AS (
                SELECT
                    t.entity_id,
                    e.entity_name,
                    l.load_day,
                    MIN(l.loading_start_dttm) AS start_dttm,
                    MAX(l.loading_finish_dttm) AS end_dttm
                FROM latest_table_day_runs l
                JOIN {TABLE_TABLES_META} t
                  ON t.table_id = l.object_id
                JOIN {TABLE_ENTITIES_META} e
                  ON e.entity_id = t.entity_id
                WHERE l.rn = 1
                  AND (e.flag_active OR COALESCE(e.on_new_fraemwork, FALSE))
                GROUP BY t.entity_id, e.entity_name, l.load_day
            ),
            ranked AS (
                SELECT
                    base.*,
                    ROW_NUMBER() OVER (
                        PARTITION BY base.entity_id
                        ORDER BY base.load_day DESC
                    ) AS rn
                FROM base
            )
            SELECT
                entity_id,
                entity_name,
                load_day,
                start_dttm,
                end_dttm,
                EXTRACT(EPOCH FROM (end_dttm - start_dttm)) / 60.0 AS duration_minutes
            FROM ranked
            WHERE rn <= :days
            ORDER BY entity_name, load_day
        """

        with engine.connect() as conn:
            rows = conn.execute(text(query), {"days": days}).mappings().all()

        payload = {}
        for row in rows:
            entity_id = row.get("entity_id")
            if not entity_id:
                continue
            payload.setdefault(str(entity_id), []).append(
                {
                    "day": str(row.get("load_day")),
                    "start_dttm": serialize_datetime(row.get("start_dttm")),
                    "end_dttm": serialize_datetime(row.get("end_dttm")),
                    "duration_minutes": round(float(row.get("duration_minutes") or 0.0), 2),
                }
            )

        return JSONResponse(content={"days": days, "items": payload}, media_type="application/json; charset=utf-8")
    except Exception as e:
        print("❌ Ошибка при получении таймлайна сущностей:", str(e))
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/timeline")
def get_table_timeline(table_name: str):
    query = f"""
    SELECT
        loading_start_dttm,
        loading_finish_dttm,
        loading_state,
        message,
        EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) AS duration_seconds
    FROM {TABLE_LOADING_HISTORY}
    WHERE object_name = :table_name and object_type='table'
    ORDER BY loading_finish_dttm DESC
    LIMIT 5
    """
    with engine.connect() as conn:
        result = conn.execute(text(query), {"table_name": table_name}).fetchall()
        columns = result[0].keys() if result else []
        return [dict(zip(columns, row)) for row in result]


@router.get("/api/metrics")
def get_metrics():
    try:
        with engine.connect() as conn:
            total_tables = conn.execute(text(f"SELECT COUNT(*) FROM {TABLE_TABLES_META} WHERE flag_active = true")).scalar()

            error_count = conn.execute(
                text(
                    f"""
                SELECT COUNT(*)
                FROM {TABLE_LOADING_HISTORY}
                WHERE loading_state = 'FAILED' and object_type='table'
                  AND loading_start_dttm >= now() - interval '24 hours'
            """
                )
            ).scalar()

            avg_duration = conn.execute(
                text(
                    f"""
                SELECT ROUND(cast(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60) as numeric), 1)
                FROM {TABLE_LOADING_HISTORY}
                WHERE loading_state = 'SUCCESS' and object_type='table'
                  AND loading_start_dttm >= now() - interval '24 hours'
            """
                )
            ).scalar()

            active_entities = conn.execute(text(f"SELECT COUNT(*) FROM {TABLE_ENTITIES_META} WHERE flag_active = true")).scalar()

            return JSONResponse(
                content={
                    "total_tables": total_tables,
                    "error_count": error_count,
                    "avg_duration_minutes": float(avg_duration) if avg_duration is not None else None,
                    "active_entities": active_entities,
                },
                media_type="application/json; charset=utf-8",
            )
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/table-history/{schema}/{table:path}")
def get_table_history(schema: str, table: str, limit: int = Query(10, ge=1, le=50)):
    schema_norm, table_norm = _normalize_table_param(schema, table)
    table_clean = _clean_table_name(table_norm)
    table_id = None

    try:
        with engine.connect() as conn:
            table_id = conn.execute(
                text(
                    f"""
                    SELECT table_id
                    FROM {TABLE_TABLES_META}
                    WHERE lower(table_schema) = :schema
                      AND (lower(table_name) = :table OR lower(table_name) = :table_clean)
                    LIMIT 1
                    """
                ),
                {"schema": schema_norm, "table": table_norm, "table_clean": table_clean},
            ).scalar()

            params = {"limit": limit}
            if table_id:
                where_clause = "object_id = :table_id"
                params["table_id"] = table_id
            else:
                where_clause = """
                    lower(object_name) = :table_fqn
                    OR lower(object_name) = :table_fqn_clean
                    OR lower(object_name) = :table_name
                    OR lower(object_name) = :table_name_clean
                """
                params["table_fqn"] = f"{schema_norm}.{table_norm}"
                params["table_fqn_clean"] = f"{schema_norm}.{table_clean}" if table_clean else None
                params["table_name"] = table_norm
                params["table_name_clean"] = table_clean

            rows = conn.execute(
                text(
                    f"""
                    SELECT
                        loading_start_dttm,
                        loading_finish_dttm,
                        loading_state,
                        message,
                        EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60.0 AS duration_minutes
                    FROM {TABLE_LOADING_HISTORY}
                    WHERE object_type = 'table'
                      AND {where_clause}
                    ORDER BY loading_finish_dttm DESC NULLS LAST
                    LIMIT :limit
                    """
                ),
                params,
            ).mappings().all()

        payload = [
            {
                "start": serialize_datetime(row.get("loading_start_dttm")),
                "finish": serialize_datetime(row.get("loading_finish_dttm")),
                "state": row.get("loading_state"),
                "message": row.get("message"),
                "duration_minutes": round(float(row["duration_minutes"]), 2)
                if row.get("duration_minutes") is not None
                else None,
            }
            for row in rows
        ]
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/table-variants/{schema}/{table:path}")
def get_table_variants(schema: str, table: str):
    schema_norm, table_norm = _normalize_table_param(schema, table)
    table_clean = _clean_table_name(table_norm)
    query = f"""
        SELECT
            t.table_id,
            t.table_schema,
            t.table_name,
            t.table_last_load,
            t.entity_id,
            e.entity_name
        FROM {TABLE_TABLES_META} t
        LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
        WHERE lower(t.table_schema) = :schema
          AND (lower(t.table_name) = :table OR lower(t.table_name) = :table_clean)
        ORDER BY t.table_id
    """
    try:
        with engine.connect() as conn:
            rows = conn.execute(
                text(query),
                {"schema": schema_norm, "table": table_norm, "table_clean": table_clean},
            ).mappings().all()

        payload = []
        for row in rows:
            payload.append(
                {
                    "table_id": row.get("table_id"),
                    "table_schema": row.get("table_schema"),
                    "table_name": row.get("table_name"),
                    "entity_id": row.get("entity_id"),
                    "entity_name": row.get("entity_name"),
                    "table_last_load": serialize_datetime(row.get("table_last_load")),
                }
            )
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/dq/table/{schema}/{table:path}")
def get_table_quality(schema: str, table: str):
    schema_norm, table_norm = _normalize_table_param(schema, table)
    table_clean = _clean_table_name(table_norm)
    try:
        with engine.connect() as conn:
            dup_row = conn.execute(
                text(
                    f"""
                    SELECT metric_result, dt_of_verification
                    FROM {TABLE_DATA_QUALITY}
                    WHERE verification_type = 'duplicate_check'
                      AND lower(table_schema) = :schema
                      AND (lower(table_name) = :table OR lower(table_name) = :table_clean)
                    ORDER BY dt_of_verification DESC NULLS LAST
                    LIMIT 1
                    """
                ),
                {"schema": schema_norm, "table": table_norm, "table_clean": table_clean},
            ).mappings().first()

            rc_rows = conn.execute(
                text(
                    f"""
                    SELECT metric_result, dt_of_verification
                    FROM {TABLE_DATA_QUALITY}
                    WHERE verification_type = 'row_count'
                      AND lower(table_schema) = :schema
                      AND (lower(table_name) = :table OR lower(table_name) = :table_clean)
                    ORDER BY dt_of_verification DESC NULLS LAST
                    LIMIT 8
                    """
                ),
                {"schema": schema_norm, "table": table_norm, "table_clean": table_clean},
            ).mappings().all()

        duplicate_count = _parse_numeric(dup_row.get("metric_result")) if dup_row else None
        duplicate_last = serialize_datetime(dup_row.get("dt_of_verification")) if dup_row else None

        row_counts = []
        for row in rc_rows:
            value = _parse_numeric(row.get("metric_result"))
            if value is None:
                continue
            row_counts.append({
                "value": value,
                "dt": row.get("dt_of_verification"),
            })

        row_counts_sorted = sorted(row_counts, key=lambda r: r["dt"] or datetime.min, reverse=True)
        latest_row = row_counts_sorted[0] if row_counts_sorted else None
        baseline_values = [r["value"] for r in row_counts_sorted[1:8] if r.get("value") is not None]

        baseline = None
        if baseline_values:
            baseline = float(sorted(baseline_values)[len(baseline_values) // 2])

        delta_pct = None
        if baseline and latest_row:
            delta_pct = round(((latest_row["value"] - baseline) / baseline) * 100, 2)

        payload = {
            "duplicate": {
                "count": int(duplicate_count) if duplicate_count is not None else None,
                "last_check": duplicate_last,
            },
            "row_count": {
                "count": int(latest_row["value"]) if latest_row else None,
                "last_check": serialize_datetime(latest_row["dt"]) if latest_row else None,
                "baseline_median": baseline,
                "delta_pct": delta_pct,
                "samples": len(baseline_values),
            },
        }
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/dq/history/{schema}/{table:path}")
def get_table_quality_history(schema: str, table: str, limit: int = Query(20, ge=1, le=200)):
    schema_norm, table_norm = _normalize_table_param(schema, table)
    table_clean = _clean_table_name(table_norm)
    try:
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    f"""
                    SELECT verification_type, metric_result, dt_of_verification
                    FROM {TABLE_DATA_QUALITY}
                    WHERE lower(table_schema) = :schema
                      AND (lower(table_name) = :table OR lower(table_name) = :table_clean)
                    ORDER BY dt_of_verification DESC NULLS LAST
                    LIMIT :limit
                    """
                ),
                {"schema": schema_norm, "table": table_norm, "table_clean": table_clean, "limit": limit},
            ).mappings().all()

        payload = [
            {
                "verification_type": row.get("verification_type"),
                "metric_result": row.get("metric_result"),
                "value": _parse_numeric(row.get("metric_result")),
                "dt": serialize_datetime(row.get("dt_of_verification")),
            }
            for row in rows
        ]
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


def _collect_dq_alerts(days: int, delta: float) -> list[dict]:
    now = datetime.utcnow()
    entity_map = _entity_map_from_meta()
    with engine.connect() as conn:
        dup_rows = conn.execute(
            text(
                f"""
                WITH ranked AS (
                  SELECT
                    lower(table_schema) AS schema,
                    lower(table_name) AS table_name,
                    metric_result,
                    dt_of_verification,
                    ROW_NUMBER() OVER (
                      PARTITION BY lower(table_schema), lower(table_name)
                      ORDER BY dt_of_verification DESC
                    ) AS rn
                  FROM {TABLE_DATA_QUALITY}
                  WHERE verification_type = 'duplicate_check'
                    AND dt_of_verification >= now() - interval '{days} days'
                )
                SELECT schema, table_name, metric_result, dt_of_verification
                FROM ranked
                WHERE rn = 1
                """
            )
        ).mappings().all()

        rc_rows = conn.execute(
            text(
                f"""
                WITH ranked AS (
                  SELECT
                    lower(table_schema) AS schema,
                    lower(table_name) AS table_name,
                    metric_result,
                    dt_of_verification,
                    ROW_NUMBER() OVER (
                      PARTITION BY lower(table_schema), lower(table_name)
                      ORDER BY dt_of_verification DESC
                    ) AS rn
                  FROM {TABLE_DATA_QUALITY}
                  WHERE verification_type = 'row_count'
                )
                SELECT schema, table_name, metric_result, dt_of_verification, rn
                FROM ranked
                WHERE rn <= 8
                """
            )
        ).mappings().all()

    alerts = []
    for row in dup_rows:
        count = _parse_numeric(row.get("metric_result")) or 0
        if count <= 0:
            continue
        fqn = f"{row.get('schema')}.{row.get('table_name')}"
        alerts.append({
            "type": "duplicate_check",
            "table_schema": row.get("schema"),
            "table_name": row.get("table_name"),
            "entity_name": entity_map.get(fqn),
            "metric_value": int(count),
            "delta_pct": None,
            "dt": serialize_datetime(row.get("dt_of_verification")),
        })

    rc_grouped = {}
    for row in rc_rows:
        key = f"{row.get('schema')}.{row.get('table_name')}"
        rc_grouped.setdefault(key, []).append(row)

    for key, rows in rc_grouped.items():
        rows_sorted = sorted(rows, key=lambda r: r.get("dt_of_verification") or datetime.min, reverse=True)
        latest = rows_sorted[0]
        if latest.get("dt_of_verification") and (now - latest["dt_of_verification"]).days > days:
            continue
        latest_val = _parse_numeric(latest.get("metric_result"))
        baseline_vals = [
            _parse_numeric(r.get("metric_result"))
            for r in rows_sorted[1:8]
            if _parse_numeric(r.get("metric_result")) is not None
        ]
        if latest_val is None or not baseline_vals:
            continue
        baseline = float(sorted(baseline_vals)[len(baseline_vals) // 2])
        if baseline == 0:
            continue
        delta_pct = ((latest_val - baseline) / baseline) * 100
        if abs(delta_pct) < delta:
            continue
            schema, table_name = key.split(".", 1)
            alerts.append({
                "type": "row_count",
                "table_schema": schema,
                "table_name": table_name,
                "entity_name": entity_map.get(key),
                "metric_value": int(latest_val),
                "delta_pct": round(delta_pct, 2),
                "dt": serialize_datetime(latest.get("dt_of_verification")),
            })

    alerts.sort(
        key=lambda a: (
            0 if a["type"] == "duplicate_check" else 1,
            -(a.get("metric_value") or 0),
            -abs(a.get("delta_pct") or 0),
        )
    )
    return alerts


@router.get("/api/dq/summary")
def get_quality_summary(days: int = Query(7, ge=1, le=90), delta: float = Query(10.0, ge=0)):
    try:
        now = datetime.utcnow()
        with engine.connect() as conn:
            dup_rows = conn.execute(
                text(
                    f"""
                    WITH ranked AS (
                      SELECT
                        lower(table_schema) AS schema,
                        lower(table_name) AS table_name,
                        metric_result,
                        dt_of_verification,
                        ROW_NUMBER() OVER (
                          PARTITION BY lower(table_schema), lower(table_name)
                          ORDER BY dt_of_verification DESC
                        ) AS rn
                      FROM {TABLE_DATA_QUALITY}
                      WHERE verification_type = 'duplicate_check'
                        AND dt_of_verification >= now() - interval '{days} days'
                    )
                    SELECT schema, table_name, metric_result, dt_of_verification
                    FROM ranked
                    WHERE rn = 1
                    """
                )
            ).mappings().all()

            rc_rows = conn.execute(
                text(
                    f"""
                    WITH ranked AS (
                      SELECT
                        lower(table_schema) AS schema,
                        lower(table_name) AS table_name,
                        metric_result,
                        dt_of_verification,
                        ROW_NUMBER() OVER (
                          PARTITION BY lower(table_schema), lower(table_name)
                          ORDER BY dt_of_verification DESC
                        ) AS rn
                      FROM {TABLE_DATA_QUALITY}
                      WHERE verification_type = 'row_count'
                    )
                    SELECT schema, table_name, metric_result, dt_of_verification, rn
                    FROM ranked
                    WHERE rn <= 8
                    """
                )
            ).mappings().all()

        dup_issues = 0
        for row in dup_rows:
            count = _parse_numeric(row.get("metric_result")) or 0
            if count > 0:
                dup_issues += 1

        rc_grouped = {}
        for row in rc_rows:
            key = f"{row.get('schema')}.{row.get('table_name')}"
            rc_grouped.setdefault(key, []).append(row)

        rc_issues = 0
        checked_rc = 0
        for key, rows in rc_grouped.items():
            rows_sorted = sorted(rows, key=lambda r: r.get("dt_of_verification") or datetime.min, reverse=True)
            latest = rows_sorted[0]
            if latest.get("dt_of_verification") and (now - latest["dt_of_verification"]).days > days:
                continue
            latest_val = _parse_numeric(latest.get("metric_result"))
            baseline_vals = [
                _parse_numeric(r.get("metric_result"))
                for r in rows_sorted[1:8]
                if _parse_numeric(r.get("metric_result")) is not None
            ]
            if latest_val is None or not baseline_vals:
                continue
            checked_rc += 1
            baseline = float(sorted(baseline_vals)[len(baseline_vals) // 2])
            if baseline == 0:
                continue
            delta_pct = ((latest_val - baseline) / baseline) * 100
            if abs(delta_pct) >= delta:
                rc_issues += 1

        payload = {
            "days": days,
            "duplicate_tables": dup_issues,
            "row_count_tables": rc_issues,
            "row_count_checked": checked_rc,
        }
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/dq/alerts")
def get_quality_alerts(
    days: int = Query(7, ge=1, le=90),
    delta: float = Query(10.0, ge=0),
    limit: int = Query(20, ge=1, le=200),
):
    try:
        alerts = _collect_dq_alerts(days, delta)
        return JSONResponse(content=alerts[:limit], media_type="application/json; charset=utf-8")
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/dq/entity")
def get_quality_by_entity(
    days: int = Query(7, ge=1, le=90),
    delta: float = Query(10.0, ge=0),
    limit: int = Query(12, ge=1, le=50),
):
    alerts = _collect_dq_alerts(days, delta)
    grouped = {}
    for alert in alerts:
        entity = alert.get("entity_name") or "UNKNOWN"
        entry = grouped.setdefault(entity, {"entity": entity, "duplicates": 0, "row_count": 0})
        if alert.get("type") == "duplicate_check":
            entry["duplicates"] += 1
        if alert.get("type") == "row_count":
            entry["row_count"] += 1

    rows = sorted(grouped.values(), key=lambda r: (-(r["duplicates"] + r["row_count"]), r["entity"]))
    return JSONResponse(content=rows[:limit], media_type="application/json; charset=utf-8")


def find_path_case_insensitive(parent_path: Path, name: str) -> Optional[Path]:
    for item in parent_path.iterdir():
        if item.name.lower() == name.lower():
            return item
    return None


@router.get("/api/card/{schema}/{table:path}")
def get_table_card_info_by_path(schema: str, table: str):
    for entity_folder in iter_meta_dirs():
        schema_folder = find_path_case_insensitive(entity_folder, schema)
        if not schema_folder:
            continue

        table_folder = find_path_case_insensitive(schema_folder, table)
        if not table_folder:
            continue

        yaml_file = table_folder / "meta_data_file.yaml"
        if not yaml_file.exists():
            return JSONResponse(status_code=404, content={"error": "meta_data_file.yaml not found"})

        try:
            with open(yaml_file, encoding="utf-8") as f:
                meta = yaml.safe_load(f)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})

        def read_sql_file(filename: str) -> str:
            file_path = table_folder / filename
            return file_path.read_text(encoding="utf-8") if file_path.exists() else f"-- {filename} not found"

        meta["sql_query_insert_init_sql"] = read_sql_file("sql_query_insert_init.sql")
        meta["sql_query_recreate_init_sql"] = read_sql_file("sql_query_recreate_init.sql")
        meta["sql_query_truncate_sql"] = read_sql_file("sql_query_truncate.sql")

        # метрики
        # метрики
        table_id = meta.get("table_id")
        avg_duration = None
        last_success_time = None
        table_size_mb = None

        if table_id:
            try:
                with engine.connect() as conn:
                    duration_result = conn.execute(
                        text(
                            f"""
                        SELECT round(cast(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60) as numeric), 1)
                        FROM {TABLE_LOADING_HISTORY}
                        WHERE loading_state = 'SUCCESS'
                          AND object_type='table'
                          AND object_id = :object_id
                    """
                        ),
                        {"object_id": table_id},
                    )
                    avg_duration = float(duration_result.scalar() or 0)

                    time_result = conn.execute(
                        text(
                            f"""
                        SELECT table_last_load
                        FROM {TABLE_TABLES_META}
                        WHERE table_id = :object_id
                    """
                        ),
                        {"object_id": table_id},
                    )
                    dt_val = time_result.scalar()
                    if isinstance(dt_val, datetime):
                        last_success_time = dt_val.strftime("%Y-%m-%d %H:%M:%S")

                    # ✅ ВОТ ТУТ — НОВЫЙ БЕЗОПАСНЫЙ КОД
                    size_sql = text("""
                        SELECT
                          pg_total_relation_size(
                            to_regclass(:full_table_name)
                          )::bigint / 1024 / 1024
                    """)

                    schema_name = meta.get("table_schema") or schema
                    table_name = meta.get("table_name") or table
                    schema_name = str(schema_name or "")
                    table_name = str(table_name or "")

                    def quote_ident(value: str) -> str:
                        escaped = value.replace('"', '""')
                        return f"\"{escaped}\""

                    def build_regclass(schema_val: str, table_val: str) -> str:
                        if not schema_val or not table_val:
                            return ""
                        needs_quote = (
                            schema_val.lower() in {"stg", "dict_stg"}
                            or schema_val != schema_val.lower()
                            or table_val != table_val.lower()
                        )
                        if needs_quote:
                            return f"{quote_ident(schema_val)}.{quote_ident(table_val)}"
                        return f"{schema_val.lower()}.{table_val.lower()}"

                    regclass_name = build_regclass(schema_name, table_name)

                    size_result = conn.execute(
                        size_sql,
                        {"full_table_name": regclass_name},
                    ).scalar()

                    table_size_mb = int(size_result) if size_result is not None else None

            except Exception as e:
                print(f"Ошибка при получении метрик: {e}")

        meta["avg_duration_minutes"] = avg_duration
        meta["last_success_time"] = last_success_time
        meta["table_size_mb"] = table_size_mb

        return JSONResponse(content=meta, media_type="application/json; charset=utf-8")

    print(f"[WARN] Table {schema}.{table} not found in any of TOP_DIRS")
    return JSONResponse(status_code=404, content={"error": "Table not found in any folder"})


@router.get("/api/tables")
def list_all_tables():
    all_meta, _ = get_cached_meta_and_index()
    all_tables = {}
    for meta in all_meta:
        schema = meta.get("table_schema")
        table = meta.get("table_name")
        if schema and table:
            key = f"{schema}.{table}"
            all_tables.setdefault(key.lower(), key)
    return JSONResponse(content=sorted(all_tables.values(), key=lambda v: v.lower()))


@router.get("/api/graph/overview")
def get_graph_overview():
    snapshot = get_graph_snapshot()
    nodes = snapshot["entity_graph"]["nodes"]
    edges = snapshot["entity_graph"]["edges"]
    layout = snapshot["layouts"]["entity"]

    nodes, edges, layout, truncated = _cap_graph(
        nodes, edges, layout, max_nodes=150, max_edges=300, sort_key="tables_count"
    )
    return {
        "nodes": list(nodes.values()),
        "edges": edges,
        "layout": layout,
        "truncated": truncated,
        "entity_cycles": snapshot.get("entity_cycles", []),
        "entity_mutual": snapshot.get("entity_mutual_any", []),
        "table_cycles": snapshot.get("table_cycles", []),
    }


@router.get("/api/graph/diagnostics")
def get_graph_diagnostics(include_any: bool = Query(True)):
    snapshot = get_graph_snapshot()
    return {
        "entity_cycles": snapshot.get("entity_cycles", []),
        "entity_mutual": snapshot.get("entity_mutual_any", []) if include_any else snapshot.get("entity_mutual", []),
        "table_cycles": snapshot.get("table_cycles", []),
    }


@router.get("/api/graph/diagnostics/mutual")
def get_graph_mutual_details(
    entity_a: str = Query(...),
    entity_b: str = Query(...),
    strict: bool = Query(True),
):
    snapshot = get_graph_snapshot()
    table_edges = snapshot["table_graph"]["edges"]
    table_entities = {k: set(v) for k, v in snapshot["table_entity_map"].items()}

    def norm_entity(value: str) -> str:
        return (value or "").strip().lower()

    a = norm_entity(entity_a)
    b = norm_entity(entity_b)
    if not a or not b:
        return JSONResponse(status_code=400, content={"error": "invalid entities"})
    if _normalize_entity_group(a) == _normalize_entity_group(b):
        return {"entity_a": entity_a, "entity_b": entity_b, "edges_ab": [], "edges_ba": []}

    edges_ab = []
    edges_ba = []
    for edge in table_edges:
        src = edge.get("source")
        tgt = edge.get("target")
        if not src or not tgt:
            continue
        src_ents = table_entities.get(src) or set()
        tgt_ents = table_entities.get(tgt) or set()
        for src_ent in src_ents:
            for tgt_ent in tgt_ents:
                if not src_ent or not tgt_ent or src_ent == tgt_ent:
                    continue
                src_norm = {norm_entity(e) for e in src_ents if isinstance(e, str)}
                tgt_norm = {norm_entity(e) for e in tgt_ents if isinstance(e, str)}
                allowed = {a, b}
                if strict and (not src_norm.issubset(allowed) or not tgt_norm.issubset(allowed)):
                    continue
                if (
                    norm_entity(src_ent) == a
                    and norm_entity(tgt_ent) == b
                    and norm_entity(tgt_ent) not in {norm_entity(e) for e in src_ents}
                    and norm_entity(src_ent) not in {norm_entity(e) for e in tgt_ents}
                ):
                    edges_ab.append({
                        "source": src,
                        "target": tgt,
                        "source_entities": sorted(src_ents),
                        "target_entities": sorted(tgt_ents),
                    })
                elif (
                    norm_entity(src_ent) == b
                    and norm_entity(tgt_ent) == a
                    and norm_entity(tgt_ent) not in {norm_entity(e) for e in src_ents}
                    and norm_entity(src_ent) not in {norm_entity(e) for e in tgt_ents}
                ):
                    edges_ba.append({
                        "source": src,
                        "target": tgt,
                        "source_entities": sorted(src_ents),
                        "target_entities": sorted(tgt_ents),
                    })

    return {
        "entity_a": entity_a,
        "entity_b": entity_b,
        "edges_ab": edges_ab,
        "edges_ba": edges_ba,
    }


@router.get("/api/graph/entity/{entity_name}")
def get_graph_entity(entity_name: str):
    snapshot = get_graph_snapshot()
    table_nodes = snapshot["table_graph"]["nodes"]
    table_edges = snapshot["table_graph"]["edges"]
    table_entity_map = snapshot["table_entity_map"]

    target = (entity_name or "").strip().lower()
    all_entities = {e for ents in table_entity_map.values() for e in ents}
    entity_key = next((e for e in all_entities if e.lower() == target), None)

    if not entity_key:
        return JSONResponse(status_code=404, content={"error": "entity not found"})

    entity_tables = {t for t, ents in table_entity_map.items() if entity_key in ents}
    if not entity_tables:
        return JSONResponse(status_code=404, content={"error": "entity has no tables"})

    nodes_set = set(entity_tables)
    edges_filtered = []
    for e in table_edges:
        if e["source"] in entity_tables or e["target"] in entity_tables:
            nodes_set.add(e["source"])
            nodes_set.add(e["target"])
            edges_filtered.append(e)

    truncated = False
    if len(nodes_set) > 300:
        keep = set(entity_tables)
        extra = [n for n in nodes_set if n not in keep]
        extra.sort()
        for n in extra:
            if len(keep) >= 300:
                truncated = True
                break
            keep.add(n)
        nodes_set = keep

    edges_filtered = [e for e in edges_filtered if e["source"] in nodes_set and e["target"] in nodes_set]
    if len(edges_filtered) > 500:
        edges_filtered = edges_filtered[:500]
        truncated = True

    nodes_payload = _normalize_layer_widths([table_nodes[n] for n in nodes_set if n in table_nodes])
    layout_payload = _grid_layout_subset(table_nodes, edges_filtered, nodes_set)

    return {
        "entity": {
            "id": f"ENTITY::{entity_key}",
            "label": entity_key,
            "tables_count": len(entity_tables),
        },
        "nodes": nodes_payload,
        "edges": edges_filtered,
        "layout": layout_payload,
        "truncated": truncated,
    }


@router.get("/api/graph/table/{schema}/{table:path}")
def get_graph_table(schema: str, table: str, depth: int = Query(3, ge=1, le=4)):
    snapshot = get_graph_snapshot()
    table_nodes = snapshot["table_graph"]["nodes"]
    table_edges = snapshot["table_graph"]["edges"]

    schema_norm = norm(schema)
    table_norm = norm(table)
    key = f"{schema_norm}.{table_norm}"
    if key not in table_nodes:
        return JSONResponse(status_code=404, content={"error": "table not found"})

    rev = {}
    for e in table_edges:
        rev.setdefault(e["target"], []).append(e["source"])

    visited = {key}
    queue = deque([(key, 0)])
    truncated = False
    max_nodes = 300

    while queue:
        node, d = queue.popleft()
        if d >= depth:
            continue
        for nxt in rev.get(node, []):
            if nxt in visited:
                continue
            visited.add(nxt)
            if len(visited) >= max_nodes:
                truncated = True
                queue.clear()
                break
            queue.append((nxt, d + 1))
        if truncated:
            break

    edges_filtered = [e for e in table_edges if e["source"] in visited and e["target"] in visited]
    if len(edges_filtered) > 500:
        edges_filtered = edges_filtered[:500]
        truncated = True

    nodes_payload = _normalize_layer_widths([table_nodes[n] for n in visited if n in table_nodes])
    layout_payload = _grid_layout_subset(table_nodes, edges_filtered, visited)

    return {
        "table": table_nodes[key],
        "nodes": nodes_payload,
        "edges": edges_filtered,
        "layout": layout_payload,
        "depth": depth,
        "truncated": truncated,
    }


def _layer_label_from_schema(schema: str) -> str:
    if not schema:
        return "OTHER"
    schema = schema.lower()
    if schema.startswith("dict_"):
        return "DICT"
    if schema == "stg":
        return "STG"
    if schema == "ods":
        return "ODS"
    if schema == "dds":
        return "DDS"
    if schema == "dm_calc":
        return "DM_CALC"
    if schema.startswith("dm"):
        return "DM"
    return schema.upper()


def _traverse_forward(
    start: str,
    edges: list[dict],
    depth: int,
    max_nodes: int,
) -> tuple[set[str], dict[str, int], bool]:
    forward = {}
    for edge in edges:
        forward.setdefault(edge["source"], []).append(edge["target"])

    visited = {start}
    depth_map = {start: 0}
    queue = deque([(start, 0)])
    truncated = False

    while queue:
        node, d = queue.popleft()
        if d >= depth:
            continue
        for nxt in forward.get(node, []):
            if nxt in visited:
                continue
            visited.add(nxt)
            depth_map[nxt] = d + 1
            if len(visited) >= max_nodes:
                truncated = True
                queue.clear()
                break
            queue.append((nxt, d + 1))
        if truncated:
            break

    return visited, depth_map, truncated


@router.get("/api/graph/impact/{schema}/{table:path}")
def get_graph_impact(schema: str, table: str, depth: int = Query(3, ge=1, le=4)):
    snapshot = get_graph_snapshot()
    table_nodes = snapshot["table_graph"]["nodes"]
    table_edges = snapshot["table_graph"]["edges"]

    schema_norm = norm(schema)
    table_norm = norm(table)
    key = f"{schema_norm}.{table_norm}"
    if key not in table_nodes:
        return JSONResponse(status_code=404, content={"error": "table not found"})

    visited, _, truncated = _traverse_forward(key, table_edges, depth, max_nodes=300)

    edges_filtered = [e for e in table_edges if e["source"] in visited and e["target"] in visited]
    if len(edges_filtered) > 500:
        edges_filtered = edges_filtered[:500]
        truncated = True

    nodes_payload = _normalize_layer_widths([table_nodes[n] for n in visited if n in table_nodes])
    layout_payload = _grid_layout_subset(table_nodes, edges_filtered, visited)

    return {
        "table": table_nodes[key],
        "nodes": nodes_payload,
        "edges": edges_filtered,
        "layout": layout_payload,
        "depth": depth,
        "truncated": truncated,
    }


@router.get("/api/impact/summary/{schema}/{table:path}")
def get_impact_summary(
    schema: str,
    table: str,
    depth: int = Query(3, ge=1, le=5),
    max_nodes: int = Query(800, ge=50, le=5000),
    limit: int = Query(120, ge=0, le=2000),
):
    snapshot = get_graph_snapshot()
    table_nodes = snapshot["table_graph"]["nodes"]
    table_edges = snapshot["table_graph"]["edges"]

    schema_norm = norm(schema)
    table_norm = norm(table)
    key = f"{schema_norm}.{table_norm}"
    if key not in table_nodes:
        return JSONResponse(status_code=404, content={"error": "table not found"})

    visited, depth_map, truncated = _traverse_forward(key, table_edges, depth, max_nodes=max_nodes)
    visited.discard(key)

    entity_counts = {}
    layer_counts = {}
    table_rows = []
    for node_id in visited:
        node = table_nodes.get(node_id)
        if not node:
            continue
        schema_val = node.get("schema") or ""
        layer = _layer_label_from_schema(schema_val)
        layer_counts[layer] = layer_counts.get(layer, 0) + 1

        entities = node.get("entities") or []
        if not entities:
            entities = [node.get("entity") or "UNKNOWN"]
        for ent in entities:
            if not ent:
                continue
            entity_counts[ent] = entity_counts.get(ent, 0) + 1

        table_rows.append(
            {
                "id": node_id,
                "schema": node.get("schema"),
                "table": node.get("table"),
                "entity": node.get("entity"),
                "entities": entities,
                "layer": layer,
                "depth": depth_map.get(node_id, 0),
            }
        )

    entities_list = [
        {"entity": ent, "count": count}
        for ent, count in sorted(entity_counts.items(), key=lambda x: (-x[1], x[0]))
    ]
    layers_list = [
        {"layer": layer, "count": count}
        for layer, count in sorted(layer_counts.items(), key=lambda x: (-x[1], x[0]))
    ]

    table_rows.sort(key=lambda r: (r.get("depth") or 0, r.get("id") or ""))
    if limit:
        table_rows = table_rows[:limit]

    return {
        "table": table_nodes[key],
        "total_tables": len(visited),
        "total_entities": len(entity_counts),
        "entities": entities_list,
        "layers": layers_list,
        "tables": table_rows,
        "depth": depth,
        "truncated": truncated,
    }


@router.get("/api/impact/list/{schema}/{table:path}")
def get_impact_list(
    schema: str,
    table: str,
    depth: int = Query(4, ge=1, le=6),
    max_nodes: int = Query(2500, ge=100, le=10000),
):
    snapshot = get_graph_snapshot()
    table_nodes = snapshot["table_graph"]["nodes"]
    table_edges = snapshot["table_graph"]["edges"]

    schema_norm = norm(schema)
    table_norm = norm(table)
    key = f"{schema_norm}.{table_norm}"
    if key not in table_nodes:
        return JSONResponse(status_code=404, content={"error": "table not found"})

    visited, depth_map, truncated = _traverse_forward(key, table_edges, depth, max_nodes=max_nodes)
    visited.discard(key)

    table_rows = []
    for node_id in visited:
        node = table_nodes.get(node_id)
        if not node:
            continue
        schema_val = node.get("schema") or ""
        layer = _layer_label_from_schema(schema_val)
        entities = node.get("entities") or []
        if not entities:
            entities = [node.get("entity") or "UNKNOWN"]
        table_rows.append(
            {
                "id": node_id,
                "schema": node.get("schema"),
                "table": node.get("table"),
                "entities": entities,
                "layer": layer,
                "depth": depth_map.get(node_id, 0),
            }
        )

    table_rows.sort(key=lambda r: (r.get("depth") or 0, r.get("id") or ""))
    return {
        "table": table_nodes[key],
        "tables": table_rows,
        "depth": depth,
        "truncated": truncated,
    }


@router.get("/api/inconsistencies")
def get_dependency_violations():
    all_meta, _ = get_cached_meta_and_index()
    dependency_pairs = []

    for meta in all_meta:
        dependent_schema = meta.get("table_schema")
        dependent_table = meta.get("table_name")
        depends_on = meta.get("depends_on", {})
        for source_schema, source_tables in depends_on.items():
            for source_table in source_tables:
                dependency_pairs.append(((source_schema, source_table), (dependent_schema, dependent_table)))

    all_tables = set()
    for src, dep in dependency_pairs:
        all_tables.add(src)
        all_tables.add(dep)

    # Load last N successful runs per table so we can compare the latest source and target refreshes.
    last_loads = {}
    with engine.connect() as conn:
        tables_by_schema = {}
        for schema, table in all_tables:
            tables_by_schema.setdefault(schema, set()).add(table)

        for schema, tables in tables_by_schema.items():
            if not schema or not tables:
                continue
            query = text(
                f"""
                WITH base AS (
                    SELECT
                        COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) AS table_schema,
                        COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_name,
                        l.loading_finish_dttm
                    FROM {TABLE_LOADING_HISTORY} l
                    LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                    WHERE l.object_type = 'table'
                      AND l.loading_state = 'SUCCESS'
                      AND l.loading_finish_dttm IS NOT NULL
                      AND t.table_schema = :schema
                      AND t.table_name = ANY(:tables)
                )
                SELECT table_schema, table_name, loading_finish_dttm
                FROM (
                    SELECT
                        table_schema,
                        table_name,
                        loading_finish_dttm,
                        ROW_NUMBER() OVER (
                            PARTITION BY table_schema, table_name
                            ORDER BY loading_finish_dttm DESC
                        ) AS rn
                    FROM base
                ) x
                WHERE rn <= :limit
                """
            )
            result = conn.execute(
                query,
                {"schema": schema, "tables": list(tables), "limit": 6},
            ).mappings().all()

            for row in result:
                key = (row.get("table_schema"), row.get("table_name"))
                if not key[0] or not key[1]:
                    continue
                last_loads.setdefault(key, []).append(row.get("loading_finish_dttm"))

    # Sort times DESC for each table
    for key in list(last_loads.keys()):
        times = [t for t in last_loads.get(key, []) if t]
        times.sort(reverse=True)
        last_loads[key] = times

    problems = []
    for (src_schema, src_table), (dep_schema, dep_table) in dependency_pairs:
        dep_times = last_loads.get((dep_schema, dep_table)) or []
        src_times = last_loads.get((src_schema, src_table)) or []
        if not dep_times or not src_times:
            continue
        dep_time = dep_times[0]
        src_time = src_times[0]
        # Violation when the latest upstream refresh finished after the latest dependent refresh.
        if not src_time or src_time <= dep_time:
            continue
        problems.append(
            {
                "source_schema": src_schema,
                "source_table": src_table,
                "source_last_load": src_time.strftime("%Y-%m-%d %H:%M:%S"),
                "dependent_schema": dep_schema,
                "dependent_table": dep_table,
                "dependent_last_load": dep_time.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )

    return JSONResponse(content=problems, media_type="application/json; charset=utf-8")


@router.get("/api/sla")
def get_sla_monitoring():
    query = f"""
        WITH exploded AS (
            SELECT 
                s.report,
                s.source_table,
                s.owner_report,
                s.load_update_table,
                s.load_update_report,
                s.load_interval,
                s.table_name,
                regexp_split_to_table(s.table_name, E'\\n') AS split_table
            FROM {TABLE_YT_SLA} s
        ),
        cleaned AS (
            SELECT *,
                   trim(split_table) AS clean_table,
                   split_part(trim(split_table), '.', 1) AS schema_name,
                   split_part(trim(split_table), '.', 2) AS table_name_only
            FROM exploded
        ),
        click as (
        select 
        	(REGEXP_MATCHES(ddl_clickhouse_view, 'DROP VIEW IF EXISTS\\s+"([^"]+)"\\."([^"]+)"'))[1] as schema_name_view,
        	(REGEXP_MATCHES(ddl_clickhouse_view, 'DROP VIEW IF EXISTS\\s+"([^"]+)"\\."([^"]+)"'))[2] as table_name_view,
        	(REGEXP_MATCHES(ddl_clickhouse_target, 'DROP TABLE IF EXISTS\\s+"([^"]+)"\\."([^"]+)"'))[1] as schema_name_table,
        	(REGEXP_MATCHES(ddl_clickhouse_target, 'DROP TABLE IF EXISTS\\s+"([^"]+)"\\."([^"]+)"'))[2] as table_name_table,
        	table_last_upload
        from {TABLE_TABLES_META_CLICK} ),
        joined AS (
            SELECT 
                c.report,
                c.source_table,
                c.owner_report,
                c.load_update_table,
                c.load_update_report,
                c.load_interval,
                c.table_name AS original_table_name,
                c.clean_table,
                coalesce(tm.table_last_load, cl.table_last_upload, clt.table_last_upload)  as table_last_load
            FROM cleaned c
            LEFT JOIN {TABLE_TABLES_META} tm
              ON tm.table_schema = c.schema_name
             AND tm.table_name = c.table_name_only and source_table='GP'
            left join click cl 
             ON cl.schema_name_view = c.schema_name
             AND cl.table_name_view = c.table_name_only and source_table='Click'
             left join click clt 
             ON clt.schema_name_table = c.schema_name
             AND clt.table_name_table = c.table_name_only and source_table='Click'
        ),
        with_flags AS (
            SELECT *,
                   (table_last_load IS NOT NULL AND
                    (
                        (position('сут' in lower(load_interval)) > 0 AND now() - table_last_load <= interval '24 hours')
                     OR (position('час' in lower(load_interval)) > 0 AND now() - table_last_load <= interval '1 hour')
                    )
                   ) AS sla_ok
            FROM joined
        )
        SELECT 
            report,
            source_table,
            owner_report,
            load_update_table,
            load_update_report,
            load_interval,
            original_table_name,
            json_agg(json_build_object(
                'table_name', clean_table,
                'table_last_load', CASE 
                    WHEN table_last_load IS NOT NULL 
                    THEN to_char(table_last_load, 'YYYY-MM-DD HH24:MI:SS') 
                    ELSE NULL 
                END,
                'sla_ok', sla_ok
            )) AS tables_info
        FROM with_flags
        GROUP BY report, source_table, owner_report, load_update_table, load_update_report, load_interval, original_table_name
        ORDER BY report;
    """
    try:
        with engine.connect() as conn:
            result = conn.execute(text(query))
            rows = [dict(row._mapping) for row in result]

        for row in rows:
            for table in row["tables_info"]:
                try:
                    if not table.get("table_last_load"):
                        table["table_last_load"] = "Нет данных"
                    table["sla_ok"] = bool(table["sla_ok"])
                except Exception as inner_error:
                    print("Ошибка при обработке таблицы:", table)
                    print("Ошибка:", inner_error)
                    table["sla_ok"] = False
                    table["table_last_load"] = "Нет данных"
            row["sla_ok"] = all(t["sla_ok"] for t in row["tables_info"])

        return JSONResponse(content=rows)

    except Exception as e:
        print("🔥 Общая ошибка SLA-эндпоинта 🔥")
        print(e)
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/slowest-tables")
def get_slowest_tables(
    days: int = Query(30, ge=1, le=120),
    limit: int = Query(20, ge=1, le=200),
):
    try:
        query = f"""
            WITH base AS (
                SELECT
                    COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) AS table_schema,
                    COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_name,
                    e.entity_name,
                    EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration
                FROM {TABLE_LOADING_HISTORY} l
                LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'SUCCESS'
                  AND l.loading_start_dttm IS NOT NULL
                  AND l.loading_finish_dttm IS NOT NULL
                  AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
            )
            SELECT
                table_schema,
                table_name,
                entity_name,
                COUNT(*) AS runs_count,
                AVG(duration) AS avg_duration,
                percentile_cont(0.95) WITHIN GROUP (ORDER BY duration) AS p95_duration,
                MAX(duration) AS max_duration,
                STDDEV_SAMP(duration) AS stddev_duration
            FROM base
            GROUP BY table_schema, table_name, entity_name
        """
        with engine.connect() as conn:
            rows = conn.execute(text(query), {"days": days}).mappings().all()

        threshold_minutes = 10.0
        data = []
        for row in rows:
            r = dict(row)
            runs = int(r.get("runs_count") or 0)
            avg = float(r["avg_duration"]) if r.get("avg_duration") is not None else None
            p95 = float(r["p95_duration"]) if r.get("p95_duration") is not None else None
            max_d = float(r["max_duration"]) if r.get("max_duration") is not None else None
            std = float(r["stddev_duration"]) if r.get("stddev_duration") is not None else None

            cv = (std / avg) if (std is not None and avg) else None
            p95_ratio = (p95 / avg) if (p95 is not None and avg) else None

            slow = bool(p95 is not None and p95 > threshold_minutes)
            unstable = bool(cv is not None and cv >= 0.3)
            critical_unstable = bool(cv is not None and cv >= 0.6) or bool(
                p95_ratio is not None and p95_ratio > 2
            )
            low_sample = runs < 5

            if low_sample:
                status = "low_sample"
            elif slow and unstable:
                status = "slow_unstable"
            elif slow and not unstable:
                status = "slow"
            elif unstable:
                status = "unstable"
            else:
                status = "ok"

            if not (slow or unstable):
                continue

            data.append(
                {
                    "table_schema": r.get("table_schema") or "",
                    "table_name": r.get("table_name") or "",
                    "entity_name": r.get("entity_name"),
                    "runs_count": runs,
                    "avg_duration": round(avg, 2) if avg is not None else None,
                    "p95_duration": round(p95, 2) if p95 is not None else None,
                    "max_duration": round(max_d, 2) if max_d is not None else None,
                    "stddev_duration": round(std, 2) if std is not None else None,
                    "cv": round(cv, 4) if cv is not None else None,
                    "p95_avg_ratio": round(p95_ratio, 3) if p95_ratio is not None else None,
                    "slow": slow,
                    "unstable": unstable,
                    "critical_unstable": critical_unstable,
                    "low_sample": low_sample,
                    "status": status,
                }
            )

        status_order = {
            "slow_unstable": 0,
            "slow": 1,
            "unstable": 2,
            "low_sample": 3,
            "ok": 4,
        }
        data.sort(
            key=lambda x: (
                status_order.get(x["status"], 9),
                -(x.get("p95_duration") or 0),
            )
        )
        limited = data[:limit]

        now_dt = datetime.utcnow().date()
        period_from = now_dt - timedelta(days=days)
        payload = {
            "meta": {
                "window_days": days,
                "period_from": period_from.strftime("%Y-%m-%d"),
                "period_to": now_dt.strftime("%Y-%m-%d"),
                "total_tables": len(rows),
                "candidates": len(data),
                "limit": limit,
            },
            "rows": limited,
        }
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        print("❌ /api/slowest-tables error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/load-profile")
def get_load_profile(days: int = Query(30, ge=1, le=120)):
    try:
        query = f"""
            SELECT
                EXTRACT(HOUR FROM l.loading_start_dttm) AS hour,
                COUNT(*) AS runs_count,
                SUM(EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0) AS total_duration_minutes
            FROM {TABLE_LOADING_HISTORY} l
            WHERE l.object_type = 'table'
              AND l.loading_state = 'SUCCESS'
              AND l.loading_start_dttm IS NOT NULL
              AND l.loading_finish_dttm IS NOT NULL
              AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
            GROUP BY EXTRACT(HOUR FROM l.loading_start_dttm)
            ORDER BY hour
        """
        with engine.connect() as conn:
            rows = conn.execute(text(query), {"days": days}).mappings().all()

        profile_map = {int(r["hour"]): r for r in rows}
        profile = []
        for h in range(24):
            row = profile_map.get(h, {})
            runs = int(row.get("runs_count") or 0)
            total = float(row.get("total_duration_minutes") or 0.0)
            profile.append(
                {
                    "hour": h,
                    "runs_count": runs,
                    "total_duration_minutes": round(total, 2),
                }
            )

        return JSONResponse(
            content={"days": days, "profile": profile},
            media_type="application/json; charset=utf-8",
        )
    except Exception as e:
        print("❌ /api/load-profile error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/night-summary")
def get_night_summary(
    days: int = Query(30, ge=1, le=120),
    limit: int = Query(50, ge=1, le=200),
    start_hour: int = Query(21, ge=0, le=23),
    end_hour: int = Query(8, ge=0, le=23),
    shift_days: int = Query(0, ge=0, le=14),
):
    try:
        with engine.connect() as conn:
            window_row = conn.execute(
                text(
                    """
                    SELECT
                        (date_trunc('day', now()) - interval '1 day' + (:start_hour || ' hours')::interval - (:shift_days || ' days')::interval) AS start_ts,
                        (date_trunc('day', now()) + (:end_hour || ' hours')::interval - (:shift_days || ' days')::interval) AS end_ts
                    """
                ),
                {"start_hour": start_hour, "end_hour": end_hour, "shift_days": shift_days},
            ).mappings().first()

        start_ts = window_row["start_ts"]
        end_ts = window_row["end_ts"]

        base_cte = f"""
            WITH night_runs AS (
                SELECT
                    l.object_id AS table_id,
                    COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) AS table_schema,
                    COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_name,
                    e.entity_name,
                    l.loading_start_dttm,
                    l.loading_finish_dttm,
                    EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration,
                    EXTRACT(HOUR FROM l.loading_start_dttm) AS hour
                FROM {TABLE_LOADING_HISTORY} l
                LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'SUCCESS'
                  AND l.loading_start_dttm IS NOT NULL
                  AND l.loading_finish_dttm IS NOT NULL
                  AND l.loading_start_dttm >= :start_ts
                  AND l.loading_start_dttm < :end_ts
            )
        """
        failed_cte = f"""
            WITH failed_runs AS (
                SELECT
                    l.object_id AS table_id,
                    COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) AS table_schema,
                    COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_name,
                    e.entity_name,
                    l.loading_start_dttm,
                    l.loading_finish_dttm,
                    l.message
                FROM {TABLE_LOADING_HISTORY} l
                LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'FAILED'
                  AND l.loading_start_dttm IS NOT NULL
                  AND l.loading_start_dttm >= :start_ts
                  AND l.loading_start_dttm < :end_ts
            )
        """

        with engine.connect() as conn:
            summary = conn.execute(
                text(
                    base_cte
                    + """
                    SELECT
                        COUNT(*) AS runs_count,
                        COUNT(DISTINCT table_id) AS tables_count,
                        COUNT(DISTINCT entity_name) AS entities_count,
                        SUM(duration) AS total_duration_minutes,
                        MAX(duration) AS max_duration_minutes
                    FROM night_runs
                    """
                ),
                {"start_ts": start_ts, "end_ts": end_ts},
            ).mappings().first()

            hourly = conn.execute(
                text(
                    base_cte
                    + """
                    SELECT
                        hour,
                        COUNT(*) AS runs_count,
                        SUM(duration) AS total_duration_minutes
                    FROM night_runs
                    GROUP BY hour
                    ORDER BY hour
                    """
                ),
                {"start_ts": start_ts, "end_ts": end_ts},
            ).mappings().all()

            hourly_top = conn.execute(
                text(
                    base_cte
                    + """
                    SELECT hour, table_id, table_schema, table_name, entity_name, duration
                    FROM (
                        SELECT
                            hour,
                            table_id,
                            table_schema,
                            table_name,
                            entity_name,
                            duration,
                            ROW_NUMBER() OVER (PARTITION BY hour ORDER BY duration DESC) AS rn
                        FROM night_runs
                    ) ranked
                    WHERE rn <= :limit
                    ORDER BY hour, duration DESC
                    """
                ),
                {"start_ts": start_ts, "end_ts": end_ts, "limit": limit},
            ).mappings().all()

            top_runs = conn.execute(
                text(
                    base_cte
                    + """
                    SELECT
                        table_id,
                        table_schema,
                        table_name,
                        entity_name,
                        duration,
                        loading_start_dttm,
                        loading_finish_dttm
                    FROM night_runs
                    ORDER BY duration DESC
                    LIMIT :limit
                    """
                ),
                {"start_ts": start_ts, "end_ts": end_ts, "limit": limit},
            ).mappings().all()

            anomalies = conn.execute(
                text(
                    f"""
                    WITH history AS (
                        SELECT
                            l.object_id,
                            percentile_cont(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0) AS p95_duration
                        FROM {TABLE_LOADING_HISTORY} l
                        WHERE l.object_type = 'table'
                          AND l.loading_state = 'SUCCESS'
                          AND l.loading_start_dttm IS NOT NULL
                          AND l.loading_finish_dttm IS NOT NULL
                          AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
                        GROUP BY l.object_id
                    ),
                    night_runs AS (
                        SELECT
                            l.object_id AS table_id,
                            COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) AS table_schema,
                            COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_name,
                            e.entity_name,
                            l.loading_start_dttm,
                            l.loading_finish_dttm,
                            EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration
                        FROM {TABLE_LOADING_HISTORY} l
                        LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                        LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                        WHERE l.object_type = 'table'
                          AND l.loading_state = 'SUCCESS'
                          AND l.loading_start_dttm IS NOT NULL
                          AND l.loading_finish_dttm IS NOT NULL
                          AND l.loading_start_dttm >= :start_ts
                          AND l.loading_start_dttm < :end_ts
                    )
                    SELECT
                        n.table_id,
                        n.table_schema,
                        n.table_name,
                        n.entity_name,
                        n.duration,
                        n.loading_start_dttm,
                        n.loading_finish_dttm,
                        h.p95_duration,
                        CASE
                            WHEN h.p95_duration > 0 THEN n.duration / h.p95_duration
                            ELSE NULL
                        END AS ratio
                    FROM night_runs n
                    JOIN history h ON h.object_id = n.table_id
                    WHERE n.duration > h.p95_duration * 1.5
                    ORDER BY n.duration DESC
                    LIMIT :limit
                    """
                ),
                {
                    "days": days,
                    "start_ts": start_ts,
                    "end_ts": end_ts,
                    "limit": limit,
                },
            ).mappings().all()

            failed_summary = conn.execute(
                text(
                    failed_cte
                    + """
                    SELECT
                        COUNT(*) AS runs_count,
                        COUNT(DISTINCT table_id) AS tables_count,
                        COUNT(DISTINCT entity_name) AS entities_count
                    FROM failed_runs
                    """
                ),
                {"start_ts": start_ts, "end_ts": end_ts},
            ).mappings().first()

            failed_runs = conn.execute(
                text(
                    failed_cte
                    + """
                    SELECT
                        table_id,
                        table_schema,
                        table_name,
                        entity_name,
                        loading_start_dttm,
                        loading_finish_dttm,
                        message
                    FROM failed_runs
                    ORDER BY loading_finish_dttm DESC NULLS LAST
                    LIMIT :limit
                    """
                ),
                {"start_ts": start_ts, "end_ts": end_ts, "limit": limit},
            ).mappings().all()

        hourly_top_map = {}
        for row in hourly_top:
            hour = int(row["hour"])
            hourly_top_map.setdefault(hour, []).append(
                {
                    "table_id": row.get("table_id"),
                    "table_fqn": f"{row['table_schema']}.{row['table_name']}".strip("."),
                    "entity_name": row.get("entity_name"),
                    "duration_minutes": round(float(row["duration"]), 2) if row["duration"] is not None else None,
                }
            )

        hourly_payload = []
        for row in hourly:
            hour = int(row["hour"])
            total = float(row.get("total_duration_minutes") or 0.0)
            hourly_payload.append(
                {
                    "hour": hour,
                    "runs_count": int(row.get("runs_count") or 0),
                    "total_duration_minutes": round(total, 2),
                    "top_tables": hourly_top_map.get(hour, []),
                }
            )

        payload = {
            "window": {
                "start": serialize_datetime(start_ts),
                "end": serialize_datetime(end_ts),
                "start_hour": start_hour,
                "end_hour": end_hour,
            },
            "summary": {
                "runs_count": int(summary.get("runs_count") or 0),
                "tables_count": int(summary.get("tables_count") or 0),
                "entities_count": int(summary.get("entities_count") or 0),
                "total_duration_minutes": round(float(summary.get("total_duration_minutes") or 0.0), 2),
                "max_duration_minutes": round(float(summary.get("max_duration_minutes") or 0.0), 2)
                if summary.get("max_duration_minutes") is not None
                else None,
            },
            "failed_summary": {
                "runs_count": int(failed_summary.get("runs_count") or 0),
                "tables_count": int(failed_summary.get("tables_count") or 0),
                "entities_count": int(failed_summary.get("entities_count") or 0),
            },
            "hourly": hourly_payload,
            "top_runs": [
                {
                    "table_id": row.get("table_id"),
                    "table_fqn": f"{row['table_schema']}.{row['table_name']}".strip("."),
                    "entity_name": row.get("entity_name"),
                    "duration_minutes": round(float(row["duration"]), 2) if row["duration"] is not None else None,
                    "start": serialize_datetime(row.get("loading_start_dttm")),
                    "end": serialize_datetime(row.get("loading_finish_dttm")),
                }
                for row in top_runs
            ],
            "anomalies": [
                {
                    "table_id": row.get("table_id"),
                    "table_fqn": f"{row['table_schema']}.{row['table_name']}".strip("."),
                    "entity_name": row.get("entity_name"),
                    "duration_minutes": round(float(row["duration"]), 2) if row["duration"] is not None else None,
                    "p95_minutes": round(float(row["p95_duration"]), 2) if row["p95_duration"] is not None else None,
                    "ratio": round(float(row["ratio"]), 2) if row["ratio"] is not None else None,
                    "start": serialize_datetime(row.get("loading_start_dttm")),
                    "end": serialize_datetime(row.get("loading_finish_dttm")),
                }
                for row in anomalies
            ],
            "failed_runs": [
                {
                    "table_id": row.get("table_id"),
                    "table_fqn": f"{row['table_schema']}.{row['table_name']}".strip("."),
                    "entity_name": row.get("entity_name"),
                    "start": serialize_datetime(row.get("loading_start_dttm")),
                    "end": serialize_datetime(row.get("loading_finish_dttm")),
                    "message": row.get("message"),
                }
                for row in failed_runs
            ],
        }
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        print("❌ /api/night-summary error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


def _parse_hhmm_to_minutes(value: str, field_name: str) -> int:
    if not isinstance(value, str):
        raise HTTPException(status_code=400, detail=f"{field_name} must be a string in HH:MM format")
    match = re.fullmatch(r"([01]?\d|2[0-3]):([0-5]\d)", value.strip())
    if not match:
        raise HTTPException(status_code=400, detail=f"Invalid {field_name}: {value}. Expected HH:MM")
    hours = int(match.group(1))
    minutes = int(match.group(2))
    return hours * 60 + minutes


@router.get("/api/night/heavy-tables")
def get_night_heavy_tables(
    days: int = Query(30, ge=1, le=120),
    limit: int = Query(25, ge=1, le=200),
    window_start: str = Query("04:30"),
    window_end: str = Query("05:20"),
):
    try:
        start_minutes = _parse_hhmm_to_minutes(window_start, "window_start")
        end_minutes = _parse_hhmm_to_minutes(window_end, "window_end")
        crosses_midnight = start_minutes > end_minutes

        time_filter = """
            (
                (:crosses_midnight = false AND minute_of_day >= :start_minutes AND minute_of_day < :end_minutes)
                OR
                (:crosses_midnight = true AND (minute_of_day >= :start_minutes OR minute_of_day < :end_minutes))
            )
        """

        query = f"""
            WITH base AS (
                SELECT
                    l.object_id AS table_id,
                    COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) AS table_schema,
                    COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_name,
                    COALESCE(e.entity_name, 'UNKNOWN') AS entity_name,
                    l.loading_start_dttm,
                    l.loading_finish_dttm,
                    EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration_minutes,
                    (EXTRACT(HOUR FROM l.loading_start_dttm)::int * 60 + EXTRACT(MINUTE FROM l.loading_start_dttm)::int) AS minute_of_day
                FROM {TABLE_LOADING_HISTORY} l
                LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'SUCCESS'
                  AND l.loading_start_dttm IS NOT NULL
                  AND l.loading_finish_dttm IS NOT NULL
                  AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
            ),
            windowed AS (
                SELECT *
                FROM base
                WHERE {time_filter}
            )
            SELECT
                table_id,
                table_schema,
                table_name,
                entity_name,
                COUNT(*) AS runs_count,
                SUM(duration_minutes) AS total_duration_minutes,
                AVG(duration_minutes) AS avg_duration_minutes,
                MAX(duration_minutes) AS max_duration_minutes,
                MAX(loading_start_dttm) AS last_start
            FROM windowed
            GROUP BY table_id, table_schema, table_name, entity_name
            ORDER BY total_duration_minutes DESC NULLS LAST
            LIMIT :limit
        """

        summary_query = f"""
            WITH base AS (
                SELECT
                    l.object_id AS table_id,
                    (EXTRACT(HOUR FROM l.loading_start_dttm)::int * 60 + EXTRACT(MINUTE FROM l.loading_start_dttm)::int) AS minute_of_day,
                    EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration_minutes
                FROM {TABLE_LOADING_HISTORY} l
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'SUCCESS'
                  AND l.loading_start_dttm IS NOT NULL
                  AND l.loading_finish_dttm IS NOT NULL
                  AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
            ),
            windowed AS (
                SELECT *
                FROM base
                WHERE {time_filter}
            )
            SELECT
                COUNT(*) AS runs_count,
                COUNT(DISTINCT table_id) AS tables_count,
                SUM(duration_minutes) AS total_duration_minutes,
                AVG(duration_minutes) AS avg_duration_minutes,
                MAX(duration_minutes) AS max_duration_minutes
            FROM windowed
        """

        params = {
            "days": days,
            "limit": limit,
            "start_minutes": start_minutes,
            "end_minutes": end_minutes,
            "crosses_midnight": crosses_midnight,
        }

        with engine.connect() as conn:
            rows = conn.execute(text(query), params).mappings().all()
            summary = conn.execute(text(summary_query), params).mappings().first() or {}

        payload = {
            "window": {
                "start": window_start,
                "end": window_end,
                "start_minutes": start_minutes,
                "end_minutes": end_minutes,
                "crosses_midnight": crosses_midnight,
                "days": days,
            },
            "summary": {
                "runs_count": int(summary.get("runs_count") or 0),
                "tables_count": int(summary.get("tables_count") or 0),
                "total_duration_minutes": round(float(summary.get("total_duration_minutes") or 0.0), 2),
                "avg_duration_minutes": round(float(summary.get("avg_duration_minutes") or 0.0), 2),
                "max_duration_minutes": round(float(summary.get("max_duration_minutes") or 0.0), 2),
            },
            "rows": [
                {
                    "table_id": row.get("table_id"),
                    "table_fqn": f"{row.get('table_schema')}.{row.get('table_name')}".strip("."),
                    "table_schema": row.get("table_schema"),
                    "table_name": row.get("table_name"),
                    "entity_name": row.get("entity_name"),
                    "runs_count": int(row.get("runs_count") or 0),
                    "total_duration_minutes": round(float(row.get("total_duration_minutes") or 0.0), 2),
                    "avg_duration_minutes": round(float(row.get("avg_duration_minutes") or 0.0), 2),
                    "max_duration_minutes": round(float(row.get("max_duration_minutes") or 0.0), 2),
                    "last_start": serialize_datetime(row.get("last_start")),
                }
                for row in rows
            ],
        }
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except HTTPException:
        raise
    except Exception as e:
        print("❌ /api/night/heavy-tables error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/logic-audit")
def get_logic_audit(
    issue_type: str = Query("all"),
    mode: str = Query("standard"),
    min_score: float = Query(0.72, ge=0.0, le=1.0),
    limit: int = Query(200, ge=1, le=1000),
    search: Optional[str] = Query(None),
):
    payload = _build_logic_audit_cache()
    pairs = payload.get("pairs") or []

    if issue_type != "all":
        pairs = [row for row in pairs if row.get("issue_type") == issue_type]

    if min_score > 0:
        pairs = [row for row in pairs if (row.get("score") or 0) >= min_score]

    if mode == "strict":
        pairs = [
            row for row in pairs
            if (row.get("expression_overlap_count") or 0) >= 1
            and (row.get("score") or 0) >= max(min_score, 0.72)
        ]

    if search:
        term = search.strip().lower()
        if term:
            pairs = [
                row for row in pairs
                if term in (row.get("left_fqn") or "").lower()
                or term in (row.get("right_fqn") or "").lower()
                or term in (row.get("left_entity") or "").lower()
                or term in (row.get("right_entity") or "").lower()
            ]

    pairs = pairs[:limit]
    stats = {
        "duplicate_exact": sum(1 for row in pairs if row.get("issue_type") == "duplicate_exact"),
        "duplicate_candidate": sum(1 for row in pairs if row.get("issue_type") == "duplicate_candidate"),
        "similar_candidate": sum(1 for row in pairs if row.get("issue_type") == "similar_candidate"),
    }
    return {
        "generated_at": payload.get("generated_at"),
        "objects_count": payload.get("objects_count"),
        "pairs_count": payload.get("pairs_count"),
        "mode": mode,
        "returned_count": len(pairs),
        "stats": stats,
        "pairs": pairs,
    }


@router.get("/api/logic-audit/pair/{pair_id}")
def get_logic_audit_pair(pair_id: str):
    payload = _build_logic_audit_cache()
    detail = (payload.get("pair_index") or {}).get(pair_id)
    if not detail:
        return JSONResponse(status_code=404, content={"error": "pair not found"})
    return detail


@router.get("/api/entity-loads")
def get_entity_loads(
    entity_id: int = Query(..., ge=1),
    days: int = Query(30, ge=1, le=120),
    limit: int = Query(30, ge=1, le=200),
    schema: Optional[str] = Query(None),
):
    try:
        schema = schema.strip() if isinstance(schema, str) else None
        query = f"""
            WITH base AS (
                SELECT
                    COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) AS table_schema,
                    COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_name,
                    e.entity_name,
                    EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration,
                    l.loading_finish_dttm
                FROM {TABLE_LOADING_HISTORY} l
                LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'SUCCESS'
                  AND l.loading_start_dttm IS NOT NULL
                  AND l.loading_finish_dttm IS NOT NULL
                  AND e.entity_id = :entity_id
                  AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
                  AND (
                    :schema IS NULL OR
                    LOWER(COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), ''))) = LOWER(:schema)
                  )
            )
            SELECT
                table_schema,
                table_name,
                entity_name,
                COUNT(*) AS runs_count,
                AVG(duration) AS avg_duration,
                percentile_cont(0.95) WITHIN GROUP (ORDER BY duration) AS p95_duration,
                MAX(duration) AS max_duration,
                MAX(loading_finish_dttm) AS last_finish
            FROM base
            GROUP BY table_schema, table_name, entity_name
            ORDER BY MAX(duration) DESC NULLS LAST
            LIMIT :limit
        """
        with engine.connect() as conn:
            rows = conn.execute(
                text(query),
                {"entity_id": entity_id, "days": days, "limit": limit, "schema": schema},
            ).mappings().all()

        payload = [
            {
                "table_fqn": f"{row['table_schema']}.{row['table_name']}".strip("."),
                "entity_name": row.get("entity_name"),
                "runs_count": int(row.get("runs_count") or 0),
                "avg_duration": round(float(row["avg_duration"]), 2) if row.get("avg_duration") is not None else None,
                "p95_duration": round(float(row["p95_duration"]), 2) if row.get("p95_duration") is not None else None,
                "max_duration": round(float(row["max_duration"]), 2) if row.get("max_duration") is not None else None,
                "last_finish": serialize_datetime(row.get("last_finish")),
            }
            for row in rows
        ]
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        print("❌ /api/entity-loads error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


def load_all_meta():
    all_meta = {}
    for top_path in iter_meta_dirs():
        for schema_dir in top_path.iterdir():
            if not schema_dir.is_dir():
                continue
            for table_dir in schema_dir.iterdir():
                yaml_path = table_dir / "meta_data_file.yaml"
                if yaml_path.exists():
                    try:
                        with open(yaml_path, encoding="utf-8") as f:
                            meta = yaml.safe_load(f)
                            key = f"{meta['table_schema']}.{meta['table_name']}"
                            all_meta[key] = meta
                    except Exception:
                        continue
    return all_meta


def get_downstream_dependencies(start_table: str, all_meta: dict):
    result = set()
    stack = [start_table]

    while stack:
        current = stack.pop()
        if current in all_meta:
            deps = all_meta[current].get("depends_on", {})
            for schema, tables in deps.items():
                for table in tables:
                    full_name = f"{schema}.{table}"
                    if full_name not in result:
                        result.add(full_name)
                        stack.append(full_name)

    return sorted(result)


def get_dependency_edges(start_table: str, all_meta: dict) -> List[Dict[str, str]]:
    edges = []
    visited = set()
    stack = [start_table]

    while stack:
        current = stack.pop()
        if current in visited:
            continue
        visited.add(current)

        meta = all_meta.get(current)
        if not meta:
            continue

        depends_on = meta.get("depends_on", {})
        for source_schema, tables in depends_on.items():
            for source_table in tables:
                source = f"{source_schema}.{source_table}"
                edges.append({"source": source, "target": current})
                stack.append(source)

    return edges


@router.get("/api/dependencies-down/{schema}/{table:path}")
def get_dependencies_down(schema: str, table: str):
    key = f"{schema}.{table}"
    try:
        all_meta = load_all_meta()
        if key not in all_meta:
            return JSONResponse(status_code=404, content={"error": "table not found"})

        edges = get_dependency_edges(key, all_meta)
        return {"central_node": key, "edges": edges}

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/dependencies-graph/{schema}/{table:path}")
def get_dependency_graph(
    schema: str,
    table: str,
    max_depth: Optional[int] = Query(None, ge=1),
    max_edges: Optional[int] = Query(None, ge=1),
):
    try:
        schema_norm = norm(schema)
        table_norm = norm(table)
        key = f"{schema_norm}.{table_norm}"
        now = time.time()

        all_meta_list, _ = get_cached_meta_and_index()
        if _graph_cache_meta_ts != _cache_timestamp:
            _graph_cache.clear()
            globals()["_graph_cache_meta_ts"] = _cache_timestamp
            globals()["_graph_cache_ts"] = now

        cache_key = (key, max_depth, max_edges)
        if _graph_cache and now - _graph_cache_ts < _GRAPH_CACHE_TTL:
            cached = _graph_cache.get(cache_key)
            if cached is not None:
                return cached

        all_meta = {
            f"{m.get('table_schema')}.{m.get('table_name')}": m
            for m in all_meta_list
            if m.get("table_schema") and m.get("table_name")
        }
        reverse_index = {}
        for m in all_meta_list:
            consumer = (m.get("table_schema"), m.get("table_name"))
            for src_schema, tables in (m.get("depends_on") or {}).items():
                for src_table in tables or []:
                    reverse_index.setdefault((src_schema, src_table), []).append({
                        "schema": consumer[0],
                        "table_name": consumer[1],
                    })
        visited = set()
        edges_set = set()
        truncated = False

        stack = [(key, 0)]
        while stack:
            current, depth = stack.pop()
            if current in visited:
                continue
            visited.add(current)

            meta = all_meta.get(current)
            if not meta:
                continue
            if max_depth is not None and depth >= max_depth:
                schema_val, table_val = current.split(".", 1)
                if meta.get("depends_on") or reverse_index.get((schema_val, table_val)):
                    truncated = True
                continue

            depends_on = meta.get("depends_on") or {}
            for source_schema, source_tables in depends_on.items():
                if not source_schema:
                    continue
                for source_table in source_tables or []:
                    if not source_table:
                        continue
                    source = f"{source_schema}.{source_table}"
                    edge_key = (source, current)
                    if edge_key not in edges_set:
                        edges_set.add(edge_key)
                        if max_edges is not None and len(edges_set) >= max_edges:
                            truncated = True
                            stack = []
                            break
                    stack.append((source, depth + 1))
                if truncated:
                    break
            if truncated:
                break

            schema_val, table_val = current.split(".", 1)
            for consumer in reverse_index.get((schema_val, table_val), []):
                if not consumer.get("schema") or not consumer.get("table_name"):
                    continue
                target = f"{consumer['schema']}.{consumer['table_name']}"
                edge_key = (current, target)
                if edge_key not in edges_set:
                    edges_set.add(edge_key)
                    if max_edges is not None and len(edges_set) >= max_edges:
                        truncated = True
                        stack = []
                        break
                stack.append((target, depth + 1))
            if truncated:
                break

        edges = [{"source": s, "target": t} for s, t in edges_set]
        payload = {"centralNode": key, "edges": edges, "truncated": truncated}

        if now - _graph_cache_ts >= _GRAPH_CACHE_TTL:
            _graph_cache.clear()
            globals()["_graph_cache_ts"] = now
        _graph_cache[cache_key] = payload
        return payload

    except Exception as e:
        print("Ошибка при построении графа зависимостей:", e)
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/dependencies-nodes/{schema}/{table:path}")
def get_dependency_nodes(
    schema: str,
    table: str,
    max_depth: Optional[int] = Query(None, ge=1),
    max_nodes: Optional[int] = Query(None, ge=1),
):
    try:
        schema_norm = norm(schema)
        table_norm = norm(table)
        key = f"{schema_norm}.{table_norm}"

        all_meta_list, _ = get_cached_meta_and_index()
        all_meta = {
            f"{m.get('table_schema')}.{m.get('table_name')}": m
            for m in all_meta_list
            if m.get("table_schema") and m.get("table_name")
        }
        reverse_index = {}
        for m in all_meta_list:
            consumer = (m.get("table_schema"), m.get("table_name"))
            for src_schema, tables in (m.get("depends_on") or {}).items():
                for src_table in tables or []:
                    reverse_index.setdefault((src_schema, src_table), []).append({
                        "schema": consumer[0],
                        "table_name": consumer[1],
                    })

        visited = set()
        truncated = False
        stack = [(key, 0)]

        while stack:
            current, depth = stack.pop()
            if current in visited:
                continue
            visited.add(current)
            if max_nodes is not None and len(visited) >= max_nodes:
                truncated = True
                break

            meta = all_meta.get(current)
            if not meta:
                continue
            if max_depth is not None and depth >= max_depth:
                schema_val, table_val = current.split(".", 1)
                if meta.get("depends_on") or reverse_index.get((schema_val, table_val)):
                    truncated = True
                continue

            depends_on = meta.get("depends_on") or {}
            for source_schema, source_tables in depends_on.items():
                if not source_schema:
                    continue
                for source_table in source_tables or []:
                    if not source_table:
                        continue
                    source = f"{source_schema}.{source_table}"
                    stack.append((source, depth + 1))

            schema_val, table_val = current.split(".", 1)
            for consumer in reverse_index.get((schema_val, table_val), []):
                if not consumer.get("schema") or not consumer.get("table_name"):
                    continue
                target = f"{consumer['schema']}.{consumer['table_name']}"
                stack.append((target, depth + 1))

        nodes = sorted(visited, key=lambda v: v.lower())
        return {"centralNode": key, "nodes": nodes, "truncated": truncated}
    except Exception as e:
        print("Ошибка при построении списка зависимостей:", e)
        return JSONResponse(status_code=500, content={"error": str(e)})





@router.get("/api/gantt/{schema}/{table:path}")
def get_gantt_data(schema: str, table: str, depth: int = Query(3, ge=1, le=4)):
    try:
        snapshot = get_graph_snapshot()
        table_nodes = snapshot["table_graph"]["nodes"]
        table_edges = snapshot["table_graph"]["edges"]

        schema_norm = norm(schema)
        table_norm = norm(table)
        start_table = f"{schema_norm}.{table_norm}"
        if start_table not in table_nodes:
            return JSONResponse(status_code=404, content={"error": f"'{start_table}' not found in meta"})

        reverse = {}
        for edge in table_edges:
            reverse.setdefault(edge["target"], []).append(edge["source"])

        visited = {start_table}
        queue = deque([(start_table, 0)])
        while queue:
            node, d = queue.popleft()
            if d >= depth:
                continue
            for src in reverse.get(node, []):
                if src in visited:
                    continue
                visited.add(src)
                queue.append((src, d + 1))

        edges = [e for e in table_edges if e["source"] in visited and e["target"] in visited]
        table_to_id = {
            t: table_nodes[t]["table_id"]
            for t in visited
            if t in table_nodes and table_nodes[t].get("table_id")
        }

        if not table_to_id:
            return JSONResponse(content=[], media_type="application/json")

        id_list = list(table_to_id.values())

        query = (
            text(
                f"""
            WITH cte AS (
                SELECT object_id, loading_start_dttm, loading_finish_dttm,
                       row_number() OVER (PARTITION BY object_id ORDER BY loading_start_dttm DESC) rn
                FROM {TABLE_LOADING_HISTORY}
                WHERE loading_state = 'SUCCESS' AND object_type = 'table'
                  AND object_id IN :id_list
            )
            SELECT object_id, loading_start_dttm, loading_finish_dttm
            FROM cte
            WHERE rn = 1
            ORDER BY loading_start_dttm
        """
            )
            .bindparams(bindparam("id_list", expanding=True))
        )

        with engine.connect() as conn:
            rows = conn.execute(query, {"id_list": id_list}).mappings().all()

        loading_times = {
            row["object_id"]: {"start": row["loading_start_dttm"], "end": row["loading_finish_dttm"]} for row in rows
        }

        id_to_table = {v: k for k, v in table_to_id.items()}
        bad_tables = set()

        for edge in edges:
            src = edge["source"]
            tgt = edge["target"]
            src_id = table_to_id.get(src)
            tgt_id = table_to_id.get(tgt)
            if src_id and tgt_id:
                src_end = loading_times.get(src_id, {}).get("end")
                tgt_start = loading_times.get(tgt_id, {}).get("start")
                if src_end and tgt_start and src_end > tgt_start:
                    bad_tables.add(tgt)

        result = []
        for row in rows:
            table_name = id_to_table.get(row["object_id"], str(row["object_id"]))
            result.append(
                {
                    "table_id": row["object_id"],
                    "table_name": table_name,
                    "start": row["loading_start_dttm"].strftime("%Y-%m-%d %H:%M:%S") if row["loading_start_dttm"] else None,
                    "end": row["loading_finish_dttm"].strftime("%Y-%m-%d %H:%M:%S") if row["loading_finish_dttm"] else None,
                    "is_bad": table_name in bad_tables,
                }
            )

        return JSONResponse(content=result, media_type="application/json")

    except Exception as e:
        print("❌ Ошибка при построении Gantt:", str(e))
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/entities/{entity_id}/table-info")
def get_entity_table_info(entity_id: int):
    """
    Возвращает информацию по таблице из tech_etl.tables_meta для конкретной сущности.
    Поля: schema_name, tables_name, last_load, entity_name
    """
    sql = f"""
        SELECT
            table_schema,
            table_name,
            table_last_load,
            entity_name
        FROM {TABLE_TABLES_META}
        WHERE entity_id = :entity_id order by table_last_load
    """
    try:
        with engine.connect() as conn:
            rows = conn.execute(text(sql), {"entity_id": entity_id}).mappings().all()
            cleaned = []
            for r in rows:
                row = dict(r)
                row["table_schema"] = row["table_schema"]
                row["table_last_load"] = (
                    row["table_last_load"].strftime("%Y-%m-%d %H:%M:%S") if row["table_last_load"] else None
                )
                row["table_name"] = row["table_name"]
                row["entity_name"] = row["entity_name"]
                cleaned.append(row)

            return JSONResponse(content=cleaned, media_type="application/json; charset=utf-8")

    except Exception as e:
        print("❌ Ошибка при получении данных об ошибках:", str(e))
        return JSONResponse(status_code=500, content={"error": str(e)})





def get_table_id_by_fqn(conn, schema: str, table: str):
    q = text(
        f"""
        SELECT table_id
        FROM {TABLE_TABLES_META}
        WHERE table_schema = :schema
          AND table_name   = :table
        LIMIT 1
    """
    )
    return conn.execute(q, {"schema": schema, "table": table}).scalar()


def build_impact(table_fqn: str, deps: list, sla_resp):
    """
    Строит impact для инцидента:
    - затронутые сущности
    - количество downstream-таблиц
    - отчёты под риском
    - SLA-нарушения
    """

    affected_entities = set()
    blocked_tables = set()
    reports_at_risk = []
    sla_violations = 0

    # --- downstream tables ---
    for d in deps or []:
        schema = d.get("schema")
        table = d.get("table_name") or d.get("table")
        entity = d.get("entity_name")

        if schema and table:
            blocked_tables.add(f"{schema}.{table}")

        if entity:
            affected_entities.add(entity)

    # --- SLA ---
    try:
        if hasattr(sla_resp, "body"):
            sla_rows = json.loads(sla_resp.body.decode("utf-8"))
        else:
            sla_rows = sla_resp or []
    except Exception:
        sla_rows = []

    for row in sla_rows:
        tables = row.get("tables_info", [])
        for t in tables:
            if not t.get("sla_ok", True):
                sla_violations += 1
                reports_at_risk.append(row.get("report"))
                break

    return {
        "affected_entities": sorted(affected_entities),
        "blocked_tables_count": len(blocked_tables),
        "reports_at_risk": sorted(set(reports_at_risk)),
        "sla_violations": sla_violations,
    }

@router.get("/api/incident")
def get_incident(table_fqn: str = Query(...)):
    try:
        schema, table = table_fqn.split(".")
    except ValueError:
        return JSONResponse(status_code=400, content={"error": "schema.table expected"})

    with engine.connect() as conn:
        table_id = conn.execute(
            text(f"""
                SELECT table_id FROM {TABLE_TABLES_META}
                WHERE table_schema=:s AND table_name=:t
            """),
            {"s": schema, "t": table}
        ).scalar()

        if not table_id:
            return JSONResponse(status_code=404, content={"error": "table not found"})

        deps = [d.dict() for d in resolve_dependencies(schema, table)]

        rows = conn.execute(
            text(f"""
                SELECT loading_start_dttm, loading_finish_dttm, loading_state, message,
                       extract(epoch from (loading_finish_dttm-loading_start_dttm)) dur
                FROM {TABLE_LOADING_HISTORY}
                WHERE object_id=:id
                ORDER BY loading_finish_dttm DESC
                LIMIT 15
            """),
            {"id": table_id}
        ).mappings().all()

    timeline = [{
        "start": r["loading_start_dttm"].strftime("%Y-%m-%d %H:%M:%S"),
        "finish": r["loading_finish_dttm"].strftime("%Y-%m-%d %H:%M:%S"),
        "state": r["loading_state"],
        "duration_sec": float(r["dur"]) if r["dur"] else None,
        "message": (r["message"] or "") or None
    } for r in rows]

    return {
        "summary": {
            "table_fqn": table_fqn,
            "state": "FAILING" if timeline and timeline[0]["state"] == "FAILED" else "RECOVERED",
        },
        "timeline": timeline,
        "dependencies": deps,
        "impact": {
            "blocked_tables_count": len(deps),
            "affected_entities": sorted({d["entity_name"] for d in deps if d.get("entity_name")}),
        }
    }


from collections import defaultdict
from datetime import timedelta

INCIDENT_WINDOW_MIN = 60  # минут


def group_failures(failures: list):
    incidents = []
    failures_sorted = sorted(
        [f for f in failures if f.get("error_time")],
        key=lambda x: x["error_time"],
        reverse=True
    )

    used = set()

    for i, f in enumerate(failures_sorted):
        if i in used:
            continue

        entity = f.get("entity_name")

        if not entity:
            all_meta, _ = get_cached_meta_and_index()
            meta = next(
                (m for m in all_meta if m["table_schema"] == f["schema"] and m["table_name"] == f["table_name"]),
                None,
            )
            entity = meta.get("entity_name") if meta else None

        entity = entity or f"{f['schema']}"
        f["entity_name"] = entity  #

        try:
            t0 = datetime.strptime(f["error_time"], "%Y-%m-%d %H:%M:%S")
        except Exception:
            continue

        group = [f]
        used.add(i)

        for j, other in enumerate(failures_sorted[i + 1 :], start=i + 1):
            if j in used:
                continue

            other_entity = other.get("entity_name")

            if not other_entity:
                all_meta, _ = get_cached_meta_and_index()
                meta = next(
                    (
                        m
                        for m in all_meta
                        if m["table_schema"] == other["schema"] and m["table_name"] == other["table_name"]
                    ),
                    None,
                )
                other_entity = meta.get("entity_name") if meta else None
                other_entity = other_entity or f"{other['schema']}"
                other["entity_name"] = other_entity

            if other_entity != entity:
                continue

            t1 = datetime.strptime(other["error_time"], "%Y-%m-%d %H:%M:%S")

            if abs((t0 - t1).total_seconds()) <= INCIDENT_WINDOW_MIN * 60:
                group.append(other)
                used.add(j)

        incidents.append(group)

    return incidents


from collections import defaultdict


@router.get("/api/incidents/active")
def get_active_incidents():
    query = f"""
        WITH latest AS (
            SELECT
                l.object_id,
                MAX(l.loading_finish_dttm) AS last_event_time
            FROM {TABLE_LOADING_HISTORY} l
            WHERE l.object_type = 'table'
            GROUP BY l.object_id
        ),
        last_state AS (
            SELECT
                l.object_id,
                l.loading_state,
                l.loading_finish_dttm
            FROM {TABLE_LOADING_HISTORY} l
            JOIN latest t
              ON t.object_id = l.object_id
             AND t.last_event_time = l.loading_finish_dttm
            WHERE l.object_type = 'table'
        )
        SELECT
            t.table_schema AS schema,
            t.table_name,
            e.entity_name,
            l.loading_finish_dttm AS error_time
        FROM last_state l
        JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
        LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
        WHERE l.loading_state = 'FAILED'
        ORDER BY l.loading_finish_dttm DESC
    """

    try:
        with engine.connect() as conn:
            rows = conn.execute(text(query)).mappings().all()

        failures = []
        for r in rows:
            row = dict(r)
            row["error_time"] = serialize_datetime(row.get("error_time"))
            failures.append(row)

        if not failures:
            return []

        grouped = group_failures(failures)
        by_entity = defaultdict(list)

        for group in grouped:
            if not group:
                continue
            entity = group[0].get("entity_name") or "UNKNOWN"
            by_entity[entity].extend(group)

        incidents = []
        for entity, group_rows in by_entity.items():
            failed_tables = set()
            last_failure = None
            for r in group_rows:
                table_fqn = f"{r['schema']}.{r['table_name']}"
                failed_tables.add(table_fqn)
                if not last_failure or r["error_time"] > last_failure:
                    last_failure = r["error_time"]

            incidents.append(
                {
                    "entity": entity,
                    "severity": "CRITICAL",
                    "failed_tables": len(failed_tables),
                    "root_tables": sorted(failed_tables)[:3],
                    "last_failure_time": last_failure,
                }
            )

        incidents.sort(key=lambda x: x["last_failure_time"], reverse=True)
        return incidents
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/incidents/history")
def get_incident_history(
    days: int = Query(300, ge=1, le=3650),
    limit: int = Query(10, ge=1, le=100),
):
    query = f"""
        SELECT
            COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) || '.' ||
            COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_fqn,
            COUNT(*) AS incidents_count,
            MAX(l.loading_finish_dttm) AS last_incident
     FROM {TABLE_LOADING_HISTORY} l
      left join {TABLE_TABLES_META} t on t.table_id=l.object_id
        WHERE l.loading_state = 'FAILED'
          AND l.object_type = 'table'
          AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
        GROUP BY
            COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')),
            COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name)
        ORDER BY incidents_count DESC
        LIMIT :limit
    """
    with engine.connect() as conn:
        rows = conn.execute(text(query), {"days": days, "limit": limit}).mappings().all()

    return [
        {
            "table": r["table_fqn"],
            "count": r["incidents_count"],
            "last_incident": r["last_incident"].strftime("%Y-%m-%d %H:%M:%S")
            if r["last_incident"] else None
        }
        for r in rows
    ]


@router.get("/api/incidents/timeline")
def get_incident_timeline(days: int = Query(7, ge=1, le=365)):
    query = f"""
        SELECT
            date_trunc('day', l.loading_finish_dttm) AS day,
            COUNT(*) AS incidents_count
        FROM {TABLE_LOADING_HISTORY} l
        WHERE l.loading_state = 'FAILED'
          AND l.object_type = 'table'
          AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
        GROUP BY date_trunc('day', l.loading_finish_dttm)
        ORDER BY day
    """
    with engine.connect() as conn:
        rows = conn.execute(text(query), {"days": days}).mappings().all()

    return [
        {
            "day": row["day"].strftime("%Y-%m-%d"),
            "count": int(row["incidents_count"] or 0),
        }
        for row in rows
        if row.get("day")
    ]
print("Reg")
@router.get("/api/orderbreaches")
def get_order_breaches():
    return get_cached_order_breaches()


@router.get("/api/click/summary")
def get_clickhouse_summary(
    days: int = Query(7, ge=1, le=365),
    limit: int = Query(8, ge=1, le=50),
):
    try:
        with engine.connect() as conn:
            summary_row = conn.execute(
                text(
                    _clickhouse_run_agg_cte(
                        run_filter_sql="AND r.start_dttm >= now() - (:days || ' days')::interval"
                    )
                    + """
                    SELECT
                        COUNT(*) AS total_runs,
                        COUNT(DISTINCT schema_name || '.' || table_name) AS total_tables,
                        COUNT(DISTINCT CASE WHEN status = 'SUCCESS' THEN schema_name || '.' || table_name END) AS ok_tables,
                        SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS ok_runs,
                        SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed_runs,
                        SUM(CASE WHEN status = 'RUNNING' THEN 1 ELSE 0 END) AS running_runs,
                        SUM(CASE WHEN status = 'UP_FOR_RETRY' THEN 1 ELSE 0 END) AS retry_runs,
                        AVG(actual_duration_seconds) AS avg_actual_seconds,
                        MAX(actual_duration_seconds) AS max_actual_seconds,
                        AVG(GREATEST(elapsed_duration_seconds - actual_duration_seconds, 0)) AS avg_lag_seconds,
                        MAX(GREATEST(elapsed_duration_seconds - actual_duration_seconds, 0)) AS max_lag_seconds,
                        MAX(end_dttm) AS last_finish
                    FROM run_agg
                    """
                ),
                {"days": days},
            ).mappings().first() or {}

            failures = conn.execute(
                text(
                    _clickhouse_run_agg_cte(
                        run_filter_sql="AND r.start_dttm >= now() - (:days || ' days')::interval"
                    )
                    + f""",
                    last_stage AS (
                        SELECT DISTINCT ON (s.run_uuid, s.table_name)
                            s.run_uuid,
                            s.table_name,
                            s.stage_name,
                            s.status AS stage_status,
                            s.error_text AS stage_error
                        FROM {TABLE_CLICK_LOAD_STAGE} s
                        WHERE s.stage_name IN ('UPLOAD_TO_S3', 'CLICKHOUSE_LOAD')
                        ORDER BY s.run_uuid, s.table_name, s.start_dttm DESC NULLS LAST
                    )
                    SELECT
                        r.run_uuid,
                        r.schema_name,
                        r.table_name,
                        r.dag_name,
                        r.dag_run,
                        r.start_dttm,
                        r.end_dttm,
                        r.actual_duration_seconds,
                        r.elapsed_duration_seconds,
                        r.status,
                        r.error_text,
                        st.stage_name,
                        st.stage_status,
                        st.stage_error
                    FROM run_agg r
                    LEFT JOIN last_stage st
                      ON st.run_uuid = r.run_uuid
                     AND st.table_name = r.table_name
                    WHERE r.status IN ('FAILED', 'UP_FOR_RETRY')
                    ORDER BY r.start_dttm DESC
                    LIMIT :limit
                    """
                ),
                {"days": days, "limit": limit},
            ).mappings().all()

        summary = {
            "total_runs": int(summary_row.get("total_runs") or 0),
            "total_tables": int(summary_row.get("total_tables") or 0),
            "ok_tables": int(summary_row.get("ok_tables") or 0),
            "ok_runs": int(summary_row.get("ok_runs") or 0),
            "failed_runs": int(summary_row.get("failed_runs") or 0),
            "running_runs": int(summary_row.get("running_runs") or 0),
            "retry_runs": int(summary_row.get("retry_runs") or 0),
            "avg_duration_min": _round_minutes((summary_row.get("avg_actual_seconds") or 0) / 60.0)
            if summary_row.get("avg_actual_seconds") is not None
            else None,
            "max_duration_min": _round_minutes((summary_row.get("max_actual_seconds") or 0) / 60.0)
            if summary_row.get("max_actual_seconds") is not None
            else None,
            "avg_lag_min": _round_minutes((summary_row.get("avg_lag_seconds") or 0) / 60.0)
            if summary_row.get("avg_lag_seconds") is not None
            else None,
            "max_lag_min": _round_minutes((summary_row.get("max_lag_seconds") or 0) / 60.0)
            if summary_row.get("max_lag_seconds") is not None
            else None,
            "last_finish": serialize_datetime(summary_row.get("last_finish")),
        }

        failure_rows = []
        for row in failures:
            stage_name = row.get("stage_name")
            stage_label = None
            if stage_name == "UPLOAD_TO_S3":
                stage_label = "S3"
            elif stage_name == "CLICKHOUSE_LOAD":
                stage_label = "ClickHouse"

            failure_rows.append(
                {
                    "run_uuid": row.get("run_uuid"),
                    "schema_name": row.get("schema_name"),
                    "table_name": row.get("table_name"),
                    "dag_name": row.get("dag_name"),
                    "dag_run": row.get("dag_run"),
                    "start_dttm": serialize_datetime(row.get("start_dttm")),
                    "end_dttm": serialize_datetime(row.get("end_dttm")),
                    "status": row.get("status"),
                    "error_text": row.get("error_text"),
                    "stage_name": stage_name,
                    "stage_status": row.get("stage_status"),
                    "stage_error": row.get("stage_error"),
                    "problem_area": stage_label,
                    **_clickhouse_run_metrics(row),
                }
            )

        return {"summary": summary, "failures": failure_rows}
    except Exception as e:
        print("❌ /api/click/summary error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/click/table/{schema}/{table:path}")
def get_clickhouse_table_runs(
    schema: str,
    table: str,
    table_id: Optional[int] = None,
    limit: int = Query(6, ge=1, le=50),
):
    try:
        schema_norm = (schema or "").strip()
        table_norm = (table or "").strip()
        table_clean = _clean_table_name(norm(table))
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    _clickhouse_run_agg_cte(
                        run_filter_sql="AND r.schema_name = :schema",
                        stage_filter_sql="""
                          AND (lower(s.table_name) = lower(:table) OR lower(s.table_name) = lower(:table_clean))
                          AND (:table_id IS NULL OR s.table_id = :table_id)
                        """,
                    )
                    + """
                    SELECT *
                    FROM run_agg
                    ORDER BY start_dttm DESC
                    LIMIT :limit
                    """
                ),
                {"schema": schema_norm, "table": table_norm, "table_clean": table_clean, "table_id": table_id, "limit": limit},
            ).mappings().all()

            runs = [
                {
                    "run_uuid": row.get("run_uuid"),
                    "dag_name": row.get("dag_name"),
                    "dag_run": row.get("dag_run"),
                    "start_dttm": serialize_datetime(row.get("start_dttm")),
                    "end_dttm": serialize_datetime(row.get("end_dttm")),
                    "status": row.get("status"),
                    "error_text": row.get("error_text"),
                    **_clickhouse_run_metrics(row),
                }
                for row in rows
            ]

            stages = []
            if runs:
                run_uuid = runs[0].get("run_uuid")
                stages_rows = conn.execute(
                    text(
                        f"""
                        SELECT
                            table_id,
                            table_name,
                            stage_name,
                            start_dttm,
                            end_dttm,
                            duration,
                            status,
                            error_text
                        FROM {TABLE_CLICK_LOAD_STAGE}
                        WHERE run_uuid = :run_uuid
                          AND (lower(table_name) = lower(:table_name) OR lower(table_name) = lower(:table_name_clean))
                          AND stage_name IN ('UPLOAD_TO_S3', 'CLICKHOUSE_LOAD')
                        ORDER BY start_dttm
                        """
                    ),
                    {"run_uuid": run_uuid, "table_name": table_norm, "table_name_clean": table_clean},
                ).mappings().all()
                stages = [
                    {
                        "table_id": row.get("table_id"),
                        "table_name": row.get("table_name"),
                        "stage_name": row.get("stage_name"),
                        "start_dttm": serialize_datetime(row.get("start_dttm")),
                        "end_dttm": serialize_datetime(row.get("end_dttm")),
                        "duration_min": _duration_minutes(row.get("duration")),
                        "status": row.get("status"),
                        "error_text": row.get("error_text"),
                    }
                    for row in stages_rows
                ]

        return {"runs": runs, "stages": stages}
    except Exception as e:
        print("❌ /api/click/table error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/click/meta/{schema}/{table:path}")
def get_clickhouse_meta(schema: str, table: str):
    try:
        schema_norm = (schema or "").strip().lower()
        table_norm = (table or "").strip().lower()
        table_clean = _clean_table_name(table_norm)
        idx = get_click_meta_index()
        meta = idx["meta"].get((schema_norm, table_norm)) or idx["meta"].get((schema_norm, table_clean))
        view_sql = idx["view_sql"].get((schema_norm, table_norm)) or idx["view_sql"].get((schema_norm, table_clean))
        if not meta and not view_sql:
            return JSONResponse(status_code=404, content={"error": "not found"})
        return {
            "meta": meta,
            "view_sql": view_sql,
            "meta_root": idx.get("root"),
        }
    except Exception as e:
        print("❌ /api/click/meta error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/click/view/search")
def search_clickhouse_view(schema: str, table: str, limit: int = Query(10, ge=1, le=50)):
    try:
        schema_norm = (schema or "").strip().lower()
        table_norm = _clean_table_name((table or "").strip().lower())
        idx = get_click_meta_index()
        matches = idx.get("view_refs", {}).get((schema_norm, table_norm), [])

        # also match by view name
        name_key = ("dm_view", table_norm)
        if name_key in idx.get("view_sql", {}):
            matches = matches + [{"view_schema": "dm_view", "view_name": table_norm, "reason": "name_match"}]

        # de-dup
        seen = set()
        uniq = []
        for item in matches:
            key = (item.get("view_schema"), item.get("view_name"))
            if key in seen:
                continue
            seen.add(key)
            uniq.append(item)
            if len(uniq) >= limit:
                break
        return {"matches": uniq}
    except Exception as e:
        print("❌ /api/click/view/search error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/click/history/{schema}/{table:path}")
def get_clickhouse_history(schema: str, table: str, limit: int = Query(20, ge=1, le=200)):
    try:
        schema_norm = (schema or "").strip()
        table_norm = (table or "").strip()
        table_clean = _clean_table_name(norm(table))
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    _clickhouse_run_agg_cte(
                        run_filter_sql="AND r.schema_name = :schema",
                        stage_filter_sql="AND (lower(s.table_name) = lower(:table) OR lower(s.table_name) = lower(:table_clean))",
                    )
                    + """
                    SELECT *
                    FROM run_agg
                    ORDER BY start_dttm DESC NULLS LAST
                    LIMIT :limit
                    """
                ),
                {"schema": schema_norm, "table": table_norm, "table_clean": table_clean, "limit": limit},
            ).mappings().all()

        history = [
            {
                "run_uuid": row.get("run_uuid"),
                "stage_name": "TOTAL",
                "start_dttm": serialize_datetime(row.get("start_dttm")),
                "end_dttm": serialize_datetime(row.get("end_dttm")),
                "status": row.get("status"),
                "dag_name": row.get("dag_name"),
                "dag_run": row.get("dag_run"),
                **_clickhouse_run_metrics(row),
            }
            for row in rows
        ]
        return history
    except Exception as e:
        print("❌ /api/click/history error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/click/slow-stages")
def get_clickhouse_slow_stages(days: int = Query(7, ge=1, le=365), limit: int = Query(10, ge=1, le=50)):
    try:
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    _clickhouse_run_agg_cte(
                        run_filter_sql="AND r.start_dttm >= now() - (:days || ' days')::interval"
                    )
                    + """
                    SELECT
                        run_uuid,
                        schema_name,
                        table_name,
                        dag_name,
                        dag_run,
                        start_dttm,
                        end_dttm,
                        status,
                        actual_duration_seconds,
                        elapsed_duration_seconds
                    FROM run_agg
                    ORDER BY actual_duration_seconds DESC NULLS LAST
                    LIMIT :limit
                    """
                ),
                {"days": days, "limit": limit},
            ).mappings().all()

        result = [
            {
                "run_uuid": row.get("run_uuid"),
                "schema_name": row.get("schema_name"),
                "table_name": row.get("table_name"),
                "start_dttm": serialize_datetime(row.get("start_dttm")),
                "end_dttm": serialize_datetime(row.get("end_dttm")),
                "status": row.get("status"),
                "dag_name": row.get("dag_name"),
                "dag_run": row.get("dag_run"),
                **_clickhouse_run_metrics(row),
            }
            for row in rows
        ]
        return result
    except Exception as e:
        print("❌ /api/click/slow-stages error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/window-runs")
def get_window_runs(
    date: str,
    time_from: str = Query(..., alias="from"),
    time_to: str = Query(..., alias="to"),
    source: str = "both",
):
    """
    Returns runs for GP and/or ClickHouse inside a local-time window.
    date: YYYY-MM-DD
    from/to: HH:MM (local)
    source: gp | click | both
    """
    try:
        window_start = f"{date} {time_from}:00"
        window_end = f"{date} {time_to}:00"
        payload = {"window_start": window_start, "window_end": window_end, "timezone": "local"}

        with engine.connect() as conn:
            if source in ("gp", "both"):
                gp_rows = conn.execute(
                    text(
                        f"""
                        SELECT
                            COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) AS schema_name,
                            COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_name,
                            e.entity_name,
                            l.loading_start_dttm AS start_dttm,
                            l.loading_finish_dttm AS end_dttm,
                            l.loading_state AS status,
                            EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration_min
                        FROM {TABLE_LOADING_HISTORY} l
                        LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                        LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                        WHERE l.object_type = 'table'
                          AND l.loading_start_dttm >= :window_start
                          AND l.loading_start_dttm <= :window_end
                        ORDER BY l.loading_start_dttm ASC
                        """
                    ),
                    {"window_start": window_start, "window_end": window_end},
                ).mappings().all()
                payload["gp"] = [
                    {
                        "schema_name": row.get("schema_name"),
                        "table_name": row.get("table_name"),
                        "entity_name": row.get("entity_name"),
                        "start_dttm": serialize_datetime(row.get("start_dttm")),
                        "end_dttm": serialize_datetime(row.get("end_dttm")),
                        "duration_min": round(float(row.get("duration_min") or 0), 2) if row.get("duration_min") is not None else None,
                        "status": row.get("status"),
                    }
                    for row in gp_rows
                ]

            if source in ("click", "both"):
                click_rows = conn.execute(
                    text(
                        _clickhouse_run_agg_cte()
                        + f"""
                        SELECT
                            ra.run_uuid,
                            ra.schema_name,
                            ra.table_name,
                            tm.entity_name,
                            ra.start_dttm,
                            ra.end_dttm,
                            ra.status,
                            ra.actual_duration_seconds,
                            ra.elapsed_duration_seconds
                        FROM run_agg ra
                        LEFT JOIN {TABLE_TABLES_META} tm
                          ON tm.table_id = ra.table_id
                        WHERE ra.start_dttm >= :window_start
                          AND ra.start_dttm <= :window_end
                        ORDER BY ra.start_dttm ASC
                        """
                    ),
                    {"window_start": window_start, "window_end": window_end},
                ).mappings().all()
                payload["click"] = [
                    {
                        "run_uuid": row.get("run_uuid"),
                        "schema_name": row.get("schema_name"),
                        "table_name": row.get("table_name"),
                        "entity_name": row.get("entity_name"),
                        "start_dttm": serialize_datetime(row.get("start_dttm")),
                        "end_dttm": serialize_datetime(row.get("end_dttm")),
                        "status": row.get("status"),
                        **_clickhouse_run_metrics(row),
                    }
                    for row in click_rows
                ]

        return payload
    except Exception as e:
        print("❌ /api/window-runs error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/load-compare")
def get_load_compare(
    date_a: str = Query(..., alias="date_a"),
    date_b: str = Query(..., alias="date_b"),
    entity_id: Optional[int] = Query(None, ge=1),
):
    try:
        start_a = f"{date_a} 00:00:00"
        end_a = f"{date_a} 23:59:59"
        start_b = f"{date_b} 00:00:00"
        end_b = f"{date_b} 23:59:59"

        query = f"""
            WITH base AS (
                SELECT
                    l.object_id AS table_id,
                    COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) AS table_schema,
                    COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_name,
                    e.entity_id,
                    COALESCE(e.entity_name, 'UNKNOWN') AS entity_name,
                    l.loading_start_dttm,
                    l.loading_finish_dttm,
                    EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration_minutes
                FROM {TABLE_LOADING_HISTORY} l
                LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'SUCCESS'
                  AND l.loading_start_dttm IS NOT NULL
                  AND l.loading_finish_dttm IS NOT NULL
                  AND (
                    (l.loading_start_dttm >= :start_a AND l.loading_start_dttm <= :end_a)
                    OR
                    (l.loading_start_dttm >= :start_b AND l.loading_start_dttm <= :end_b)
                  )
                  AND (:entity_id IS NULL OR e.entity_id = :entity_id)
            ),
            ranked_a AS (
                SELECT
                    *,
                    ROW_NUMBER() OVER (
                        PARTITION BY table_schema, table_name
                        ORDER BY loading_start_dttm DESC NULLS LAST
                    ) AS rn
                FROM base
                WHERE loading_start_dttm >= :start_a AND loading_start_dttm <= :end_a
            ),
            ranked_b AS (
                SELECT
                    *,
                    ROW_NUMBER() OVER (
                        PARTITION BY table_schema, table_name
                        ORDER BY loading_start_dttm DESC NULLS LAST
                    ) AS rn
                FROM base
                WHERE loading_start_dttm >= :start_b AND loading_start_dttm <= :end_b
            ),
            latest_a AS (
                SELECT * FROM ranked_a WHERE rn = 1
            ),
            latest_b AS (
                SELECT * FROM ranked_b WHERE rn = 1
            )
            SELECT
                COALESCE(a.table_id, b.table_id) AS table_id,
                COALESCE(a.table_schema, b.table_schema) AS table_schema,
                COALESCE(a.table_name, b.table_name) AS table_name,
                COALESCE(a.entity_id, b.entity_id) AS entity_id,
                COALESCE(a.entity_name, b.entity_name) AS entity_name,
                a.duration_minutes AS duration_a,
                a.loading_start_dttm AS start_a,
                a.loading_finish_dttm AS end_a,
                b.duration_minutes AS duration_b,
                b.loading_start_dttm AS start_b,
                b.loading_finish_dttm AS end_b
            FROM latest_a a
            FULL OUTER JOIN latest_b b
              ON a.table_schema = b.table_schema
             AND a.table_name = b.table_name
            ORDER BY ABS(COALESCE(b.duration_minutes, 0) - COALESCE(a.duration_minutes, 0)) DESC NULLS LAST,
                     COALESCE(a.table_schema, b.table_schema),
                     COALESCE(a.table_name, b.table_name)
        """

        params = {
            "start_a": start_a,
            "end_a": end_a,
            "start_b": start_b,
            "end_b": end_b,
            "entity_id": entity_id,
        }

        with engine.connect() as conn:
            rows = conn.execute(text(query), params).mappings().all()

        result_rows = []
        for row in rows:
            duration_a = float(row.get("duration_a")) if row.get("duration_a") is not None else None
            duration_b = float(row.get("duration_b")) if row.get("duration_b") is not None else None
            delta_minutes = None
            delta_pct = None
            if duration_a is not None and duration_b is not None:
                delta_minutes = round(duration_b - duration_a, 2)
                if duration_a:
                    delta_pct = round(((duration_b - duration_a) / duration_a) * 100, 2)

            result_rows.append(
                {
                    "table_id": row.get("table_id"),
                    "table_fqn": f"{row.get('table_schema')}.{row.get('table_name')}".strip("."),
                    "table_schema": row.get("table_schema"),
                    "table_name": row.get("table_name"),
                    "entity_id": row.get("entity_id"),
                    "entity_name": row.get("entity_name"),
                    "duration_a": round(duration_a, 2) if duration_a is not None else None,
                    "duration_b": round(duration_b, 2) if duration_b is not None else None,
                    "delta_minutes": delta_minutes,
                    "delta_pct": delta_pct,
                    "start_a": serialize_datetime(row.get("start_a")),
                    "end_a": serialize_datetime(row.get("end_a")),
                    "start_b": serialize_datetime(row.get("start_b")),
                    "end_b": serialize_datetime(row.get("end_b")),
                }
            )

        return {
            "date_a": date_a,
            "date_b": date_b,
            "entity_id": entity_id,
            "rows": result_rows,
        }
    except Exception as e:
        print("❌ /api/load-compare error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


def _build_ytrack_link(task_id: Optional[str]) -> Optional[str]:
    if not task_id:
        return None
    base = (YTRACK_ISSUE_URL or "").strip()
    if not base:
        return None
    return base.replace("{task_id}", task_id).replace("{id}", task_id)


def _resolve_date_window(date_from: Optional[str], date_to: Optional[str], days: int):
    # date_from/date_to are expected as YYYY-MM-DD; fallback to last N days
    params = {"days": days}
    clause = "r.started_at >= (now() - (:days || ' days')::interval)"
    if date_from:
        clause = "r.started_at >= :date_from"
        params = {"date_from": date_from, "days": days}
    if date_to:
        clause = clause + " AND r.started_at <= :date_to"
        params["date_to"] = date_to
    return clause, params


@router.get("/api/releases")
def get_releases(days: int = Query(30, ge=1, le=365), limit: int = Query(50, ge=1, le=200)):
    try:
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    f"""
                    SELECT
                        l.release_id,
                        l.release_type,
                        l.initiated_by,
                        l.started_at,
                        l.finished_at,
                        l.status,
                        l.total_objects,
                        l.ready_to_release,
                        EXTRACT(EPOCH FROM (COALESCE(l.finished_at, now()) - l.started_at)) / 60.0 AS duration_minutes,
                        COALESCE(o.objects_count, 0) AS objects_count,
                        COALESCE(o.failed_count, 0) AS failed_count,
                        COALESCE(o.failed_any, false) AS failed_any,
                        COALESCE(o.task_ids, ARRAY[]::text[]) AS task_ids,
                        COALESCE(w.hours_total, 0) AS hours_total
                    FROM {TABLE_RELEASE_LOG} l
                    LEFT JOIN (
                        SELECT
                            release_id,
                            COUNT(*) AS objects_count,
                            COUNT(*) FILTER (WHERE lower(final_status) NOT IN ('success', 'succeeded', 'ok')) AS failed_count,
                            BOOL_OR(failed_objects) AS failed_any,
                            ARRAY_AGG(DISTINCT task_id) FILTER (WHERE task_id IS NOT NULL AND task_id <> '') AS task_ids
                        FROM {TABLE_RELEASE_OBJECTS}
                        GROUP BY release_id
                    ) o ON o.release_id = l.release_id
                    LEFT JOIN (
                        SELECT ro.release_id,
                               COALESCE(SUM(w.minutes), 0) / 60.0 AS hours_total
                        FROM (
                            SELECT DISTINCT release_id, task_id
                            FROM {TABLE_RELEASE_OBJECTS}
                            WHERE task_id IS NOT NULL AND task_id <> ''
                        ) ro
                        LEFT JOIN (
                            SELECT issue_id, COALESCE(SUM(minutes), 0) AS minutes
                            FROM {TABLE_YT_ISSUE_WORKLOG}
                            GROUP BY issue_id
                        ) w ON w.issue_id = ro.task_id
                        GROUP BY ro.release_id
                    ) w ON w.release_id = l.release_id
                    WHERE l.started_at >= (now() - (:days || ' days')::interval)
                    ORDER BY l.started_at DESC
                    LIMIT :limit
                    """
                ),
                {"days": days, "limit": limit},
            )
            payload = []
            for row in rows:
                record = dict(row._mapping)
                task_ids = record.get("task_ids") or []
                record["task_ids"] = task_ids
                record["task_links"] = [link for link in (_build_ytrack_link(t) for t in task_ids) if link]
                payload.append(record)
            return {"items": payload}
    except Exception as e:
        print("❌ /api/releases error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить релизы")


@router.get("/api/releases/{release_id}")
def get_release_details(release_id: str, limit: int = Query(500, ge=1, le=2000)):
    try:
        with engine.connect() as conn:
            log_row = conn.execute(
                text(
                    f"""
                    SELECT release_id, release_type, initiated_by, started_at, finished_at,
                           status, total_objects, ready_to_release,
                           EXTRACT(EPOCH FROM (COALESCE(finished_at, now()) - started_at)) / 60.0 AS duration_minutes
                    FROM {TABLE_RELEASE_LOG}
                    WHERE release_id = :release_id
                    LIMIT 1
                    """
                ),
                {"release_id": release_id},
            ).fetchone()
            if not log_row:
                raise HTTPException(status_code=404, detail="Релиз не найден")
            objects = conn.execute(
                text(
                    f"""
                    SELECT
                        release_id,
                        task_id,
                        target_system,
                        schema_name,
                        table_name,
                        entity_id,
                        entity_name,
                        change_type,
                        final_status,
                        attempts_count,
                        created_at,
                        failed_objects,
                        attempt_no,
                        error_message,
                        error_stacktrace
                    FROM {TABLE_RELEASE_OBJECTS}
                    WHERE release_id = :release_id
                    ORDER BY created_at DESC
                    LIMIT :limit
                    """
                ),
                {"release_id": release_id, "limit": limit},
            ).fetchall()
            obj_payload = []
            for row in objects:
                record = dict(row._mapping)
                record["task_link"] = _build_ytrack_link(record.get("task_id"))
                obj_payload.append(record)
            return {"release": dict(log_row._mapping), "objects": obj_payload}
    except HTTPException:
        raise
    except Exception as e:
        print("❌ /api/releases/{id} error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить детали релиза")


@router.get("/api/releases/table/{schema}/{table:path}")
def get_table_releases(
    schema: str,
    table: str,
    target_system: Optional[str] = None,
    limit: int = Query(30, ge=1, le=200),
):
    try:
        table_clean = _clean_table_name(norm(table))
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    f"""
                    WITH issue_snapshot AS (
                        SELECT
                            issue_id,
                            assignee,
                            created_by
                        FROM {TABLE_YT_ISSUE_SNAPSHOT}
                    ),
                    issue_executor AS (
                        SELECT DISTINCT ON (issue_id)
                               issue_id,
                               author AS executor
                        FROM {TABLE_YT_ISSUE_TIMELINE}
                        WHERE event_type = 'State change'
                          AND value_to IN ('Ожидание релиза', 'В работе')
                        ORDER BY issue_id, ts DESC NULLS LAST
                    )
                    SELECT
                        o.release_id,
                        o.task_id,
                        o.target_system,
                        o.schema_name,
                        o.table_name,
                        o.entity_id,
                        o.entity_name,
                        o.change_type,
                        o.final_status,
                        o.attempts_count,
                        o.created_at,
                        o.failed_objects,
                        o.attempt_no,
                        o.error_message,
                        o.error_stacktrace,
                        l.release_type,
                        l.initiated_by,
                        l.started_at,
                        l.finished_at,
                        l.status AS release_status,
                        COALESCE(exec.executor, snap.assignee, snap.created_by, '—') AS task_executor
                    FROM {TABLE_RELEASE_OBJECTS} o
                    LEFT JOIN {TABLE_RELEASE_LOG} l ON l.release_id = o.release_id
                    LEFT JOIN issue_snapshot snap ON snap.issue_id = o.task_id
                    LEFT JOIN issue_executor exec ON exec.issue_id = o.task_id
                    WHERE o.schema_name = :schema
                      AND (lower(o.table_name) = lower(:table) OR lower(o.table_name) = lower(:table_clean))
                      AND (:target_system IS NULL OR lower(o.target_system) = lower(:target_system))
                    ORDER BY o.created_at DESC
                    LIMIT :limit
                    """
                ),
                {"schema": schema, "table": table, "table_clean": table_clean, "target_system": target_system, "limit": limit},
            ).fetchall()
            payload = []
            for row in rows:
                record = dict(row._mapping)
                record["task_link"] = _build_ytrack_link(record.get("task_id"))
                payload.append(record)
            return {"items": payload}
    except Exception as e:
        print("❌ /api/releases/table error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить релизы по объекту")


@router.get("/api/ytrek/table/{schema}/{table:path}")
def get_ytrek_table_info(schema: str, table: str):
    try:
        table_clean = _clean_table_name(norm(table))
        with engine.connect() as conn:
            task_rows = conn.execute(
                text(
                    f"""
                    SELECT DISTINCT task_id
                    FROM {TABLE_RELEASE_OBJECTS}
                    WHERE schema_name = :schema
                      AND (lower(table_name) = lower(:table) OR lower(table_name) = lower(:table_clean))
                      AND task_id IS NOT NULL
                    """
                ),
                {"schema": schema, "table": table, "table_clean": table_clean},
            ).fetchall()
            task_ids = [r[0] for r in task_rows if r[0]]
            if not task_ids:
                return {"tasks": [], "timeline": [], "worklog": [], "stats": {}}

            snapshots = conn.execute(
                text(
                    f"""
                    SELECT issue_id, summary, project_name, project_key, created_by, assignee,
                           created_at, updated_at, resolved_at, current_state
                    FROM {TABLE_YT_ISSUE_SNAPSHOT}
                    WHERE issue_id = ANY(:ids)
                    ORDER BY updated_at DESC NULLS LAST
                    """
                ),
                {"ids": task_ids},
            ).mappings().all()

            worklog = conn.execute(
                text(
                    f"""
                    SELECT issue_id,
                           COALESCE(SUM(minutes), 0) AS minutes,
                           COUNT(*) AS entries
                    FROM {TABLE_YT_ISSUE_WORKLOG}
                    WHERE issue_id = ANY(:ids)
                    GROUP BY issue_id
                    """
                ),
                {"ids": task_ids},
            ).mappings().all()
            worklog_map = {r["issue_id"]: r for r in worklog}

            timeline = conn.execute(
                text(
                    f"""
                    SELECT issue_id, ts, author, event_type, field_name, value_from, value_to
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE issue_id = ANY(:ids)
                    ORDER BY ts DESC NULLS LAST
                    LIMIT 200
                    """
                ),
                {"ids": task_ids},
            ).mappings().all()

            last_assignee = conn.execute(
                text(
                    f"""
                    SELECT DISTINCT ON (issue_id)
                           issue_id, ts, author, value_from, value_to
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE issue_id = ANY(:ids)
                      AND event_type = 'Assignee change'
                    ORDER BY issue_id, ts DESC NULLS LAST
                    """
                ),
                {"ids": task_ids},
            ).mappings().all()
            last_assignee_map = {r["issue_id"]: r for r in last_assignee}

            last_state = conn.execute(
                text(
                    f"""
                    SELECT DISTINCT ON (issue_id)
                           issue_id, ts, author, value_from, value_to
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE issue_id = ANY(:ids)
                      AND event_type = 'State change'
                    ORDER BY issue_id, ts DESC NULLS LAST
                    """
                ),
                {"ids": task_ids},
            ).mappings().all()
            last_state_map = {r["issue_id"]: r for r in last_state}

            last_wait = conn.execute(
                text(
                    f"""
                    SELECT DISTINCT ON (issue_id)
                           issue_id, ts, author, value_from, value_to
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE issue_id = ANY(:ids)
                      AND event_type = 'State change'
                      AND value_to = 'Ожидание релиза'
                    ORDER BY issue_id, ts DESC NULLS LAST
                    """
                ),
                {"ids": task_ids},
            ).mappings().all()
            last_wait_map = {r["issue_id"]: r for r in last_wait}

            last_work = conn.execute(
                text(
                    f"""
                    SELECT DISTINCT ON (issue_id)
                           issue_id, ts, author, value_from, value_to
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE issue_id = ANY(:ids)
                      AND event_type = 'State change'
                      AND value_to = 'В работе'
                    ORDER BY issue_id, ts DESC NULLS LAST
                    """
                ),
                {"ids": task_ids},
            ).mappings().all()
            last_work_map = {r["issue_id"]: r for r in last_work}

            custom = conn.execute(
                text(
                    f"""
                    SELECT issue_id, field_name, field_value
                    FROM {TABLE_YT_ISSUE_CUSTOM}
                    WHERE issue_id = ANY(:ids)
                      AND field_name IN ('Subsystem', 'Дашборд КХД/Направление', 'Дашборд SD', 'Тип карточки', 'Дата релиза')
                    """
                ),
                {"ids": task_ids},
            ).mappings().all()
            custom_map = {}
            for row in custom:
                custom_map.setdefault(row["issue_id"], {})[row["field_name"]] = row["field_value"]

            tasks_payload = []
            for s in snapshots:
                issue_id = s["issue_id"]
                wl = worklog_map.get(issue_id, {})
                effective_assignee = None
                effective_reason = None
                if issue_id in last_wait_map:
                    effective_assignee = last_wait_map[issue_id].get("author")
                    effective_reason = "Ожидание релиза"
                elif issue_id in last_work_map:
                    effective_assignee = last_work_map[issue_id].get("author")
                    effective_reason = "В работе"
                else:
                    effective_assignee = s.get("assignee")
                    effective_reason = "Текущий"
                tasks_payload.append(
                    {
                        **s,
                        "work_minutes": wl.get("minutes", 0),
                        "work_entries": wl.get("entries", 0),
                        "last_assignee_change": last_assignee_map.get(issue_id),
                        "last_state_change": last_state_map.get(issue_id),
                        "custom": custom_map.get(issue_id, {}),
                        "effective_assignee": effective_assignee,
                        "effective_assignee_reason": effective_reason,
                    }
                )

            stats = {
                "tasks_count": len(task_ids),
                "work_minutes_total": sum(r.get("minutes", 0) for r in worklog_map.values()),
            }

            return {
                "tasks": tasks_payload,
                "timeline": [
                    {
                        "issue_id": r["issue_id"],
                        "ts": serialize_datetime(r["ts"]),
                        "author": r["author"],
                        "event_type": r["event_type"],
                        "field_name": r["field_name"],
                        "value_from": r["value_from"],
                        "value_to": r["value_to"],
                    }
                    for r in timeline
                ],
                "stats": stats,
            }
    except Exception as e:
        print("❌ /api/ytrek/table error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить данные YouTrack")


@router.get("/api/ytrek/analytics")
def get_ytrek_analytics(days: int = Query(365, ge=1, le=3650)):
    try:
        with engine.connect() as conn:
            base = f"""
                WITH tasks AS (
                    SELECT DISTINCT ro.task_id
                    FROM {TABLE_RELEASE_OBJECTS} ro
                    WHERE ro.task_id IS NOT NULL
                ),
                snap AS (
                    SELECT s.*
                    FROM {TABLE_YT_ISSUE_SNAPSHOT} s
                    JOIN tasks t ON t.task_id = s.issue_id
                    WHERE s.created_at >= (now() - (:days || ' days')::interval)
                ),
                exec AS (
                    SELECT DISTINCT ON (issue_id)
                           issue_id, author AS executor, ts
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE event_type = 'State change'
                      AND value_to IN ('Ожидание релиза', 'В работе')
                    ORDER BY issue_id, ts DESC NULLS LAST
                ),
                work AS (
                    SELECT issue_id, COALESCE(SUM(minutes), 0) AS minutes
                    FROM {TABLE_YT_ISSUE_WORKLOG}
                    GROUP BY issue_id
                ),
                team AS (
                    SELECT issue_id, field_value AS team
                    FROM {TABLE_YT_ISSUE_CUSTOM}
                    WHERE field_name = 'Subsystem'
                ),
                dashboard AS (
                    SELECT issue_id, field_value AS dashboard_direction
                    FROM {TABLE_YT_ISSUE_CUSTOM}
                    WHERE field_name = 'Дашборд КХД/Направление'
                )
            """

            by_team = conn.execute(
                text(
                    base
                    + """
                    SELECT COALESCE(t.team, 'Не указана') AS team,
                           COUNT(*) AS tasks_count,
                           COALESCE(SUM(w.minutes), 0) AS minutes
                    FROM snap s
                    LEFT JOIN work w ON w.issue_id = s.issue_id
                    LEFT JOIN team t ON t.issue_id = s.issue_id
                    GROUP BY t.team
                    ORDER BY minutes DESC NULLS LAST
                    """
                ),
                {"days": days},
            ).mappings().all()

            by_dashboard = conn.execute(
                text(
                    base
                    + """
                    SELECT COALESCE(d.dashboard_direction, 'Не указан') AS dashboard_direction,
                           COUNT(*) AS tasks_count,
                           COALESCE(SUM(w.minutes), 0) AS minutes
                    FROM snap s
                    LEFT JOIN work w ON w.issue_id = s.issue_id
                    LEFT JOIN dashboard d ON d.issue_id = s.issue_id
                    GROUP BY d.dashboard_direction
                    ORDER BY minutes DESC NULLS LAST
                    """
                ),
                {"days": days},
            ).mappings().all()

            by_creator = conn.execute(
                text(
                    base
                    + """
                    SELECT COALESCE(s.created_by, 'Не указан') AS creator,
                           COUNT(*) AS tasks_count,
                           COALESCE(SUM(w.minutes), 0) AS minutes
                    FROM snap s
                    LEFT JOIN work w ON w.issue_id = s.issue_id
                    GROUP BY s.created_by
                    ORDER BY minutes DESC NULLS LAST
                    """
                ),
                {"days": days},
            ).mappings().all()

            by_assignee = conn.execute(
                text(
                    base
                    + """
                    SELECT COALESCE(exec.executor, s.assignee, s.created_by, 'Не указан') AS assignee,
                           COUNT(*) AS tasks_count,
                           COALESCE(SUM(w.minutes), 0) AS minutes
                    FROM snap s
                    LEFT JOIN exec ON exec.issue_id = s.issue_id
                    LEFT JOIN work w ON w.issue_id = s.issue_id
                    GROUP BY 1
                    ORDER BY minutes DESC NULLS LAST
                    """
                ),
                {"days": days},
            ).mappings().all()

            return {
                "by_team": by_team,
                "by_dashboard": by_dashboard,
                "by_creator": by_creator,
                "by_assignee": by_assignee,
            }
    except Exception as e:
        print("❌ /api/ytrek/analytics error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить аналитику YouTrack")


@router.get("/api/ytrek/tasks")
def get_ytrek_tasks(days: int = Query(365, ge=1, le=3650)):
    try:
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    f"""
                    WITH tasks AS (
                        SELECT DISTINCT ro.task_id
                        FROM {TABLE_RELEASE_OBJECTS} ro
                        WHERE ro.task_id IS NOT NULL
                    ),
                    snap AS (
                        SELECT s.*
                        FROM {TABLE_YT_ISSUE_SNAPSHOT} s
                        JOIN tasks t ON t.task_id = s.issue_id
                        WHERE s.created_at >= (now() - (:days || ' days')::interval)
                    ),
                    exec AS (
                        SELECT DISTINCT ON (issue_id)
                               issue_id, author AS executor, ts
                        FROM {TABLE_YT_ISSUE_TIMELINE}
                        WHERE event_type = 'State change'
                          AND value_to IN ('Ожидание релиза', 'В работе')
                        ORDER BY issue_id, ts DESC NULLS LAST
                    ),
                work AS (
                    SELECT issue_id, COALESCE(SUM(minutes), 0) AS minutes
                    FROM {TABLE_YT_ISSUE_WORKLOG}
                    GROUP BY issue_id
                ),
                team AS (
                    SELECT issue_id, field_value AS team
                    FROM {TABLE_YT_ISSUE_CUSTOM}
                    WHERE field_name = 'Subsystem'
                ),
                dashboard AS (
                    SELECT issue_id, field_value AS dashboard_direction
                    FROM {TABLE_YT_ISSUE_CUSTOM}
                    WHERE field_name = 'Дашборд КХД/Направление'
                )
                SELECT s.issue_id,
                       COALESCE(s.created_by, 'Не указан') AS created_by,
                       COALESCE(exec.executor, s.assignee, s.created_by, 'Не указан') AS assignee,
                       s.current_state,
                       COALESCE(t.team, 'Не указана') AS team,
                       COALESCE(d.dashboard_direction, 'Не указан') AS dashboard_direction,
                       COALESCE(w.minutes, 0) AS minutes
                FROM snap s
                LEFT JOIN exec ON exec.issue_id = s.issue_id
                LEFT JOIN work w ON w.issue_id = s.issue_id
                LEFT JOIN team t ON t.issue_id = s.issue_id
                LEFT JOIN dashboard d ON d.issue_id = s.issue_id
                ORDER BY w.minutes DESC NULLS LAST
                """
            ),
                {"days": days},
            ).mappings().all()
            return rows
    except Exception as e:
        print("❌ /api/ytrek/tasks error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить задачи YouTrack")


@router.get("/api/ytrek/workload")
def get_ytrek_workload(days: int = Query(90, ge=14, le=3650)):
    try:
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    f"""
                    WITH tasks AS (
                        SELECT DISTINCT ro.task_id
                        FROM {TABLE_RELEASE_OBJECTS} ro
                        WHERE ro.task_id IS NOT NULL
                    ),
                    day_series AS (
                        SELECT generate_series(
                            CURRENT_DATE - (:days - 1) * INTERVAL '1 day',
                            CURRENT_DATE,
                            INTERVAL '1 day'
                        )::date AS day
                    ),
                    snap AS (
                        SELECT s.issue_id, s.created_at
                        FROM {TABLE_YT_ISSUE_SNAPSHOT} s
                        JOIN tasks t ON t.task_id = s.issue_id
                    ),
                    first_assignee AS (
                        SELECT issue_id, MIN(ts) AS ts
                        FROM {TABLE_YT_ISSUE_TIMELINE}
                        WHERE event_type = 'Assignee change'
                        GROUP BY issue_id
                    ),
                    first_work AS (
                        SELECT issue_id, MIN(ts) AS ts
                        FROM {TABLE_YT_ISSUE_TIMELINE}
                        WHERE event_type = 'State change'
                          AND value_to = 'В работе'
                        GROUP BY issue_id
                    ),
                    first_wait_release AS (
                        SELECT issue_id, MIN(ts) AS ts
                        FROM {TABLE_YT_ISSUE_TIMELINE}
                        WHERE event_type = 'State change'
                          AND value_to = 'Ожидание релиза'
                        GROUP BY issue_id
                    ),
                    created_daily AS (
                        SELECT DATE(created_at) AS day, COUNT(*) AS cnt
                        FROM snap
                        WHERE created_at >= CURRENT_DATE - (:days - 1) * INTERVAL '1 day'
                        GROUP BY 1
                    ),
                    assignee_daily AS (
                        SELECT DATE(a.ts) AS day, COUNT(*) AS cnt
                        FROM first_assignee a
                        JOIN tasks t ON t.task_id = a.issue_id
                        WHERE a.ts >= CURRENT_DATE - (:days - 1) * INTERVAL '1 day'
                        GROUP BY 1
                    ),
                    work_daily AS (
                        SELECT DATE(w.ts) AS day, COUNT(*) AS cnt
                        FROM first_work w
                        JOIN tasks t ON t.task_id = w.issue_id
                        WHERE w.ts >= CURRENT_DATE - (:days - 1) * INTERVAL '1 day'
                        GROUP BY 1
                    ),
                    wait_daily AS (
                        SELECT DATE(w.ts) AS day, COUNT(*) AS cnt
                        FROM first_wait_release w
                        JOIN tasks t ON t.task_id = w.issue_id
                        WHERE w.ts >= CURRENT_DATE - (:days - 1) * INTERVAL '1 day'
                        GROUP BY 1
                    ),
                    release_daily AS (
                        SELECT DATE(started_at) AS day, COUNT(*) AS cnt
                        FROM {TABLE_RELEASE_LOG}
                        WHERE started_at >= CURRENT_DATE - (:days - 1) * INTERVAL '1 day'
                        GROUP BY 1
                    )
                    SELECT
                        ds.day::text AS day,
                        COALESCE(cd.cnt, 0) AS created_count,
                        COALESCE(ad.cnt, 0) AS assigned_count,
                        COALESCE(wd.cnt, 0) AS in_work_count,
                        COALESCE(rd.cnt, 0) AS release_ready_count,
                        COALESCE(ld.cnt, 0) AS release_count,
                        COALESCE(cd.cnt, 0)
                          + COALESCE(ad.cnt, 0)
                          + COALESCE(wd.cnt, 0)
                          + COALESCE(rd.cnt, 0) AS total_activity
                    FROM day_series ds
                    LEFT JOIN created_daily cd ON cd.day = ds.day
                    LEFT JOIN assignee_daily ad ON ad.day = ds.day
                    LEFT JOIN work_daily wd ON wd.day = ds.day
                    LEFT JOIN wait_daily rd ON rd.day = ds.day
                    LEFT JOIN release_daily ld ON ld.day = ds.day
                    ORDER BY ds.day
                    """
                ),
                {"days": days},
            ).mappings().all()
            return list(rows)
    except Exception as e:
        print("❌ /api/ytrek/workload error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить нагрузку по задачам")


@router.get("/api/analytics/dashboard")
def get_analytics_dashboard(
    days: int = Query(30, ge=1, le=3650),
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
):
    try:
        date_clause, params = _resolve_date_window(date_from, date_to, days)
        with engine.connect() as conn:
            base = f"""
                WITH rel AS (
                    SELECT r.release_id, r.started_at, r.finished_at, r.initiated_by, r.status
                    FROM {TABLE_RELEASE_LOG} r
                    WHERE {date_clause}
                ),
                ro AS (
                    SELECT ro.*
                    FROM {TABLE_RELEASE_OBJECTS} ro
                    JOIN rel r ON r.release_id = ro.release_id
                ),
                tasks AS (
                    SELECT DISTINCT task_id
                    FROM ro
                    WHERE task_id IS NOT NULL
                ),
                snap AS (
                    SELECT s.*
                    FROM {TABLE_YT_ISSUE_SNAPSHOT} s
                    JOIN tasks t ON t.task_id = s.issue_id
                ),
                exec AS (
                    SELECT DISTINCT ON (issue_id)
                           issue_id, author AS executor, ts
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE event_type = 'State change'
                      AND value_to IN ('Ожидание релиза', 'В работе')
                    ORDER BY issue_id, ts DESC NULLS LAST
                ),
                work AS (
                    SELECT issue_id, COALESCE(SUM(minutes), 0) AS minutes
                    FROM {TABLE_YT_ISSUE_WORKLOG}
                    GROUP BY issue_id
                ),
                direction AS (
                    SELECT issue_id, field_value AS direction
                    FROM {TABLE_YT_ISSUE_CUSTOM}
                    WHERE field_name = 'Направление'
                )
            """

            summary = conn.execute(
                text(
                    base
                    + """
                    SELECT
                        (SELECT COUNT(*) FROM rel) AS releases,
                        (SELECT COUNT(*) FROM tasks) AS tasks,
                        (SELECT COUNT(*) FROM ro) AS objects,
                        (SELECT COALESCE(SUM(minutes), 0) FROM work) AS minutes,
                        (SELECT COUNT(DISTINCT COALESCE(exec.executor, snap.assignee, snap.created_by))
                         FROM snap
                         LEFT JOIN exec ON exec.issue_id = snap.issue_id) AS executors
                    """
                ),
                params,
            ).mappings().first()

            by_executor = conn.execute(
                text(
                    base
                    + """
                    SELECT COALESCE(exec.executor, snap.assignee, snap.created_by, 'Не указан') AS executor,
                           COUNT(DISTINCT snap.issue_id) AS tasks_count,
                           COUNT(ro.table_name) AS tables_count,
                           COALESCE(SUM(work.minutes), 0) AS minutes
                    FROM snap
                    LEFT JOIN exec ON exec.issue_id = snap.issue_id
                    LEFT JOIN work ON work.issue_id = snap.issue_id
                    LEFT JOIN ro ON ro.task_id = snap.issue_id
                    GROUP BY executor
                    ORDER BY minutes DESC NULLS LAST
                    """
                ),
                params,
            ).mappings().all()

            by_creator = conn.execute(
                text(
                    base
                    + """
                    SELECT COALESCE(snap.created_by, 'Не указан') AS creator,
                           COUNT(DISTINCT snap.issue_id) AS tasks_count,
                           COUNT(ro.table_name) AS tables_count,
                           COALESCE(SUM(work.minutes), 0) AS minutes
                    FROM snap
                    LEFT JOIN work ON work.issue_id = snap.issue_id
                    LEFT JOIN ro ON ro.task_id = snap.issue_id
                    GROUP BY creator
                    ORDER BY minutes DESC NULLS LAST
                    """
                ),
                params,
            ).mappings().all()

            by_direction = conn.execute(
                text(
                    base
                    + """
                    SELECT COALESCE(direction.direction, 'Не указан') AS direction,
                           COUNT(DISTINCT snap.issue_id) AS tasks_count,
                           COUNT(ro.table_name) AS tables_count,
                           COALESCE(SUM(work.minutes), 0) AS minutes
                    FROM snap
                    LEFT JOIN direction ON direction.issue_id = snap.issue_id
                    LEFT JOIN work ON work.issue_id = snap.issue_id
                    LEFT JOIN ro ON ro.task_id = snap.issue_id
                    GROUP BY direction
                    ORDER BY minutes DESC NULLS LAST
                    """
                ),
                params,
            ).mappings().all()

            top_tables = conn.execute(
                text(
                    base
                    + """
                    SELECT ro.schema_name, ro.table_name,
                           COUNT(*) AS changes,
                           COALESCE(SUM(work.minutes), 0) AS minutes
                    FROM ro
                    LEFT JOIN work ON work.issue_id = ro.task_id
                    GROUP BY ro.schema_name, ro.table_name
                    ORDER BY changes DESC, minutes DESC
                    LIMIT 20
                    """
                ),
                params,
            ).mappings().all()

            return {
                "summary": summary,
                "by_executor": by_executor,
                "by_creator": by_creator,
                "by_direction": by_direction,
                "top_tables": top_tables,
            }
    except Exception as e:
        print("❌ /api/analytics/dashboard error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить дашборд")


@router.get("/api/analytics/release/{release_id}")
def get_analytics_release(release_id: str):
    try:
        with engine.connect() as conn:
            rel = conn.execute(
                text(
                    f"""
                    SELECT release_id, started_at, finished_at, initiated_by, status, total_objects
                    FROM {TABLE_RELEASE_LOG}
                    WHERE release_id = :release_id
                    """
                ),
                {"release_id": release_id},
            ).mappings().first()
            if not rel:
                raise HTTPException(status_code=404, detail="Релиз не найден")

            base = f"""
                WITH ro AS (
                    SELECT * FROM {TABLE_RELEASE_OBJECTS}
                    WHERE release_id = :release_id
                ),
                tasks AS (
                    SELECT DISTINCT task_id FROM ro WHERE task_id IS NOT NULL
                ),
                snap AS (
                    SELECT s.*
                    FROM {TABLE_YT_ISSUE_SNAPSHOT} s
                    JOIN tasks t ON t.task_id = s.issue_id
                ),
                exec AS (
                    SELECT DISTINCT ON (issue_id)
                           issue_id, author AS executor, ts
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE event_type = 'State change'
                      AND value_to IN ('Ожидание релиза', 'В работе')
                    ORDER BY issue_id, ts DESC NULLS LAST
                ),
                work AS (
                    SELECT issue_id, COALESCE(SUM(minutes), 0) AS minutes
                    FROM {TABLE_YT_ISSUE_WORKLOG}
                    GROUP BY issue_id
                ),
                direction AS (
                    SELECT issue_id, field_value AS direction
                    FROM {TABLE_YT_ISSUE_CUSTOM}
                    WHERE field_name = 'Направление'
                )
            """

            tasks_list = conn.execute(
                text(
                    base
                    + """
                    SELECT snap.issue_id AS task_id,
                           snap.created_by AS creator,
                           COALESCE(exec.executor, snap.assignee, snap.created_by, 'Не указан') AS executor,
                           COALESCE(direction.direction, 'Не указан') AS direction,
                           COUNT(ro.table_name) AS tables_count,
                           COALESCE(SUM(work.minutes), 0) AS minutes
                    FROM snap
                    LEFT JOIN exec ON exec.issue_id = snap.issue_id
                    LEFT JOIN direction ON direction.issue_id = snap.issue_id
                    LEFT JOIN work ON work.issue_id = snap.issue_id
                    LEFT JOIN ro ON ro.task_id = snap.issue_id
                    GROUP BY snap.issue_id, snap.created_by, exec.executor, snap.assignee, direction.direction
                    ORDER BY minutes DESC NULLS LAST
                    """
                ),
                {"release_id": release_id},
            ).mappings().all()

            tables_list = conn.execute(
                text(
                    base
                    + """
                    SELECT ro.schema_name, ro.table_name, ro.change_type, ro.task_id,
                           COALESCE(exec.executor, snap.assignee, snap.created_by, 'Не указан') AS executor,
                           ro.final_status
                    FROM ro
                    LEFT JOIN snap ON snap.issue_id = ro.task_id
                    LEFT JOIN exec ON exec.issue_id = ro.task_id
                    ORDER BY ro.schema_name, ro.table_name
                    """
                ),
                {"release_id": release_id},
            ).mappings().all()

            summary = {
                "release_id": rel["release_id"],
                "status": rel["status"],
                "started_at": rel["started_at"],
                "finished_at": rel["finished_at"],
                "initiated_by": rel["initiated_by"],
                "tasks": len({t["task_id"] for t in tasks_list}),
                "tables": len(tables_list),
                "hours": round(sum(t["minutes"] for t in tasks_list) / 60, 2),
            }

            return {"summary": summary, "tasks": tasks_list, "tables": tables_list}
    except HTTPException:
        raise
    except Exception as e:
        print("❌ /api/analytics/release error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить релиз")


@router.get("/api/analytics/table/{schema}/{table:path}")
def get_analytics_table(schema: str, table: str, days: int = Query(365, ge=1, le=3650)):
    try:
        date_clause, params = _resolve_date_window(None, None, days)
        params.update({"schema": schema, "table": table, "table_clean": _clean_table_name(norm(table))})
        with engine.connect() as conn:
            base = f"""
                WITH rel AS (
                    SELECT r.release_id, r.started_at
                    FROM {TABLE_RELEASE_LOG} r
                    WHERE {date_clause}
                ),
                ro AS (
                    SELECT ro.*
                    FROM {TABLE_RELEASE_OBJECTS} ro
                    JOIN rel r ON r.release_id = ro.release_id
                    WHERE ro.schema_name = :schema
                      AND (lower(ro.table_name) = lower(:table) OR lower(ro.table_name) = lower(:table_clean))
                ),
                tasks AS (
                    SELECT DISTINCT task_id FROM ro WHERE task_id IS NOT NULL
                ),
                snap AS (
                    SELECT s.*
                    FROM {TABLE_YT_ISSUE_SNAPSHOT} s
                    JOIN tasks t ON t.task_id = s.issue_id
                ),
                exec AS (
                    SELECT DISTINCT ON (issue_id)
                           issue_id, author AS executor, ts
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE event_type = 'State change'
                      AND value_to IN ('Ожидание релиза', 'В работе')
                    ORDER BY issue_id, ts DESC NULLS LAST
                ),
                work AS (
                    SELECT issue_id, COALESCE(SUM(minutes), 0) AS minutes
                    FROM {TABLE_YT_ISSUE_WORKLOG}
                    GROUP BY issue_id
                ),
                direction AS (
                    SELECT issue_id, field_value AS direction
                    FROM {TABLE_YT_ISSUE_CUSTOM}
                    WHERE field_name = 'Направление'
                )
            """

            history = conn.execute(
                text(
                    base
                    + """
                    SELECT ro.schema_name, ro.table_name, ro.task_id, ro.release_id,
                           COALESCE(exec.executor, snap.assignee, snap.created_by, 'Не указан') AS executor,
                           snap.created_by AS creator,
                           COALESCE(direction.direction, 'Не указан') AS direction,
                           COALESCE(work.minutes, 0) AS minutes,
                           rel.started_at AS changed_at
                    FROM ro
                    LEFT JOIN snap ON snap.issue_id = ro.task_id
                    LEFT JOIN exec ON exec.issue_id = ro.task_id
                    LEFT JOIN work ON work.issue_id = ro.task_id
                    LEFT JOIN direction ON direction.issue_id = ro.task_id
                    LEFT JOIN rel ON rel.release_id = ro.release_id
                    ORDER BY rel.started_at DESC NULLS LAST
                    """
                ),
                params,
            ).mappings().all()

            summary = {
                "schema": schema,
                "table": table,
                "changes": len(history),
                "hours": round(sum(r["minutes"] for r in history) / 60, 2) if history else 0,
                "last_change": history[0]["changed_at"] if history else None,
            }

            return {"summary": summary, "history": history}
    except Exception as e:
        print("❌ /api/analytics/table error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить аналитику таблицы")


@router.get("/api/analytics/workload")
def get_analytics_workload(
    days: int = Query(30, ge=1, le=3650),
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    group_by: str = "executor",
):
    try:
        date_clause, params = _resolve_date_window(date_from, date_to, days)
        with engine.connect() as conn:
            base = f"""
                WITH rel AS (
                    SELECT r.release_id, r.started_at
                    FROM {TABLE_RELEASE_LOG} r
                    WHERE {date_clause}
                ),
                ro AS (
                    SELECT ro.*
                    FROM {TABLE_RELEASE_OBJECTS} ro
                    JOIN rel r ON r.release_id = ro.release_id
                ),
                tasks AS (
                    SELECT DISTINCT task_id
                    FROM ro
                    WHERE task_id IS NOT NULL
                ),
                snap AS (
                    SELECT s.*
                    FROM {TABLE_YT_ISSUE_SNAPSHOT} s
                    JOIN tasks t ON t.task_id = s.issue_id
                ),
                exec AS (
                    SELECT DISTINCT ON (issue_id)
                           issue_id, author AS executor, ts
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE event_type = 'State change'
                      AND value_to IN ('Ожидание релиза', 'В работе')
                    ORDER BY issue_id, ts DESC NULLS LAST
                ),
                work AS (
                    SELECT issue_id, COALESCE(SUM(minutes), 0) AS minutes
                    FROM {TABLE_YT_ISSUE_WORKLOG}
                    GROUP BY issue_id
                ),
                direction AS (
                    SELECT issue_id, field_value AS direction
                    FROM {TABLE_YT_ISSUE_CUSTOM}
                    WHERE field_name = 'Направление'
                )
            """

            summary = conn.execute(
                text(
                    base
                    + """
                    SELECT
                        COUNT(DISTINCT snap.issue_id) AS tasks_count,
                        COUNT(DISTINCT ro.schema_name || '.' || ro.table_name) AS tables_count,
                        COUNT(DISTINCT COALESCE(exec.executor, snap.assignee, snap.created_by)) AS executors_count,
                        COALESCE(SUM(work.minutes), 0) AS minutes
                    FROM snap
                    LEFT JOIN exec ON exec.issue_id = snap.issue_id
                    LEFT JOIN work ON work.issue_id = snap.issue_id
                    LEFT JOIN direction ON direction.issue_id = snap.issue_id
                    LEFT JOIN ro ON ro.task_id = snap.issue_id
                    """
                ),
                params,
            ).mappings().first()

            group_expr = "COALESCE(exec.executor, snap.assignee, snap.created_by, 'Не указан')"
            label = "executor"
            if group_by == "creator":
                group_expr = "COALESCE(snap.created_by, 'Не указан')"
                label = "creator"
            elif group_by == "direction":
                group_expr = "COALESCE(direction.direction, 'Не указан')"
                label = "direction"

            rows = conn.execute(
                text(
                    base
                    + f"""
                    SELECT {group_expr} AS {label},
                           COUNT(DISTINCT snap.issue_id) AS tasks_count,
                           COUNT(ro.table_name) AS tables_count,
                           COALESCE(SUM(work.minutes), 0) AS minutes,
                           MAX(COALESCE(exec.ts, snap.updated_at, snap.created_at)) AS last_activity
                    FROM snap
                    LEFT JOIN exec ON exec.issue_id = snap.issue_id
                    LEFT JOIN work ON work.issue_id = snap.issue_id
                    LEFT JOIN direction ON direction.issue_id = snap.issue_id
                    LEFT JOIN ro ON ro.task_id = snap.issue_id
                    GROUP BY 1
                    ORDER BY minutes DESC NULLS LAST
                    """
                ),
                params,
            ).mappings().all()
            return {"group_by": group_by, "summary": summary, "items": rows}
    except Exception as e:
        print("❌ /api/analytics/workload error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить нагрузку")


@router.get("/api/analytics/hot-tables")
def get_analytics_hot_tables(
    days: int = Query(90, ge=1, le=3650),
    min_changes: int = Query(3, ge=1, le=1000),
):
    try:
        date_clause, params = _resolve_date_window(None, None, days)
        with engine.connect() as conn:
            base = f"""
                WITH rel AS (
                    SELECT r.release_id, r.started_at
                    FROM {TABLE_RELEASE_LOG} r
                    WHERE {date_clause}
                ),
                ro AS (
                    SELECT ro.*
                    FROM {TABLE_RELEASE_OBJECTS} ro
                    JOIN rel r ON r.release_id = ro.release_id
                ),
                exec AS (
                    SELECT DISTINCT ON (issue_id)
                           issue_id, author AS executor, ts
                    FROM {TABLE_YT_ISSUE_TIMELINE}
                    WHERE event_type = 'State change'
                      AND value_to IN ('Ожидание релиза', 'В работе')
                    ORDER BY issue_id, ts DESC NULLS LAST
                ),
                work AS (
                    SELECT issue_id, COALESCE(SUM(minutes), 0) AS minutes
                    FROM {TABLE_YT_ISSUE_WORKLOG}
                    GROUP BY issue_id
                ),
                last_change AS (
                    SELECT DISTINCT ON (ro.schema_name, ro.table_name)
                           ro.schema_name, ro.table_name, ro.task_id, rel.started_at AS changed_at
                    FROM ro
                    JOIN rel ON rel.release_id = ro.release_id
                    ORDER BY ro.schema_name, ro.table_name, rel.started_at DESC NULLS LAST
                )
            """

            rows = conn.execute(
                text(
                    base
                    + """
                    SELECT ro.schema_name, ro.table_name,
                           COUNT(*) AS changes,
                           COALESCE(SUM(work.minutes), 0) AS minutes,
                           MAX(rel.started_at) AS last_change_at,
                           COALESCE(exec.executor, 'Не указан') AS last_executor
                    FROM ro
                    JOIN rel ON rel.release_id = ro.release_id
                    LEFT JOIN work ON work.issue_id = ro.task_id
                    LEFT JOIN last_change lc ON lc.schema_name = ro.schema_name AND lc.table_name = ro.table_name
                    LEFT JOIN exec ON exec.issue_id = lc.task_id
                    GROUP BY ro.schema_name, ro.table_name, exec.executor
                    HAVING COUNT(*) >= :min_changes
                    ORDER BY changes DESC, minutes DESC
                    LIMIT 50
                    """
                ),
                {"days": days, "min_changes": min_changes},
            ).mappings().all()
            return {"items": rows}
    except Exception as e:
        print("❌ /api/analytics/hot-tables error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось получить hot tables")


@router.get("/api/search")
def search_entities(q: str):
    try:
        q = (q or "").strip()
        if not q:
            return {"releases": [], "tasks": [], "tables": []}
        like = f"%{q}%"
        with engine.connect() as conn:
            releases = conn.execute(
                text(
                    f"""
                    SELECT release_id, started_at, status
                    FROM {TABLE_RELEASE_LOG}
                    WHERE release_id ILIKE :q
                    ORDER BY started_at DESC NULLS LAST
                    LIMIT 20
                    """
                ),
                {"q": like},
            ).mappings().all()

            tasks = conn.execute(
                text(
                    f"""
                    SELECT issue_id, summary, created_by, updated_at, current_state
                    FROM {TABLE_YT_ISSUE_SNAPSHOT}
                    WHERE issue_id ILIKE :q OR summary ILIKE :q
                    ORDER BY updated_at DESC NULLS LAST
                    LIMIT 20
                    """
                ),
                {"q": like},
            ).mappings().all()

            tables = conn.execute(
                text(
                    f"""
                    SELECT DISTINCT schema_name, table_name
                    FROM {TABLE_RELEASE_OBJECTS}
                    WHERE (schema_name || '.' || table_name) ILIKE :q
                       OR table_name ILIKE :q
                    ORDER BY schema_name, table_name
                    LIMIT 40
                    """
                ),
                {"q": like},
            ).mappings().all()

            return {"releases": releases, "tasks": tasks, "tables": tables}
    except Exception as e:
        print("❌ /api/search error:", e)
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Не удалось выполнить поиск")


app.include_router(router)
