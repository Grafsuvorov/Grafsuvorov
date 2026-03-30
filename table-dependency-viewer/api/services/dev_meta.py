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


LOCK_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS tech_etl.app_dev_meta_lock (
    schema_name TEXT NOT NULL,
    file_name TEXT NOT NULL,
    locked_by TEXT NOT NULL,
    locked_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL
)
DISTRIBUTED RANDOMLY
"""

AUDIT_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS tech_etl.app_dev_meta_audit (
    schema_name TEXT NOT NULL,
    file_name TEXT NOT NULL,
    action TEXT NOT NULL,
    author TEXT NOT NULL,
    yaml_hash TEXT,
    details TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
)
DISTRIBUTED RANDOMLY
"""

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


def _resolve_root(base_dir: Path, root_value: str) -> Path:
    root = Path(root_value)
    if not root.is_absolute():
        root = (base_dir / root).resolve()
    return root


def ensure_dev_meta_tables(engine) -> None:
    with engine.begin() as conn:
        try:
            conn.execute(text(LOCK_TABLE_SQL))
        except Exception:
            pass
        try:
            conn.execute(text(AUDIT_TABLE_SQL))
        except Exception:
            pass


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


def _get_active_locks(engine) -> dict[tuple[str, str], dict[str, Any]]:
    ensure_dev_meta_tables(engine)
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM tech_etl.app_dev_meta_lock WHERE expires_at <= NOW()"))
        rows = conn.execute(
            text(
                """
                SELECT schema_name, file_name, locked_by, locked_at, expires_at
                FROM tech_etl.app_dev_meta_lock
                """
            )
        ).mappings().all()
    return {
        (row["schema_name"], row["file_name"]): {
            "locked_by": row["locked_by"],
            "locked_at": row["locked_at"].isoformat() if row["locked_at"] else None,
            "expires_at": row["expires_at"].isoformat() if row["expires_at"] else None,
        }
        for row in rows
    }


def _get_last_audit_map(engine, schema_name: str) -> dict[str, dict[str, Any]]:
    ensure_dev_meta_tables(engine)
    with engine.begin() as conn:
        rows = conn.execute(
            text(
                """
                SELECT schema_name, file_name, author, action, created_at
                FROM (
                    SELECT
                        schema_name,
                        file_name,
                        author,
                        action,
                        created_at,
                        ROW_NUMBER() OVER (
                            PARTITION BY schema_name, file_name
                            ORDER BY created_at DESC
                        ) AS rn
                    FROM tech_etl.app_dev_meta_audit
                    WHERE schema_name = :schema_name
                ) t
                WHERE rn = 1
                """
            ),
            {"schema_name": schema_name},
        ).mappings().all()
    return {
        row["file_name"]: {
            "last_action_by": row["author"],
            "last_action": row["action"],
            "last_action_at": row["created_at"].isoformat() if row["created_at"] else None,
        }
        for row in rows
    }


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
    prod_root = _resolve_root(base_dir, prod_root_value)
    dev_root = _resolve_root(base_dir, dev_root_value)
    locks = _get_active_locks(engine)
    return {
        "prod_root": str(prod_root),
        "dev_root": str(dev_root),
        "airflow": {
            "base_url": airflow_base_url,
            "dag_id": airflow_dag_id,
            "configured": bool(airflow_base_url and airflow_dag_id),
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
    prod_root = _resolve_root(base_dir, prod_root_value)
    dev_root = _resolve_root(base_dir, dev_root_value)
    locks = _get_active_locks(engine)
    audit_map = _get_last_audit_map(engine, schema_name)
    prod_files = list_meta_files(prod_root, schema_name)
    dev_files = list_meta_files(dev_root, schema_name)
    for file_row in prod_files:
        file_row.update(audit_map.get(file_row["file_name"], {}))
    for file_row in dev_files:
        file_row.update(audit_map.get(file_row["file_name"], {}))
    return {
        "schema_name": schema_name,
        "prod_files": prod_files,
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
    schema_name: str,
    file_name: str,
    author: str,
    ttl_minutes: int,
) -> dict[str, Any]:
    ensure_dev_meta_tables(engine)
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM tech_etl.app_dev_meta_lock WHERE expires_at <= NOW()"))
        row = conn.execute(
            text(
                """
                SELECT locked_by, expires_at
                FROM tech_etl.app_dev_meta_lock
                WHERE schema_name = :schema_name AND file_name = :file_name
                """
            ),
            {"schema_name": schema_name, "file_name": file_name},
        ).mappings().first()
        if row and row["locked_by"] != author:
            raise PermissionError(f"Файл уже редактирует {row['locked_by']}")
        conn.execute(
            text(
                """
                DELETE FROM tech_etl.app_dev_meta_lock
                WHERE schema_name = :schema_name AND file_name = :file_name
                """
            ),
            {"schema_name": schema_name, "file_name": file_name},
        )
        now = datetime.now()
        expires_at = now + timedelta(minutes=ttl_minutes)
        conn.execute(
            text(
                """
                INSERT INTO tech_etl.app_dev_meta_lock (schema_name, file_name, locked_by, locked_at, expires_at)
                VALUES (:schema_name, :file_name, :locked_by, :locked_at, :expires_at)
                """
            ),
            {
                "schema_name": schema_name,
                "file_name": file_name,
                "locked_by": author,
                "locked_at": now,
                "expires_at": expires_at,
            },
        )
    return {
        "schema_name": schema_name,
        "file_name": file_name,
        "locked_by": author,
        "expires_at": expires_at.isoformat(),
    }


def release_dev_meta_lock(*, engine, schema_name: str, file_name: str, author: str) -> None:
    ensure_dev_meta_tables(engine)
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                DELETE FROM tech_etl.app_dev_meta_lock
                WHERE schema_name = :schema_name
                  AND file_name = :file_name
                  AND locked_by = :locked_by
                """
            ),
            {
                "schema_name": schema_name,
                "file_name": file_name,
                "locked_by": author,
            },
        )


def assert_dev_meta_lock_owner(*, engine, schema_name: str, file_name: str, author: str) -> None:
    ensure_dev_meta_tables(engine)
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM tech_etl.app_dev_meta_lock WHERE expires_at <= NOW()"))
        row = conn.execute(
            text(
                """
                SELECT locked_by
                FROM tech_etl.app_dev_meta_lock
                WHERE schema_name = :schema_name
                  AND file_name = :file_name
                """
            ),
            {"schema_name": schema_name, "file_name": file_name},
        ).mappings().first()
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
    schema_name: str,
    file_name: str,
    author: str,
    action: str,
    content: str,
    details: dict[str, Any],
) -> None:
    ensure_dev_meta_tables(engine)
    yaml_hash = hashlib.sha256(content.encode("utf-8")).hexdigest() if content else None
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO tech_etl.app_dev_meta_audit (schema_name, file_name, action, author, yaml_hash, details)
                VALUES (:schema_name, :file_name, :action, :author, :yaml_hash, :details)
                """
            ),
            {
                "schema_name": schema_name,
                "file_name": file_name,
                "action": action,
                "author": author,
                "yaml_hash": yaml_hash,
                "details": json.dumps(details, ensure_ascii=False),
            },
        )


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
    strict_host_key: str,
) -> list[str]:
    cmd = ["ssh"]
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
    strict_host_key: str,
) -> list[str]:
    cmd = ["scp"]
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
        strict_host_key=strict_host_key,
    )
    scp_cmd = _build_scp_base_command(
        port=port,
        ssh_key_path=ssh_key_path,
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


def trigger_airflow_dev_dag(
    *,
    engine,
    airflow_base_url: str,
    dag_id: str,
    username: str,
    password: str,
    schema_name: str,
    file_name: str,
    author: str,
) -> dict[str, Any]:
    if not airflow_base_url or not dag_id:
        raise ValueError("Airflow DEV не настроен")
    payload = {
        "conf": {
            "schema_name": schema_name,
            "file_name": file_name,
            "author": author,
        }
    }
    url = f"{airflow_base_url.rstrip('/')}/api/v1/dags/{dag_id}/dagRuns"
    req = urlrequest.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    if username or password:
        raw = f"{username}:{password}".encode("utf-8")
        req.add_header("Authorization", f"Basic {base64.b64encode(raw).decode('utf-8')}")
    try:
        with urlrequest.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8")
            data = json.loads(body) if body else {}
    except urlerror.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise ValueError(f"Airflow вернул {exc.code}: {body}") from exc
    except Exception as exc:
        raise ValueError(f"Не удалось вызвать Airflow: {exc}") from exc
    _audit_dev_meta(
        engine,
        schema_name=schema_name,
        file_name=file_name,
        author=author,
        action="run_dag",
        content="",
        details={"url": url, "response": data},
    )
    return data
