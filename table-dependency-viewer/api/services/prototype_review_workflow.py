"""Orchestration for running a prototype review."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from typing import Any, Callable

from .prototype_review import (
    _infer_target_from_path,
    _is_clickhouse_sql_path,
    infer_review_targets,
    parse_prototype_task_text,
    validate_prototype_sql,
)


@dataclass(frozen=True)
class PrototypeReviewWorkflowDependencies:
    load_bundle: Callable[..., dict[str, Any]]
    get_meta_and_index: Callable[[], tuple[list[dict[str, Any]], Any]]
    resolve_item: Callable[..., dict[str, Any]]
    execute_review: Callable[..., tuple[list[dict[str, Any]], list[dict[str, Any]]]]
    gitlab_api_url: str
    gitlab_project: str
    gitlab_token: str
    gitlab_ssl_verify: bool
    analyst_gitlab_project: str
    dev_database_url: str


def build_prototype_review_result(
    payload: Any,
    user,
    progress_callback=None,
    *,
    dependencies: PrototypeReviewWorkflowDependencies,
) -> dict[str, Any]:
    bundle = dependencies.load_bundle(
        gitlab_api_url=dependencies.gitlab_api_url,
        gitlab_project=dependencies.gitlab_project,
        gitlab_token=dependencies.gitlab_token,
        gitlab_ssl_verify=dependencies.gitlab_ssl_verify,
        mr_input=payload.mr_input,
        default_project=dependencies.analyst_gitlab_project or dependencies.gitlab_project,
    )
    files = bundle.get("files") or []
    parsed_task = parse_prototype_task_text(payload.task_text or "")
    sql_validation = validate_prototype_sql(files)
    all_meta, _ = dependencies.get_meta_and_index()
    known_schemas = {
        str(meta.get("table_schema") or "").strip().lower()
        for meta in all_meta
        if str(meta.get("table_schema") or "").strip()
    }
    validation_errors = list(sql_validation.get("errors") or [])
    validation_warnings = list(sql_validation.get("warnings") or [])
    for deleted_file in bundle.get("deleted_files") or []:
        deleted_path = str(deleted_file.get("path") or "").strip()
        if deleted_path:
            validation_warnings.append(
                f"Удалённый SQL-файл `{deleted_path}` не выполнялся в DEV; проверьте влияние удаления на объект и зависимости"
            )
    review_targets = infer_review_targets(files)
    if files and not any(item.get("target_fqn") for item in review_targets):
        validation_errors.append("Не удалось определить целевые таблицы по SQL-файлам MR")

    status_reason = "; ".join(validation_errors) if validation_errors else ""
    task_context = {
        **parsed_task,
        "summary": (payload.issue_summary or "").strip() or parsed_task.get("summary"),
        "dependent_views": payload.dependent_views or parsed_task.get("dependent_views") or [],
        "linked_issues": payload.linked_issues or parsed_task.get("linked_issues") or [],
        "release_date": (payload.release_date or parsed_task.get("release_date") or "").strip(),
        "direction": (payload.direction or parsed_task.get("direction") or "").strip(),
        "business_key_changed": (
            payload.business_key_changed
            if payload.business_key_changed is not None
            else parsed_task.get("business_key_changed")
        ),
    }
    preparation_rows: list[dict[str, Any]] = []
    execution_rows: list[dict[str, Any]] = []
    if not validation_errors:
        preparation_rows, execution_rows = dependencies.execute_review(
            dev_database_url=dependencies.dev_database_url,
            files=files,
            review_targets=review_targets,
            progress_callback=progress_callback,
        )

    exec_by_path = {str(item.get("path") or "").strip(): item for item in execution_rows if str(item.get("path") or "").strip()}
    exec_by_item_id: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in execution_rows:
        row_item_id = str(row.get("item_id") or "").strip()
        if row_item_id:
            exec_by_item_id[row_item_id].append(row)
    prep_by_item_id = {str(item.get("item_id") or ""): item for item in preparation_rows}
    review_items: list[dict[str, Any]] = []
    reserved_table_ids: set[int] = set()
    all_dependencies: list[str] = []
    requires_user_input = False
    for target_item in review_targets:
        item_id = str(target_item.get("item_id") or "").strip()
        target_fqn = str(target_item.get("target_fqn") or "").strip()
        if not target_fqn:
            validation_warnings.append(f"Для файла `{target_item.get('path')}` не удалось определить целевой объект")
            continue
        path_value = str(target_item.get("path") or "")
        related_paths = [str(value).strip() for value in (target_item.get("paths") or []) if str(value).strip()]
        related_execution_rows = list(exec_by_item_id.get(item_id) or [])
        if not related_execution_rows:
            related_execution_rows = [exec_by_path[path] for path in related_paths if path in exec_by_path]
        execution_status = "skipped"
        execution_duration = 0.0
        execution_error_messages: list[str] = []
        if related_execution_rows:
            execution_duration = round(
                sum(float(row.get("duration_sec") or 0.0) for row in related_execution_rows),
                3,
            )
            if any(str(row.get("status") or "") == "error" for row in related_execution_rows):
                execution_status = "error"
                execution_error_messages = [
                    str(row.get("error_message") or "").strip()
                    for row in related_execution_rows
                    if str(row.get("error_message") or "").strip()
                ]
            elif any(str(row.get("status") or "") == "ok" for row in related_execution_rows):
                execution_status = "ok"
            elif any(str(row.get("status") or "") == "skipped" for row in related_execution_rows):
                execution_status = "skipped"
        execution_row = {
            "status": execution_status,
            "duration_sec": execution_duration,
        }
        if execution_error_messages:
            execution_row["error_message"] = "; ".join(dict.fromkeys(execution_error_messages))
        related_files = [row for row in files if str(row.get("path") or "") in set(related_paths)]
        file_item = related_files[0] if related_files else {}
        table_dependencies: list[str] = []
        item_result = dependencies.resolve_item(
            target_fqn=target_fqn,
            path_value=path_value,
            execution_row=execution_row,
            known_schemas=known_schemas,
            file_item=file_item,
            related_files=related_files,
            fallback_entity_name=str(payload.entity_name or parsed_task.get("entity_name") or "").strip(),
            object_type_hint=str(target_item.get("object_type") or ""),
            reserved_table_ids=reserved_table_ids,
        )
        item_result["item_id"] = item_id
        item_result["paths"] = related_paths
        item_result["object_type"] = str(target_item.get("object_type") or item_result.get("object_type") or "TABLE").upper()
        item_result["preparation"] = prep_by_item_id.get(item_id) or {"status": "skipped"}
        item_result["dependencies"] = table_dependencies
        requires_user_input = requires_user_input or bool(item_result.get("requires_user_input"))
        review_items.append(item_result)

    covered_paths = {
        str(path_value).strip()
        for item in review_items
        for path_value in (item.get("paths") or [item.get("path")])
        if str(path_value).strip()
    }
    for execution_row in execution_rows:
        path_value = str(execution_row.get("path") or "").strip()
        if not path_value or path_value in covered_paths or _is_clickhouse_sql_path(path_value):
            continue
        fallback_target = _infer_target_from_path(path_value)
        if not fallback_target:
            continue
        target_fqn, object_type = fallback_target
        related_files = [row for row in files if str(row.get("path") or "").strip() == path_value]
        file_item = related_files[0] if related_files else {}
        table_dependencies: list[str] = []
        item_result = dependencies.resolve_item(
            target_fqn=target_fqn,
            path_value=path_value,
            execution_row=execution_row,
            known_schemas=known_schemas,
            file_item=file_item,
            related_files=related_files,
            fallback_entity_name=str(payload.entity_name or parsed_task.get("entity_name") or "").strip(),
            object_type_hint=object_type,
            reserved_table_ids=reserved_table_ids,
        )
        item_result["item_id"] = f"{target_fqn}::{object_type}"
        item_result["object_type"] = object_type
        item_result["paths"] = [path_value]
        item_result["preparation"] = {"status": "skipped"}
        item_result["dependencies"] = table_dependencies
        requires_user_input = requires_user_input or bool(item_result.get("requires_user_input"))
        review_items.append(item_result)
        covered_paths.add(path_value)
    execution_errors = [item for item in execution_rows if item.get("status") == "error"]
    if execution_errors:
        for item in execution_errors:
            validation_errors.append(f"Файл `{item.get('path')}`: {item.get('error_message') or 'SQL не выполнился'}")
    if any(item.get("warnings") for item in review_items):
        for item in review_items:
            for warning in item.get("warnings") or []:
                if warning not in validation_warnings:
                    validation_warnings.append(warning)
    status = "error" if validation_errors else ("warning" if validation_warnings else "ok")
    if not status_reason:
        status_reason = "; ".join(validation_warnings) if validation_warnings else "Проверки завершены. Проверьте блоки по всем таблицам и затем создайте задачу."
    return {
        "status": status,
        "mr": bundle.get("mr") or {},
        "files": [{"path": item.get("path"), "statements_count": len(item.get("statements") or [])} for item in files],
        "deleted_files": bundle.get("deleted_files") or [],
        "final_target": review_items[0].get("target_fqn") if review_items else None,
        "review_items": review_items,
        "dependencies": all_dependencies,
        "preparation": preparation_rows,
        "execution": execution_rows,
        "validation_errors": validation_errors,
        "validation_warnings": validation_warnings,
        "status_reason": status_reason,
        "task_context": task_context,
        "issue": {"status": "skipped", "issue_id": None, "url": None, "link": None},
        "requires_user_input": requires_user_input,
    }
