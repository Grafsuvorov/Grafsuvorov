"""Publish Prototype Review SQL, registry and technical DQ to dbt GitLab."""

import os
import re
from typing import Any, Optional
from urllib import parse as urlparse

from .entity_dev_meta import _gitlab_json_request, _parse_gitlab_project
from .gitlab_delivery import file_content, resource_exists
from .prototype_review import build_review_execution_plan, infer_removed_table_targets
from .prototype_review_variants import validate_common_variant_settings, entity_names
from .prototype_review_dbt import (
    build_duplicates_model,
    build_nulls_model,
    build_registry_yaml,
    dbt_duplicates_path,
    dbt_model_sql_path,
    dbt_variant_sql_path,
    dbt_nulls_path,
    dbt_registry_path,
    update_duplicates_model,
)


def publish_dbt_registry(
    *,
    task_id: str,
    author: str,
    review_items: list[dict[str, Any]],
    changed_files: Optional[list[dict[str, Any]]] = None,
    deleted_files: Optional[list[dict[str, Any]]] = None,
    mode: str = "khd",
    gitlab_project: Optional[str] = None,
    gitlab_token: Optional[str] = None,
    gitlab_api_url: Optional[str] = None,
    gitlab_ssl_verify: bool = True,
) -> dict[str, Any]:
    task_id_norm = str(task_id or "").strip().upper()
    if not re.fullmatch(r"[A-Z][A-Z0-9_]*-\d+" if mode == "ohd" else r"DWH-\d+", task_id_norm):
        raise ValueError("Некорректный номер задачи YouTrack ОХД" if mode == "ohd"
                         else "Номер задачи для dbt MR должен быть в формате DWH-12345")
    if mode == "ohd" and (not gitlab_project or not gitlab_token or not gitlab_api_url):
        raise ValueError("Для ОХД не настроен отдельный GitLab API/project/token")
    token = gitlab_token if mode == "ohd" else os.getenv("DBT_GITLAB_TOKEN", "")
    project_ref = _parse_gitlab_project(gitlab_project if mode == "ohd" else os.getenv("DBT_GITLAB_PROJECT", "dwh/dbt"))
    if not token:
        raise ValueError("Не настроен DBT_GITLAB_TOKEN")
    if not project_ref:
        raise ValueError("Не настроен DBT_GITLAB_PROJECT")

    dbt_files: dict[str, dict[str, Any]] = {}
    sql_review_targets = [
        {
            **item,
            "execution_paths": item.get("execution_paths") or item.get("paths") or [item.get("path")],
            # Publication is independent of whether SQL was executed in DEV.
            "skip_dev_execution": False,
        }
        for item in review_items
        if not item.get("is_clickhouse_view") and not item.get("source_load_sql")
    ]
    sql_by_target = {
        str(plan_item.get("item_id") or plan_item.get("target_fqn") or "").strip().lower(): str(plan_item.get("sql_text") or "").strip()
        for plan_item in build_review_execution_plan(
            files=changed_files or [],
            review_targets=sql_review_targets,
            parse_dependencies=mode != "ohd",
        )
        if str(plan_item.get("target_fqn") or "").strip()
    }
    sql_by_target.update({str(item.get("item_id") or item.get("target_fqn")).lower(): item["source_load_sql"]
                          for item in review_items if item.get("source_load_sql")})
    # A physical table has one DQ registry; algorithms keep separate SQL files.
    merged_entities = {}
    validate_common_variant_settings(review_items)
    for item in review_items:
        fqn = str(item.get("target_fqn") or "").lower()
        if item.get("sql_variant_mode") != "separate":
            continue
        values = item.get("entity_names") or str(item.get("entity_name") or "").split(",")
        merged_entities.setdefault(fqn, [])
        for name in values:
            name = str(name).strip()
            if name and name not in merged_entities[fqn]:
                merged_entities[fqn].append(name)
    active_targets: set[str] = set()
    for item in review_items:
        object_type = str(item.get("object_type") or "TABLE").strip().upper()
        if object_type not in {"TABLE", "VIEW"} or item.get("is_clickhouse_view"):
            continue
        target_fqn = str(item.get("target_fqn") or "").strip()
        if "." not in target_fqn:
            continue
        schema_name, table_name = target_fqn.split(".", 1)
        active_targets.add(target_fqn.lower())
        model_sql_path = (dbt_variant_sql_path(schema_name, table_name, entity_names(item.get("entity_name"))[0])
                          if item.get("sql_variant_mode") == "separate" else dbt_model_sql_path(schema_name, table_name))
        model_sql = sql_by_target.get(str(item.get("item_id") or target_fqn).lower())
        if object_type == "VIEW" and not model_sql:
            raise ValueError(f"Не найден SQL представления `{target_fqn}` для публикации в dbt")
        if model_sql:
            dbt_files[model_sql_path] = {"target_fqn": target_fqn, "file_path": model_sql_path, "file_kind": "model_sql", "content": model_sql + "\n"}
        if object_type == "VIEW":
            continue
        registry_path = dbt_registry_path(schema_name, table_name)
        duplicates_path = dbt_duplicates_path(schema_name, table_name)
        dbt_files[registry_path] = {"target_fqn": target_fqn, "file_path": registry_path, "file_kind": "registry", "content": build_registry_yaml({**item, "entity_names": merged_entities.get(target_fqn.lower()) or item.get("entity_names")})}
        dbt_files[duplicates_path] = {"target_fqn": target_fqn, "file_path": duplicates_path, "file_kind": "dq_model", "key_attributes": item.get("key_attributes") or []}
        null_conditions = [str(value).strip() for value in (item.get("null_conditions") or []) if str(value).strip()]
        nulls_path = dbt_nulls_path(schema_name, table_name)
        dbt_files[nulls_path] = {"target_fqn": target_fqn, "file_path": nulls_path, "file_kind": "nulls_model", "null_conditions": null_conditions}

    deleted_targets = infer_removed_table_targets(files=changed_files or [], deleted_files=deleted_files or [], active_targets=active_targets)
    if not dbt_files and not deleted_targets:
        return {"status": "skipped", "reason": "В review нет SQL, registry или DQ для публикации", "files": []}

    branch_name = f"feature/{task_id_norm}"
    target_branch = "main" if mode == "ohd" else os.getenv("DBT_GITLAB_TARGET_BRANCH", "main").strip() or "main"
    api_url = gitlab_api_url if mode == "ohd" else os.getenv("GITLAB_API_URL", "")
    ssl_verify = gitlab_ssl_verify if mode == "ohd" else os.getenv("GITLAB_SSL_VERIFY", "true").strip().lower() not in {"0", "false", "no", "off"}
    lookup_options = {"api_url": api_url, "ssl_verify": ssl_verify} if mode == "ohd" else {}
    branch_exists = resource_exists(project=project_ref, token=token, path=f"repository/branches/{urlparse.quote(branch_name, safe='')}", **lookup_options)
    content_ref = branch_name if branch_exists else target_branch
    actions: list[dict[str, Any]] = []
    result_files: list[dict[str, Any]] = []

    for file_data in dbt_files.values():
        file_path = file_data["file_path"]
        existing_content = file_content(project=project_ref, token=token, file_path=file_path, ref=content_ref, **lookup_options)
        if file_data["file_kind"] == "dq_model":
            content = update_duplicates_model(existing_content, file_data["key_attributes"]) if existing_content is not None else build_duplicates_model({"key_attributes": file_data["key_attributes"]})
        elif file_data["file_kind"] == "nulls_model":
            if not file_data["null_conditions"]:
                if existing_content is None:
                    continue
                actions.append({"action": "delete", "file_path": file_path})
                result_files.append({"target_fqn": file_data["target_fqn"], "file_path": file_path, "file_kind": "nulls_model", "action": "delete"})
                continue
            content = build_nulls_model({"null_conditions": file_data["null_conditions"]})
        else:
            content = file_data["content"]
        action = "update" if existing_content is not None else "create"
        if existing_content == content:
            result_files.append({"target_fqn": file_data["target_fqn"], "file_path": file_path, "file_kind": file_data["file_kind"], "action": "unchanged"})
            continue
        actions.append({"action": action, "file_path": file_path, "content": content, "encoding": "text"})
        result_files.append({"target_fqn": file_data["target_fqn"], "file_path": file_path, "file_kind": file_data["file_kind"], "action": action})

    for target_fqn in sorted(deleted_targets):
        schema_name, table_name = target_fqn.split(".", 1)
        for file_kind, file_path in (
            ("registry", dbt_registry_path(schema_name, table_name)),
            ("model_sql", dbt_model_sql_path(schema_name, table_name)),
            ("dq_model", dbt_duplicates_path(schema_name, table_name)),
            ("nulls_model", dbt_nulls_path(schema_name, table_name)),
        ):
            if file_content(project=project_ref, token=token, file_path=file_path, ref=content_ref, **lookup_options) is None:
                continue
            actions.append({"action": "delete", "file_path": file_path})
            result_files.append({"target_fqn": target_fqn, "file_path": file_path, "file_kind": file_kind, "action": "delete"})

    if not actions:
        return {"status": "skipped", "reason": "SQL, registry и DQ-модели уже актуальны", "branch_name": branch_name, "target_branch": target_branch, "files": result_files}

    commit_payload: dict[str, Any] = {"branch": branch_name, "commit_message": f"{task_id_norm}: sync dbt metadata, SQL and DQ", "actions": actions}
    if not branch_exists:
        commit_payload["start_branch"] = target_branch
    request_args = {"api_url": api_url, "project": project_ref, "token": token, "ssl_verify": ssl_verify}
    commit_data = _gitlab_json_request(**request_args, path="repository/commits", method="POST", payload=commit_payload)

    undeleted_paths = [str(action.get("file_path") or "") for action in actions if action.get("action") == "delete" and file_content(project=project_ref, token=token, file_path=str(action.get("file_path") or ""), ref=branch_name, **lookup_options) is not None]
    if undeleted_paths:
        raise ValueError("После dbt-коммита не удалены файлы: " + ", ".join(sorted(undeleted_paths)))

    existing_mrs = _gitlab_json_request(**request_args, path="merge_requests", method="GET", query={"state": "opened", "source_branch": branch_name, "target_branch": target_branch})
    mr_data = existing_mrs[0] if existing_mrs else _gitlab_json_request(
        **request_args,
        path="merge_requests",
        method="POST",
        payload={
            "source_branch": branch_name,
            "target_branch": target_branch,
            "title": f"{task_id_norm}: dbt metadata, SQL and DQ",
            "description": "\n".join([f"Task: {task_id_norm}", f"Author: {author}", "", "dbt files:", *[f"- {item['action']}: {item['file_path']}" for item in result_files]]),
            "remove_source_branch": False,
        },
    )
    return {"status": "ok", "project": project_ref, "branch_name": branch_name, "target_branch": target_branch, "commit_id": commit_data.get("id"), "files": result_files, "mr_url": mr_data.get("web_url"), "mr_iid": mr_data.get("iid")}


_prototype_review_publish_dbt_registry = publish_dbt_registry
