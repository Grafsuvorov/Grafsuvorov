"""Delivery of prototype review metadata and dbt changes."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable

from .prototype_review import infer_removed_table_targets


@dataclass(frozen=True)
class PrototypeIssueDeliveryDependencies:
    collect_target_sql: Callable[..., dict[str, Any]]
    save_gp_bundle: Callable[..., dict[str, Any]]
    save_file: Callable[..., dict[str, Any]]
    delete_object: Callable[..., dict[str, Any]]
    create_meta_mr: Callable[..., dict[str, Any]]
    publish_dbt: Callable[..., dict[str, Any]]
    add_comment: Callable[..., Any]
    yaml_repo_path: Callable[..., str]
    engine: Any
    base_dir: Any
    dev_entity_root: Any
    dev_click_root: Any
    entity_git_repo: str
    entity_git_root: str
    click_git_root: str
    workspace_root: str
    base_branch: str
    target_branch: str
    gitlab_api_url: str
    gitlab_project: str
    gitlab_token: str
    gitlab_ssl_verify: bool
    youtrack_url: str
    youtrack_token: str
    youtrack_ssl_verify: bool


def deliver_prototype_issue(
    *,
    issue_result: dict[str, Any],
    review_items: list[dict[str, Any]],
    bundle: dict[str, Any],
    user: Any,
    dependencies: PrototypeIssueDeliveryDependencies,
) -> dict[str, Any]:
    author = getattr(user, "email", None) or getattr(user, "username", None) or "prototype-review"
    meta_branch = None
    meta_files = []
    meta_error = None
    meta_mr = None
    meta_mr_error = None
    dbt_registry = None
    dbt_registry_error = None
    raw_issue_id = str((issue_result.get("raw") or {}).get("id") or "").strip()
    if raw_issue_id:
        issue_id = str(issue_result.get("issue_id") or "").strip().upper()
        branch_name = f"feature/{issue_id}"
        active_targets = {
            str(item.get("target_fqn") or "").strip().lower()
            for item in review_items
            if str(item.get("target_fqn") or "").strip()
        }
        deleted_table_targets = infer_removed_table_targets(
            files=bundle.get("files") or [],
            deleted_files=bundle.get("deleted_files") or [],
            active_targets=active_targets,
        )
        for item in review_items:
            yaml_content = str(item.get("yaml_content") or "").strip()
            if not yaml_content:
                continue
            target_fqn = str(item.get("target_fqn") or "").strip().lower()
            entity_name = str(item.get("entity_name") or "").strip()
            if "." not in target_fqn or not entity_name:
                continue
            schema_name, table_name = target_fqn.split(".", 1)
            try:
                # Prototype Review creates metadata only.  The engineer owns
                # recreate/insert/truncate scripts and adds them manually.
                save_result = dependencies.save_file(
                    git_repo_value=dependencies.entity_git_repo,
                    workspace_root_value=dependencies.workspace_root,
                    workspace_owner=author,
                    branch_name=branch_name,
                    base_branch=dependencies.base_branch,
                    file_path=dependencies.yaml_repo_path(entity_name, schema_name, table_name),
                    content=yaml_content,
                    task_id=str(issue_result.get("issue_id") or "").strip().upper(),
                    author=author,
                    expected_revision=None,
                )
                for replica_entity_name, replica_yaml in (item.get("replica_yaml_contents") or {}).items():
                    replica_name = str(replica_entity_name or "").strip()
                    if not replica_name:
                        continue
                    replica_result = dependencies.save_file(
                        git_repo_value=dependencies.entity_git_repo,
                        workspace_root_value=dependencies.workspace_root,
                        workspace_owner=author,
                        branch_name=branch_name,
                        base_branch=dependencies.base_branch,
                        file_path=dependencies.yaml_repo_path(replica_name, schema_name, table_name),
                        content=str(replica_yaml or ""),
                        task_id=str(issue_result.get("issue_id") or "").strip().upper(),
                        author=author,
                        expected_revision=None,
                    )
                    save_result["changed_files"] = [
                        *(save_result.get("changed_files") or []),
                        *(replica_result.get("changed_files") or []),
                    ]
                    save_result["branch_name"] = replica_result.get("branch_name") or save_result.get("branch_name")
                meta_files.append(
                    {
                        "target_fqn": target_fqn,
                        "entity_name": entity_name,
                        "file_path": save_result.get("file_path") or save_result.get("path"),
                        "branch_name": save_result.get("branch_name"),
                        "committed": bool(save_result.get("committed")),
                        "action": "create" if item.get("is_new") else "update",
                        "changed_files": save_result.get("changed_files") or [],
                    }
                )
                meta_branch = save_result.get("branch_name") or meta_branch
            except Exception as exc:
                meta_error = str(exc)
                break
        if not meta_error:
            for target_fqn in sorted(deleted_table_targets):
                schema_name, table_name = target_fqn.split(".", 1)
                try:
                    delete_result = dependencies.delete_object(
                        git_repo_value=dependencies.entity_git_repo,
                        entity_git_root_value=dependencies.entity_git_root,
                        workspace_root_value=dependencies.workspace_root,
                        workspace_owner=author,
                        branch_name=branch_name,
                        base_branch=dependencies.base_branch,
                        schema_name=schema_name,
                        table_name=table_name,
                        task_id=issue_id,
                        author=author,
                    )
                    meta_files.append(
                        {
                            "target_fqn": target_fqn,
                            "entity_name": delete_result.get("entity_name"),
                            "file_path": delete_result.get("path"),
                            "branch_name": delete_result.get("branch_name"),
                            "committed": bool(delete_result.get("committed")),
                            "action": "delete",
                            "changed_files": delete_result.get("changed_files") or [],
                        }
                    )
                    meta_branch = delete_result.get("branch_name") or meta_branch
                except Exception as exc:
                    meta_error = str(exc)
                    break
        if not meta_error and meta_branch:
            try:
                meta_mr = dependencies.create_meta_mr(
                    engine=dependencies.engine,
                    base_dir=dependencies.base_dir,
                    entity_dev_root_value=dependencies.dev_entity_root,
                    click_dev_root_value=dependencies.dev_click_root,
                    git_repo_value=dependencies.entity_git_repo,
                    entity_git_root_value=dependencies.entity_git_root,
                    click_git_root_value=dependencies.click_git_root,
                    gitlab_token=dependencies.gitlab_token,
                    gitlab_project=dependencies.gitlab_project,
                    gitlab_api_url=dependencies.gitlab_api_url,
                    gitlab_ssl_verify=dependencies.gitlab_ssl_verify,
                    task_id=str(issue_result.get("issue_id") or "").strip().upper(),
                    release_branch=dependencies.target_branch,
                    branch_name=meta_branch,
                    mr_title=(
                        f"{str(issue_result.get('issue_id') or '').strip().upper()}: "
                        f"Engineer MR to {dependencies.target_branch}"
                    ),
                    author=author,
                )
                if meta_mr.get("mr_url") and dependencies.youtrack_url and dependencies.youtrack_token:
                    dependencies.add_comment(
                        base_url=dependencies.youtrack_url,
                        token=dependencies.youtrack_token,
                        issue_id=str(issue_result.get("issue_id") or "").strip().upper(),
                        ssl_verify=dependencies.youtrack_ssl_verify,
                        text=(
                            "MR создан из Prototype Review для инженера.\n"
                            f"Ссылка: {meta_mr.get('mr_url')}\n"
                            f"Ветка: {meta_mr.get('feature_branch') or '—'} -> "
                            f"{meta_mr.get('release_branch') or dependencies.target_branch}"
                        ),
                    )
                    meta_mr["task_link_attached"] = True
            except Exception as exc:
                meta_mr_error = str(exc)
        try:
            dbt_registry = dependencies.publish_dbt(
                task_id=issue_id,
                author=author,
                review_items=review_items,
                changed_files=bundle.get("files") or [],
                deleted_files=bundle.get("deleted_files") or [],
            )
            if dbt_registry.get("mr_url") and dependencies.youtrack_url and dependencies.youtrack_token:
                dependencies.add_comment(
                    base_url=dependencies.youtrack_url,
                    token=dependencies.youtrack_token,
                    issue_id=issue_id,
                    ssl_verify=dependencies.youtrack_ssl_verify,
                    text=(
                        "MR с ключами и DQ-настройками создан в dbt-проекте.\n"
                        f"Ссылка: {dbt_registry.get('mr_url')}\n"
                        f"Ветка: {dbt_registry.get('branch_name')} -> {dbt_registry.get('target_branch')}"
                    ),
                )
                dbt_registry["task_link_attached"] = True
        except Exception as exc:
            dbt_registry_error = str(exc)
    return {
        "meta_branch": meta_branch,
        "meta_files": meta_files,
        "meta_error": meta_error,
        "meta_mr": meta_mr,
        "meta_mr_error": meta_mr_error,
        "dbt_registry": dbt_registry,
        "dbt_registry_error": dbt_registry_error,
    }
