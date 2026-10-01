"""Workflow for validating a prototype review and creating its YouTrack issue."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable

from .prototype_review_issue_delivery import PrototypeIssueDeliveryDependencies


@dataclass(frozen=True)
class PrototypeIssueWorkflowDependencies:
    load_bundle: Callable[..., dict[str, Any]]
    parse_task: Callable[[str], dict[str, Any]]
    refresh_yaml: Callable[..., str]
    item_needs_attention: Callable[[dict[str, Any]], tuple[bool, list[str]]]
    build_description: Callable[..., str]
    create_issue: Callable[..., dict[str, Any]]
    link_issues: Callable[..., Any]
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


def create_prototype_review_issue(
    payload: Any,
    user: Any,
    *,
    dependencies: PrototypeIssueWorkflowDependencies,
) -> dict[str, Any]:
    dashboard_direction = str(payload.direction or "").strip()
    if not dashboard_direction:
        raise ValueError("Заполните обязательное поле «Дашборд КХД/Направление»")

    bundle = dependencies.load_bundle(
        gitlab_api_url=dependencies.gitlab_api_url,
        gitlab_project=dependencies.gitlab_project,
        gitlab_token=dependencies.gitlab_token,
        gitlab_ssl_verify=dependencies.gitlab_ssl_verify,
        mr_input=payload.mr_input,
        default_project=dependencies.analyst_gitlab_project or dependencies.gitlab_project,
    )
    parsed_task = dependencies.parse_task(payload.task_text or "")
    review_items = [item.model_dump() for item in payload.review_items]
    reserved_table_ids: set[int] = set()
    for item in review_items:
        if str(item.get("yaml_content") or "").strip():
            item["yaml_content"] = dependencies.refresh_yaml(
                item=item,
                reserved_table_ids=reserved_table_ids,
            )

    incomplete: list[str] = []
    for item in review_items:
        needs_attention, missing = dependencies.item_needs_attention(item)
        if needs_attention:
            incomplete.append(f"{item.get('target_fqn')}: {', '.join(missing)}")
    if incomplete:
        raise ValueError("Нужно заполнить вручную: " + "; ".join(incomplete))

    task_context = {
        **parsed_task,
        "summary": (payload.issue_summary or "").strip() or parsed_task.get("summary"),
        "linked_issues": payload.linked_issues or parsed_task.get("linked_issues") or [],
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
        assignee_query=dependencies.assignee_query,
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
    delivery = dependencies.deliver_issue(
        issue_result=issue_result,
        review_items=review_items,
        bundle=bundle,
        user=user,
        dependencies=dependencies.delivery,
    )
    if issue_result.get("issue_id"):
        issue_result["link"] = dependencies.build_issue_link(issue_result["issue_id"])
    return {
        "status": "ok",
        "issue": issue_result,
        "issue_links": issue_links,
        "description": description,
        **delivery,
    }
