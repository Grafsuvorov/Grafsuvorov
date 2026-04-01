from __future__ import annotations

import base64
import hashlib
import json
import os
import subprocess
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any
from urllib import error as urlerror
from urllib import request as urlrequest

import yaml
from sqlalchemy import create_engine, text

REQUIRED_TOP_LEVEL_KEYS = {
    "schema_name_gp",
    "schema_name_click",
    "object_name",
    "object_type",
    "clickhouse_cluster",
    "engine",
    "order_by",
    "load_type",
    "recreate_mode",
    "truncate_mode_on",
    "postgres_conn_id",
    "clickhouse_conn_id",
    "dag_schedule_interval",
    "attributes",
}

REQUIRED_ATTRIBUTE_KEYS = {
    "column_name_click",
    "column_name_gp",
    "data_type_click",
    "data_type_gp",
    "is_nullable",
}

MAPPING_GP_TO_CLICK = {
    "date": "Date32",
    "timestamp": "DateTime",
    "varchar": "String",
    "text": "String",
    "bpchar": "String",
    "numeric": "Decimal(32,10)",
    "decimal": "Decimal(32,10)",
    "int8": "Int64",
    "int4": "Int32",
    "int2": "Int32",
    "int": "Int32",
    "bigint": "Int64",
    "bool": "UInt8",
    "boolean": "UInt8",
    "json": "String",
    "jsonb": "String",
    "time": "String",
    "float8": "Decimal(32,10)",
}


def _resolve_root(base_dir: Path, root_value: str) -> Path:
    root = Path(root_value)
    if not root.is_absolute():
        root = (base_dir / root).resolve()
    return root


def _state_root(base_dir: Path, dev_root_value: str) -> Path:
    return _resolve_root(base_dir, dev_root_value) / ".admin"


def _locks_root(base_dir: Path, dev_root_value: str) -> Path:
    return _state_root(base_dir, dev_root_value) / "locks"


def _audit_log_path(base_dir: Path, dev_root_value: str) -> Path:
    return _state_root(base_dir, dev_root_value) / "audit.jsonl"


def _ensure_state_dirs(base_dir: Path, dev_root_value: str) -> None:
    state_root = _state_root(base_dir, dev_root_value)
    (state_root / "locks").mkdir(parents=True, exist_ok=True)


def _lock_file_path(base_dir: Path, dev_root_value: str, schema_name: str, file_name: str) -> Path:
    return _locks_root(base_dir, dev_root_value) / schema_name / f"{file_name}.json"


def _read_json_file(path: Path) -> dict[str, Any] | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def _prune_expired_locks(base_dir: Path, dev_root_value: str) -> dict[tuple[str, str], dict[str, Any]]:
    _ensure_state_dirs(base_dir, dev_root_value)
    locks: dict[tuple[str, str], dict[str, Any]] = {}
    now = datetime.now()
    for path in _locks_root(base_dir, dev_root_value).rglob("*.json"):
        payload = _read_json_file(path)
        if not payload:
            try:
                path.unlink()
            except OSError:
                pass
            continue
        try:
            expires_at = datetime.fromisoformat(str(payload.get("expires_at") or ""))
        except ValueError:
            expires_at = None
        if not expires_at or expires_at <= now:
            try:
                path.unlink()
            except OSError:
                pass
            continue
        schema_name = str(payload.get("schema_name") or "")
        file_name = str(payload.get("file_name") or "")
        if not schema_name or not file_name:
            continue
        locks[(schema_name, file_name)] = {
            "locked_by": payload.get("locked_by"),
            "locked_at": payload.get("locked_at"),
            "expires_at": payload.get("expires_at"),
        }
    return locks


def _connection_url_for_generator(dev_database_url: str, default_database_url: str) -> str:
    return dev_database_url or default_database_url


def _normalize_click_type(data_type_gp: str) -> str:
    base_type = (data_type_gp or "").split("(", 1)[0].strip().lower()
    if base_type == "numeric":
        if "(" in (data_type_gp or ""):
            return f"Decimal{data_type_gp[data_type_gp.index('('):]}"
        return "Decimal(32,10)"
    return MAPPING_GP_TO_CLICK.get(base_type, "String")


def generate_dev_meta_yaml(
    *,
    database_url: str,
    schema_name_gp: str,
    object_name: str,
    schema_name_click: str,
    order_by: list[str],
    greenplum_table_name: str | None = None,
) -> dict[str, Any]:
    if not database_url:
        raise ValueError("Для генератора нужен DEV_DATABASE_URL или DATABASE_URL")
    if not schema_name_gp.strip() or not object_name.strip():
        raise ValueError("Нужно указать schema_name_gp и object_name")
    if schema_name_click not in {"dm", "dm_view"}:
        raise ValueError("schema_name_click должен быть dm или dm_view")
    if schema_name_click == "dm_view":
        raise ValueError("Автогенерация сейчас поддержана только для dm")
    if not order_by:
        raise ValueError("Укажи хотя бы одну колонку в order_by")

    source_object_name = (greenplum_table_name or object_name).strip()
    engine = create_engine(database_url)
    query = text(
        """
        SELECT
            t.table_type,
            c.column_name,
            c.ordinal_position,
            concat(
                c.udt_name,
                CASE
                    WHEN c.character_maximum_length IS NOT NULL
                        THEN concat('(', c.character_maximum_length, ')')
                    WHEN c.numeric_precision IS NOT NULL AND c.data_type = 'numeric'
                        THEN concat('(', c.numeric_precision, ',', c.numeric_scale, ')')
                    ELSE ''
                END
            ) AS data_type_gp,
            CASE WHEN c.is_nullable = 'YES' THEN true ELSE false END AS is_nullable,
            c.column_default,
            pd.description
        FROM information_schema.columns c
        JOIN information_schema.tables t
          ON t.table_schema = c.table_schema
         AND t.table_name = c.table_name
        LEFT JOIN pg_catalog.pg_statio_all_tables p
          ON c.table_schema = p.schemaname
         AND c.table_name = p.relname
        LEFT JOIN pg_catalog.pg_description pd
          ON c.ordinal_position = pd.objsubid
         AND p.relid = pd.objoid
        WHERE c.table_schema = :schema_name
          AND c.table_name = :table_name
        ORDER BY c.ordinal_position
        """
    )
    with engine.connect() as conn:
        rows = conn.execute(
            query,
            {"schema_name": schema_name_gp.strip(), "table_name": source_object_name},
        ).mappings().all()
    if not rows:
        raise ValueError(f"Объект {schema_name_gp}.{source_object_name} не найден")

    column_names = [str(row["column_name"]) for row in rows]
    missing_order_by = [name for name in order_by if name not in column_names]
    if missing_order_by:
        raise ValueError(f"Колонки из order_by не найдены: {', '.join(missing_order_by)}")

    object_type = "table"
    first_type = str(rows[0]["table_type"] or "").upper()
    if "VIEW" in first_type:
        object_type = "view"

    attributes: list[dict[str, Any]] = []
    for row in rows:
        column_name = str(row["column_name"])
        data_type_gp = str(row["data_type_gp"] or "")
        attr = {
            "column_name_click": column_name,
            "column_name_gp": column_name,
            "data_type_click": _normalize_click_type(data_type_gp),
            "data_type_gp": data_type_gp,
            "is_nullable": "NULL" if bool(row["is_nullable"]) and column_name not in order_by else "NOT NULL",
            "description": (row["description"] or "Комментария нет").replace("\n", " "),
        }
        if row["column_default"]:
            attr["default"] = str(row["column_default"])
        attributes.append(attr)

    payload: dict[str, Any] = {
        "schema_name_gp": schema_name_gp.strip(),
        "schema_name_click": schema_name_click.strip(),
        "object_name": object_name.strip(),
        "object_type": object_type,
        "clickhouse_cluster": "{cluster}",
        "engine": "ReplicatedMergeTree",
        "order_by": order_by,
        "partitions": None,
        "table_settings": "index_granularity = 8192",
        "table_comment": None,
        "settings_external_table": {
            "max_threads": 20,
            "max_insert_threads": 20,
            "input_format_parallel_parsing": 0,
        },
        "load_type": "full",
        "recreate_mode": "drop_create",
        "truncate_mode_on": object_name.strip() != "account_turnover",
        "postgres_conn_id": "gp_connection",
        "clickhouse_conn_id": "clickhouse",
        "dag_name": None,
        "dag_schedule_interval": {
            "PROD": None,
            "DEV": None,
        },
        "dag_tags": [],
        "task_pool": "dm_pool",
        "task_pool_slots": 1,
        "attributes": attributes,
    }
    if greenplum_table_name and greenplum_table_name.strip() != object_name.strip():
        payload["greenplum_table_name"] = greenplum_table_name.strip()

    file_name = f"{schema_name_gp.strip()}_{object_name.strip()}_meta.yaml"
    content = yaml.dump(
        payload,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
        width=float("inf"),
    )
    return {
        "file_name": file_name,
        "content": content,
        "payload": payload,
    }


def list_meta_files(root: Path, schema_name: str) -> list[dict[str, Any]]:
    schema_dir = root / schema_name
    if not schema_dir.exists():
        return []
    result: list[dict[str, Any]] = []
    for path in sorted(schema_dir.iterdir()):
        if not path.is_file():
            continue
        stat = path.stat()
        result.append(
            {
                "file_name": path.name,
                "updated_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "size": stat.st_size,
            }
        )
    return result


def _get_active_locks(base_dir: Path, dev_root_value: str) -> dict[tuple[str, str], dict[str, Any]]:
    return _prune_expired_locks(base_dir, dev_root_value)


def _get_last_audit_map(base_dir: Path, dev_root_value: str, schema_name: str) -> dict[str, dict[str, Any]]:
    audit_path = _audit_log_path(base_dir, dev_root_value)
    if not audit_path.exists():
        return {}
    latest: dict[str, dict[str, Any]] = {}
    try:
        for line in audit_path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            if row.get("schema_name") != schema_name:
                continue
            file_name = str(row.get("file_name") or "")
            if not file_name:
                continue
            created_at = str(row.get("created_at") or "")
            current = latest.get(file_name)
            if not current or created_at >= str(current.get("last_action_at") or ""):
                latest[file_name] = {
                    "last_action_by": row.get("author"),
                    "last_action": row.get("action"),
                    "last_action_at": created_at,
                }
    except Exception:
        return {}
    return latest


def get_dev_meta_status(
    *,
    engine,
    base_dir: Path,
    prod_root_value: str,
    dev_root_value: str,
    airflow_base_url: str,
    airflow_dag_id: str,
    lock_ttl_minutes: int,
    dev_database_url: str,
    deploy_host: str,
    deploy_user: str,
    deploy_base_dir: str,
) -> dict[str, Any]:
    dev_root = _resolve_root(base_dir, dev_root_value)
    locks = _get_active_locks(base_dir, dev_root_value)
    return {
        "dev_root": str(dev_root),
        "airflow": {
            "base_url": airflow_base_url,
            "dag_id": airflow_dag_id,
            "configured": bool(airflow_base_url),
        },
        "deploy": {
            "host": deploy_host,
            "user": deploy_user,
            "base_dir": deploy_base_dir,
            "configured": bool(deploy_host and deploy_user and deploy_base_dir),
        },
        "dev_database_configured": bool(dev_database_url),
        "locks_count": len(locks),
        "lock_ttl_minutes": lock_ttl_minutes,
    }


def get_dev_meta_files(
    *,
    engine,
    base_dir: Path,
    prod_root_value: str,
    dev_root_value: str,
    schema_name: str,
) -> dict[str, Any]:
    dev_root = _resolve_root(base_dir, dev_root_value)
    locks = _get_active_locks(base_dir, dev_root_value)
    audit_map = _get_last_audit_map(base_dir, dev_root_value, schema_name)
    dev_files = list_meta_files(dev_root, schema_name)
    for file_row in dev_files:
        file_row.update(audit_map.get(file_row["file_name"], {}))
    return {
        "schema_name": schema_name,
        "dev_files": dev_files,
        "locks": [
            {"schema_name": key[0], "file_name": key[1], **value}
            for key, value in locks.items()
            if key[0] == schema_name
        ],
    }


def read_dev_meta_file(*, base_dir: Path, root_value: str, schema_name: str, file_name: str) -> dict[str, Any]:
    root = _resolve_root(base_dir, root_value)
    path = root / schema_name / file_name
    if not path.exists() or not path.is_file():
        raise FileNotFoundError(str(path))
    return {
        "schema_name": schema_name,
        "file_name": file_name,
        "content": path.read_text(encoding="utf-8"),
        "updated_at": datetime.fromtimestamp(path.stat().st_mtime).isoformat(),
        "path": str(path),
    }


def acquire_dev_meta_lock(
    *,
    engine,
    base_dir: Path,
    dev_root_value: str,
    schema_name: str,
    file_name: str,
    author: str,
    ttl_minutes: int,
) -> dict[str, Any]:
    locks = _prune_expired_locks(base_dir, dev_root_value)
    current = locks.get((schema_name, file_name))
    if current and current.get("locked_by") != author:
        raise PermissionError(f"Файл уже редактирует {current['locked_by']}")
    now = datetime.now()
    expires_at = now + timedelta(minutes=ttl_minutes)
    lock_path = _lock_file_path(base_dir, dev_root_value, schema_name, file_name)
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_path.write_text(
        json.dumps(
            {
                "schema_name": schema_name,
                "file_name": file_name,
                "locked_by": author,
                "locked_at": now.isoformat(),
                "expires_at": expires_at.isoformat(),
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    return {
        "schema_name": schema_name,
        "file_name": file_name,
        "locked_by": author,
        "locked_at": now.isoformat(),
        "expires_at": expires_at.isoformat(),
    }


def release_dev_meta_lock(
    *,
    engine,
    base_dir: Path,
    dev_root_value: str,
    schema_name: str,
    file_name: str,
    author: str,
) -> None:
    lock_path = _lock_file_path(base_dir, dev_root_value, schema_name, file_name)
    if not lock_path.exists():
        return
    payload = _read_json_file(lock_path) or {}
    if payload.get("locked_by") != author:
        return
    try:
        lock_path.unlink()
    except OSError:
        pass


def assert_dev_meta_lock_owner(
    *,
    engine,
    base_dir: Path,
    dev_root_value: str,
    schema_name: str,
    file_name: str,
    author: str,
) -> None:
    locks = _prune_expired_locks(base_dir, dev_root_value)
    row = locks.get((schema_name, file_name))
    if not row:
        raise PermissionError("Перед сохранением возьмите файл в работу")
    if row["locked_by"] != author:
        raise PermissionError(f"Файл уже редактирует {row['locked_by']}")


def _validate_yaml_structure(payload: Any, schema_name: str) -> list[str]:
    errors: list[str] = []
    if schema_name == "dm_view":
        if not isinstance(payload, str):
            errors.append("Для dm_view ожидается текст SQL")
            return errors
        sql = payload.strip()
        if not sql:
            errors.append("SQL для dm_view не должен быть пустым")
            return errors
        lowered = sql.lower()
        if "select" not in lowered:
            errors.append("В SQL для dm_view не найден SELECT")
        return errors
    if not isinstance(payload, dict):
        return ["Корневой YAML должен быть объектом"]
    missing_top = sorted(REQUIRED_TOP_LEVEL_KEYS - set(payload.keys()))
    if missing_top:
        errors.append(f"Отсутствуют обязательные поля: {', '.join(missing_top)}")
    attrs = payload.get("attributes")
    if not isinstance(attrs, list) or not attrs:
        errors.append("Поле attributes должно быть непустым списком")
    else:
        for idx, item in enumerate(attrs, start=1):
            if not isinstance(item, dict):
                errors.append(f"attributes[{idx}] должен быть объектом")
                continue
            missing_attr = sorted(REQUIRED_ATTRIBUTE_KEYS - set(item.keys()))
            if missing_attr:
                errors.append(
                    f"attributes[{idx}] отсутствуют поля: {', '.join(missing_attr)}"
                )
    order_by = payload.get("order_by")
    if not isinstance(order_by, list) or not order_by:
        errors.append("order_by должен быть непустым списком")
    schedule = payload.get("dag_schedule_interval")
    if not isinstance(schedule, dict):
        errors.append("dag_schedule_interval должен быть объектом")
    schema_click = str(payload.get("schema_name_click") or "").strip()
    if schema_click and schema_click not in {"dm", "dm_view"}:
        errors.append("schema_name_click должен быть dm или dm_view")
    return errors


def _validate_gp_object(payload: dict[str, Any], dev_database_url: str) -> str | None:
    if not dev_database_url:
        return None
    schema_gp = str(payload.get("schema_name_gp") or "").strip()
    object_name = str(payload.get("greenplum_table_name") or payload.get("object_name") or "").strip()
    if not schema_gp or not object_name:
        return None
    dev_engine = create_engine(dev_database_url)
    try:
        with dev_engine.connect() as conn:
            exists = conn.execute(
                text(
                    """
                    SELECT 1
                    FROM information_schema.tables
                    WHERE table_schema = :schema_name
                      AND table_name = :table_name
                    LIMIT 1
                    """
                ),
                {"schema_name": schema_gp, "table_name": object_name},
            ).scalar()
        if not exists:
            return f"Объект {schema_gp}.{object_name} не найден в DEV Greenplum"
    except Exception as exc:
        return f"Не удалось проверить DEV Greenplum: {exc}"
    return None


def validate_dev_meta_content(
    *,
    content: str,
    schema_name: str,
    dev_database_url: str,
) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    parsed: Any = content
    if schema_name == "dm":
        try:
            parsed = yaml.safe_load(content) or {}
        except Exception as exc:
            return {"valid": False, "errors": [f"YAML не распарсился: {exc}"], "warnings": []}
    errors.extend(_validate_yaml_structure(parsed, schema_name))
    if schema_name == "dm" and isinstance(parsed, dict):
        gp_error = _validate_gp_object(parsed, dev_database_url)
        if gp_error:
            errors.append(gp_error)
        nullable_order_by = [
            item.get("column_name_click")
            for item in parsed.get("attributes", [])
            if item.get("column_name_click") in (parsed.get("order_by") or [])
            and str(item.get("is_nullable") or "").upper() == "NULL"
        ]
        if nullable_order_by:
            warnings.append(
                f"Колонки из order_by помечены как NULL: {', '.join(nullable_order_by)}"
            )
    return {"valid": not errors, "errors": errors, "warnings": warnings}


def _audit_dev_meta(
    engine,
    base_dir: Path,
    dev_root_value: str,
    schema_name: str,
    file_name: str,
    author: str,
    action: str,
    content: str,
    details: dict[str, Any],
) -> None:
    yaml_hash = hashlib.sha256(content.encode("utf-8")).hexdigest() if content else None
    _ensure_state_dirs(base_dir, dev_root_value)
    audit_path = _audit_log_path(base_dir, dev_root_value)
    record = {
        "schema_name": schema_name,
        "file_name": file_name,
        "action": action,
        "author": author,
        "yaml_hash": yaml_hash,
        "details": details,
        "created_at": datetime.now().isoformat(),
    }
    with audit_path.open("a", encoding="utf-8") as audit_file:
        audit_file.write(json.dumps(record, ensure_ascii=False) + "\n")


def save_dev_meta_file(
    *,
    engine,
    base_dir: Path,
    dev_root_value: str,
    schema_name: str,
    file_name: str,
    content: str,
    author: str,
    dev_database_url: str,
) -> dict[str, Any]:
    assert_dev_meta_lock_owner(
        engine=engine,
        base_dir=base_dir,
        dev_root_value=dev_root_value,
        schema_name=schema_name,
        file_name=file_name,
        author=author,
    )
    validation = validate_dev_meta_content(content=content, schema_name=schema_name, dev_database_url=dev_database_url)
    if not validation["valid"]:
        raise ValueError("; ".join(validation["errors"]))
    root = _resolve_root(base_dir, dev_root_value)
    target_dir = root / schema_name
    target_dir.mkdir(parents=True, exist_ok=True)
    path = target_dir / file_name
    path.write_text(content, encoding="utf-8")
    _audit_dev_meta(
        engine,
        base_dir=base_dir,
        dev_root_value=dev_root_value,
        schema_name=schema_name,
        file_name=file_name,
        author=author,
        action="save",
        content=content,
        details={"path": str(path), "warnings": validation["warnings"]},
    )
    return {
        "path": str(path),
        "validation": validation,
    }


def _build_ssh_base_command(
    *,
    port: int,
    ssh_key_path: str,
    password: str,
    strict_host_key: str,
) -> list[str]:
    cmd = ["ssh"]
    if password:
        cmd = ["sshpass", "-p", password] + cmd
    if port:
        cmd.extend(["-p", str(port)])
    if ssh_key_path:
        cmd.extend(["-i", ssh_key_path])
    strict_enabled = str(strict_host_key).strip().lower() in {"1", "true", "yes", "on"}
    if not strict_enabled:
        cmd.extend(
            [
                "-o",
                "StrictHostKeyChecking=no",
                "-o",
                "UserKnownHostsFile=/dev/null",
            ]
        )
    return cmd


def _build_scp_base_command(
    *,
    port: int,
    ssh_key_path: str,
    password: str,
    strict_host_key: str,
) -> list[str]:
    cmd = ["scp"]
    if password:
        cmd = ["sshpass", "-p", password] + cmd
    if port:
        cmd.extend(["-P", str(port)])
    if ssh_key_path:
        cmd.extend(["-i", ssh_key_path])
    strict_enabled = str(strict_host_key).strip().lower() in {"1", "true", "yes", "on"}
    if not strict_enabled:
        cmd.extend(
            [
                "-o",
                "StrictHostKeyChecking=no",
                "-o",
                "UserKnownHostsFile=/dev/null",
            ]
        )
    return cmd


def deploy_dev_meta_file(
    *,
    engine,
    base_dir: Path,
    dev_root_value: str,
    schema_name: str,
    file_name: str,
    content: str,
    author: str,
    dev_database_url: str,
    host: str,
    port: int,
    user: str,
    password: str,
    remote_base_dir: str,
    ssh_key_path: str,
    strict_host_key: str,
) -> dict[str, Any]:
    if not host or not user or not remote_base_dir:
        raise ValueError("Не настроен deploy на DEV сервер")

    saved = save_dev_meta_file(
        engine=engine,
        base_dir=base_dir,
        dev_root_value=dev_root_value,
        schema_name=schema_name,
        file_name=file_name,
        content=content,
        author=author,
        dev_database_url=dev_database_url,
    )

    remote_dir = f"{remote_base_dir.rstrip('/')}/{schema_name}"
    remote_path = f"{remote_dir}/{file_name}"
    ssh_target = f"{user}@{host}"
    ssh_cmd = _build_ssh_base_command(
        port=port,
        ssh_key_path=ssh_key_path,
        password=password,
        strict_host_key=strict_host_key,
    )
    scp_cmd = _build_scp_base_command(
        port=port,
        ssh_key_path=ssh_key_path,
        password=password,
        strict_host_key=strict_host_key,
    )

    try:
        subprocess.run(
            ssh_cmd + [ssh_target, f"mkdir -p {remote_dir}"],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except subprocess.CalledProcessError as exc:
        raise ValueError(exc.stderr.strip() or exc.stdout.strip() or "Не удалось создать папку на DEV сервере") from exc
    except Exception as exc:
        raise ValueError(f"Не удалось подключиться к DEV серверу: {exc}") from exc

    temp_path: str | None = None
    try:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as temp_file:
            temp_file.write(content)
            temp_path = temp_file.name
        subprocess.run(
            scp_cmd + [temp_path, f"{ssh_target}:{remote_path}"],
            check=True,
            capture_output=True,
            text=True,
            timeout=60,
        )
        subprocess.run(
            ssh_cmd + [ssh_target, f"test -f {remote_path}"],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except subprocess.CalledProcessError as exc:
        raise ValueError(exc.stderr.strip() or exc.stdout.strip() or "Не удалось передать файл на DEV сервер") from exc
    except Exception as exc:
        raise ValueError(f"Не удалось отправить файл на DEV сервер: {exc}") from exc
    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                pass

    _audit_dev_meta(
        engine,
        base_dir=base_dir,
        dev_root_value=dev_root_value,
        schema_name=schema_name,
        file_name=file_name,
        author=author,
        action="deploy",
        content=content,
        details={
            "host": host,
            "port": port,
            "remote_dir": remote_dir,
            "remote_path": remote_path,
            "local_path": saved["path"],
        },
    )
    return {
        "path": saved["path"],
        "remote_path": remote_path,
        "validation": saved["validation"],
    }


def _dag_id_from_file_name(file_name: str) -> str:
    path = Path(file_name)
    dag_id = path.stem.strip()
    if not dag_id:
        raise ValueError("Не удалось определить dag_id из имени файла")
    return dag_id


def _urlopen_without_proxy(req: urlrequest.Request, timeout: int):
    opener = urlrequest.build_opener(urlrequest.ProxyHandler({}))
    return opener.open(req, timeout=timeout)


def _airflow_json_request(
    *,
    url: str,
    username: str,
    password: str,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
    timeout: int = 30,
) -> dict[str, Any]:
    req = urlrequest.Request(
        url,
        data=json.dumps(payload).encode("utf-8") if payload is not None else None,
        headers={"Content-Type": "application/json"},
        method=method,
    )
    if username or password:
        raw = f"{username}:{password}".encode("utf-8")
        req.add_header("Authorization", f"Basic {base64.b64encode(raw).decode('utf-8')}")
    try:
        with _urlopen_without_proxy(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8")
            return json.loads(body) if body else {}
    except urlerror.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise ValueError(f"Airflow вернул {exc.code}: {body}") from exc
    except Exception as exc:
        raise ValueError(f"Не удалось вызвать Airflow: {exc}") from exc


def trigger_airflow_dev_dag(
    *,
    engine,
    base_dir: Path,
    dev_root_value: str,
    airflow_base_url: str,
    dag_id: str,
    username: str,
    password: str,
    schema_name: str,
    file_name: str,
    author: str,
    remote_base_dir: str,
) -> dict[str, Any]:
    if not airflow_base_url:
        raise ValueError("Airflow DEV не настроен")
    resolved_dag_id = dag_id or _dag_id_from_file_name(file_name)
    remote_path = f"{remote_base_dir.rstrip('/')}/{schema_name}/{file_name}" if remote_base_dir else None
    payload = {
        "conf": {
            "schema_name": schema_name,
            "file_name": file_name,
            "author": author,
            "remote_path": remote_path,
            "dev_bypass_dm_sensor": True,
        }
    }
    url = f"{airflow_base_url.rstrip('/')}/api/v1/dags/{resolved_dag_id}/dagRuns"
    data = _airflow_json_request(
        url=url,
        username=username,
        password=password,
        method="POST",
        payload=payload,
        timeout=30,
    )
    _audit_dev_meta(
        engine,
        base_dir=base_dir,
        dev_root_value=dev_root_value,
        schema_name=schema_name,
        file_name=file_name,
        author=author,
        action="run_dag",
        content="",
        details={"url": url, "response": data, "dag_id": resolved_dag_id, "remote_path": remote_path},
    )
    return {"dag_id": resolved_dag_id, "response": data, "remote_path": remote_path}


def get_airflow_dev_dag_status(
    *,
    airflow_base_url: str,
    username: str,
    password: str,
    dag_id: str,
    dag_run_id: str,
    highlight_task_ids: list[str] | None = None,
) -> dict[str, Any]:
    if not airflow_base_url:
        raise ValueError("Airflow DEV не настроен")
    if not dag_id or not dag_run_id:
        raise ValueError("Нужно указать dag_id и dag_run_id")
    run_url = f"{airflow_base_url.rstrip('/')}/api/v1/dags/{dag_id}/dagRuns/{dag_run_id}"
    task_url = f"{airflow_base_url.rstrip('/')}/api/v1/dags/{dag_id}/dagRuns/{dag_run_id}/taskInstances"
    run_data = _airflow_json_request(
        url=run_url,
        username=username,
        password=password,
        timeout=20,
    )
    task_data = _airflow_json_request(
        url=task_url,
        username=username,
        password=password,
        timeout=20,
    )
    task_instances = task_data.get("task_instances") or []
    highlight = set(highlight_task_ids or ["dm_sensor"])
    highlight_tasks = [
        {
            "task_id": task.get("task_id"),
            "state": task.get("state"),
            "start_date": task.get("start_date"),
            "end_date": task.get("end_date"),
        }
        for task in task_instances
        if task.get("task_id") in highlight
    ]
    failed_tasks = [
        {
            "task_id": task.get("task_id"),
            "state": task.get("state"),
        }
        for task in task_instances
        if task.get("state") in {"failed", "upstream_failed"}
    ]
    return {
        "dag_id": dag_id,
        "dag_run_id": dag_run_id,
        "dag_run_state": run_data.get("state"),
        "logical_date": run_data.get("logical_date"),
        "run_type": run_data.get("run_type"),
        "highlight_tasks": highlight_tasks,
        "failed_tasks": failed_tasks,
    }
