"""Workflow for validating a prototype review and creating its YouTrack issue."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable
import re
import logging

from .prototype_review_issue_delivery import PrototypeIssueDeliveryDependencies
from .prototype_review_variants import validate_issue_variants
from .prototype_review_retry import validate_review_sources
from .prototype_review_dbt import build_registry_yaml
from .prototype_review import infer_review_targets, infer_removed_table_targets
from .prototype_source_batch import payload_source_loads, validate_source_loads


@dataclass(frozen=True)
class PrototypeIssueWorkflowDependencies:
    load_bundle: Callable[..., dict[str, Any]]
    parse_task: Callable[[str], dict[str, Any]]
    prepare_yaml: Callable[..., str]
    extract_dependencies: Callable[..., list[str]]
    apply_yaml_dependencies: Callable[[str, list[str]], str]
    item_needs_attention: Callable[[dict[str, Any]], tuple[bool, list[str]]]
    build_description: Callable[..., str]
    create_issue: Callable[..., dict[str, Any]]
    get_parent_issue_context: Callable[..., dict[str, Any]]
    link_issues: Callable[..., Any]
    link_parent_issue: Callable[..., dict[str, Any]]
    attach_files: Callable[..., list[dict[str, Any]]]
    deliver_issue: Callable[..., dict[str, Any]]
    build_issue_link: Callable[[str], str | None]
    delivery: PrototypeIssueDeliveryDependencies
    gitlab_api_url: str
    gitlab_project: str
    gitlab_token: str
    gitlab_ssl_verify: bool
    analyst_gitlab_project: str
    youtrack_url: str
    youtrack_project_id: str
    youtrack_project: str
    youtrack_token: str
    youtrack_queue: str
    youtrack_issue_type: str
    youtrack_ssl_verify: bool
    default_estimate_minutes: int
    estimate_field_name: str
    card_type_field_name: str
    card_type_value: str
    assignee_field_name: str
    assignee_query: str
    release_date_field_name: str
    direction_field_name: str
    business_key_changed_field_name: str


def _split_entity_names(value: Any) -> list[str]:
    """Return ordered unique entity names entered as a comma-separated value."""
    result: list[str] = []
    seen: set[str] = set()
    for part in str(value or "").split(","):
        entity_name = part.strip()
        key = entity_name.lower()
        if entity_name and key not in seen:
            seen.add(key)
            result.append(entity_name)
    return result


def _reuse_primary_sql_paths(replica_yaml: str, primary_yaml: str) -> str:
    """Point a replica YAML at the SQL files owned by the primary entity."""
    result = str(replica_yaml or "")
    for field_name in ("sql_query_recreate_init", "sql_query_insert_init", "sql_query_truncate"):
        primary_match = re.search(rf"(?m)^(\s*{field_name}:\s*)(.+?)\s*$", str(primary_yaml or ""))
        if not primary_match:
            continue
        result = re.sub(
            rf"(?m)^(\s*{field_name}:\s*).+?\s*$",
            lambda match: f"{match.group(1)}{primary_match.group(2)}",
            result,
            count=1,
        )
    return result


def create_prototype_review_issue(
    payload: Any,
    user: Any,
    *,
    dependencies: PrototypeIssueWorkflowDependencies,
) -> dict[str, Any]:
    ohd = getattr(payload, "mode", "khd") == "ohd"
    source_loads = payload_source_loads(payload)
    review_items = [item.model_dump() if hasattr(item, "model_dump") else dict(item)
                    for item in getattr(payload, "review_items", [])]
    if ohd and any(getattr(i, "is_clickhouse_view", False) for i in payload.review_items):
        raise ValueError("В режиме ОХД поддерживается только dbt Greenplum без ClickHouse")
    validate_source_loads(source_loads, mode="ohd" if ohd else "khd", review_items=review_items)
    task_contents = {
        "mode": "ohd" if ohd else "khd",
        "diff_targets": [item.get("target_fqn") for item in review_items],
        "source_targets": [f"{load['target_schema']}.{load['target_table']}" for load in source_loads],
    }
    logging.getLogger("uvicorn.error").info("[PROTOTYPE TASK CONTENTS] %s", task_contents)
    dashboard_direction = str(payload.direction or "").strip()
    requested_parent_issue = str(getattr(payload, "parent_issue", None) or "").strip().upper()
    if requested_parent_issue:
        if not callable(dependencies.get_parent_issue_context):
            raise ValueError("Не настроено получение данных родительской задачи YouTrack")
        parent_context = dependencies.get_parent_issue_context(
            base_url=dependencies.youtrack_url,
            token=dependencies.youtrack_token,
            issue_id=requested_parent_issue,
            direction_field_name=dependencies.direction_field_name,
            ssl_verify=dependencies.youtrack_ssl_verify,
        )
        parent_direction = str((parent_context or {}).get("direction") or "").strip()
        if parent_direction:
            dashboard_direction = parent_direction
    if not dashboard_direction:
        raise ValueError("Заполните обязательное поле «Дашборд КХД/Направление»")

    bundle = dependencies.load_bundle(
        gitlab_api_url=dependencies.gitlab_api_url,
        gitlab_project=dependencies.gitlab_project,
        gitlab_token=dependencies.gitlab_token,
        gitlab_ssl_verify=dependencies.gitlab_ssl_verify,
        mr_input=payload.mr_input,
        default_project=dependencies.analyst_gitlab_project or dependencies.gitlab_project,
    ) if str(payload.mr_input or "").strip() else {"mr": {}, "files": [], "deleted_files": []}
    parsed_task = dependencies.parse_task(payload.task_text or "")
    if not str(payload.mr_input or "").strip() and review_items:
        raise ValueError("Для объектов diff укажите исходный MR")
    if not str(payload.mr_input or "").strip() and not source_loads:
        raise ValueError("Добавьте STG-таблицы или укажите MR")
    changed_files = bundle.get("files") or []
    removed_targets = infer_removed_table_targets(files=changed_files, deleted_files=bundle.get("deleted_files") or [],
        active_targets={str(item.get("target_fqn") or "").lower() for item in review_items})
    for load in source_loads:
        if f"{load['target_schema']}.{load['target_table']}".lower() in removed_targets:
            raise ValueError("STG-таблица одновременно добавляется из источника и удаляется в diff")
    if ohd and any(t.get("is_clickhouse_view") for t in infer_review_targets(changed_files)):
        raise ValueError("Режим ОХД поддерживает только dbt Greenplum, без ClickHouse")
    validate_review_sources(review_items, changed_files)
    validate_issue_variants(review_items, changed_files)
    for item in review_items:
        item_paths = {
            str(value or "").strip()
            for value in (item.get("paths") or [])
            if str(value or "").strip()
        }
        if not item_paths and str(item.get("path") or "").strip():
            item_paths.add(str(item.get("path") or "").strip())
        related_files = [
            file_item
            for file_item in changed_files
            if str(file_item.get("path") or "").strip() in item_paths
        ]
        if ohd:
            item["dependencies"] = []
        elif related_files:
            item["dependencies"] = dependencies.extract_dependencies(
                related_files,
                exclude_fqns={str(item.get("target_fqn") or "").strip()},
            )
        item["_related_files"] = related_files
    reserved_table_ids: set[int] = set()
    for item in review_items:
        if ohd:
            item["review_mode"] = "ohd"
            item.pop("_related_files", None)
            item["yaml_content"] = ""
            item["table_id"] = None
            item["replica_yaml_contents"] = {}
            item["entity_names"] = _split_entity_names(item.get("entity_name"))
            if str(item.get("object_type") or "TABLE").upper() == "TABLE":
                build_registry_yaml(item)
            continue
        if item.get("is_clickhouse_view"):
            # ClickHouse view DDL is delivered verbatim to config_files/meta;
            # it has no Greenplum YAML identity or DEV execution step.
            item["object_type"] = "VIEW"
            item["yaml_content"] = ""
            item["replica_yaml_contents"] = {}
            continue
        entity_names = _split_entity_names(item.get("entity_name"))
        if not entity_names:
            entity_names = [""]
        primary_entity_name, *replica_entity_names = entity_names
        item["entity_name"] = primary_entity_name
        item["entity_names"] = entity_names
        item["replica_entity_names"] = replica_entity_names
        related_files = item.pop("_related_files", [])
        primary_yaml = dependencies.prepare_yaml(
            item={**item, "entity_name": primary_entity_name},
            related_files=related_files,
            reserved_table_ids=reserved_table_ids,
        )
        primary_yaml = dependencies.apply_yaml_dependencies(primary_yaml, list(item.get("dependencies") or []))
        item["yaml_content"] = primary_yaml
        replica_yaml_contents: dict[str, str] = {}
        for replica_entity_name in replica_entity_names:
            replica_yaml = dependencies.prepare_yaml(
                item={**item, "entity_name": replica_entity_name},
                related_files=related_files,
                reserved_table_ids=reserved_table_ids,
            )
            replica_yaml = dependencies.apply_yaml_dependencies(replica_yaml, list(item.get("dependencies") or []))
            replica_yaml_contents[replica_entity_name] = _reuse_primary_sql_paths(replica_yaml, primary_yaml)
        item["replica_yaml_contents"] = replica_yaml_contents

    incomplete: list[str] = []
    for item in review_items:
        if item.get("is_clickhouse_view"):
            continue
        needs_attention, missing = dependencies.item_needs_attention(item)
        if needs_attention:
            incomplete.append(f"{item.get('target_fqn')}: {', '.join(missing)}")
    if incomplete:
        raise ValueError("Нужно заполнить вручную: " + "; ".join(incomplete))

    parent_issue = str(getattr(payload, "parent_issue", None) or parsed_task.get("parent_issue") or "").strip().upper()
    linked_issues = [
        issue_id for issue_id in dict.fromkeys(payload.linked_issues or parsed_task.get("linked_issues") or [])
        if str(issue_id or "").strip().upper() != parent_issue
    ]
    task_context = {
        **parsed_task,
        "summary": (payload.issue_summary or "").strip() or parsed_task.get("summary"),
        "linked_issues": linked_issues,
        "parent_issue": parent_issue,
        "diff_comment": str(getattr(payload, "diff_comment", None) or "").strip(),
        "release_date": (payload.release_date or parsed_task.get("release_date") or "").strip(),
        "direction": dashboard_direction,
        "business_key_changed": (
            payload.business_key_changed
            if payload.business_key_changed is not None
            else parsed_task.get("business_key_changed")
        ),
    }
    summary = (
        (payload.issue_summary or "").strip()
        or parsed_task.get("summary")
        or f"[Prototype Review] {bundle.get('mr', {}).get('source_branch') or 'prototype'}"
    )
    description = dependencies.build_description(
        mr=bundle.get("mr") or {},
        task_context=task_context,
        initiator={"email": getattr(user, "email", None), "username": getattr(user, "username", None)},
        review_items=review_items,
        deleted_files=bundle.get("deleted_files") or [],
    )
    for index, load in enumerate(source_loads, 1):
        description += f"\n\n## STG {index}\n\n" + "\n".join([
            f'**Таблица target:** {load["target_schema"]}."{load["target_table"]}";',
            f'**Источник:** {load.get("source_schema")}.{load.get("source_table")};',
            *([f'**Расписание:** {load.get("entity_name")};'] if not ohd else []),
        ])
    issue_result = dependencies.create_issue(
        base_url=dependencies.youtrack_url,
        project_id=dependencies.youtrack_project_id,
        project=dependencies.youtrack_project,
        token=dependencies.youtrack_token,
        queue=dependencies.youtrack_queue,
        issue_type=dependencies.youtrack_issue_type,
        ssl_verify=dependencies.youtrack_ssl_verify,
        summary=summary,
        description=description,
        default_estimate_minutes=dependencies.default_estimate_minutes,
        estimate_field_name=dependencies.estimate_field_name,
        card_type_field_name=dependencies.card_type_field_name,
        card_type_value=dependencies.card_type_value,
        assignee_field_name=dependencies.assignee_field_name,
        assignee_query=getattr(user, "email", None) or dependencies.assignee_query,
        assignee_fallback_query=dependencies.assignee_query,
        release_date=task_context.get("release_date"),
        release_date_field_name=dependencies.release_date_field_name,
        direction=task_context.get("direction"),
        direction_field_name=dependencies.direction_field_name,
        business_key_changed=task_context.get("business_key_changed"),
        business_key_changed_field_name=dependencies.business_key_changed_field_name,
    )
    issue_links = dependencies.link_issues(
        base_url=dependencies.youtrack_url,
        token=dependencies.youtrack_token,
        issue_id=str(issue_result.get("issue_id") or ""),
        linked_issue_ids=task_context.get("linked_issues") or [],
        ssl_verify=dependencies.youtrack_ssl_verify,
    )
    parent_link = {"status": "skipped", "parent_issue": None}
    if parent_issue:
        parent_link = dependencies.link_parent_issue(
            base_url=dependencies.youtrack_url,
            token=dependencies.youtrack_token,
            issue_id=str(issue_result.get("issue_id") or ""),
            parent_issue_id=parent_issue,
            ssl_verify=dependencies.youtrack_ssl_verify,
        )
    attachments: list[dict[str, Any]] = []
    attachment_error = None
    attachment_files = [
        {
            "filename": script.get("filename"),
            "content": script.get("content"),
            "mime_type": script.get("mime_type") or "text/plain; charset=utf-8",
        }
        for item in review_items
        for script in (item.get("manual_scripts") or [])
        if str(script.get("filename") or "").strip() and str(script.get("content") or "").strip()
    ]
    oversized_files = [
        str(item.get("filename") or "")
        for item in attachment_files
        if len(str(item.get("content") or "").encode("utf-8")) > 2 * 1024 * 1024
    ]
    if oversized_files:
        attachment_error = "Не приложены файлы больше 2 МБ: " + ", ".join(oversized_files)
        attachment_files = [
            item
            for item in attachment_files
            if len(str(item.get("content") or "").encode("utf-8")) <= 2 * 1024 * 1024
        ]
    if attachment_files:
        try:
            attachments = dependencies.attach_files(
                base_url=dependencies.youtrack_url,
                token=dependencies.youtrack_token,
                issue_id=str(issue_result.get("issue_id") or ""),
                ssl_verify=dependencies.youtrack_ssl_verify,
                files=attachment_files,
            )
        except Exception as exc:
            attachment_error = str(exc)
    delivery = dependencies.deliver_issue(
        issue_result=issue_result,
        review_items=review_items,
        bundle=bundle,
        user=user,
        dependencies=dependencies.delivery,
        source_load=source_loads or None,
    )
    if issue_result.get("issue_id"):
        issue_result["link"] = dependencies.build_issue_link(issue_result["issue_id"])
    return {
        "status": "ok",
        "task_contents": task_contents,
        "issue": issue_result,
        "issue_links": issue_links,
        "parent_link": parent_link,
        "description": description,
        "attachments": attachments,
        "attachment_error": attachment_error,
        **delivery,
    }
