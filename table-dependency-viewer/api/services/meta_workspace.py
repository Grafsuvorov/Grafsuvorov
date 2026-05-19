from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path
from typing import Any

from sqlalchemy import text

from .dev_meta import _audit_dev_meta, _resolve_root, ensure_dev_meta_tables
from .entity_dev_meta import (
    ENTITY_LOCK_SCHEMA,
    _ensure_git_identity,
    _gitlab_json_request,
    _list_task_entity_object_keys,
    _object_dir_from_key,
    _parse_gitlab_project,
    _run_git,
    _sync_task_objects_to_worktree,
)


def _list_task_click_meta_files(*, engine, task_id: str) -> list[dict[str, str]]:
    ensure_dev_meta_tables(engine)
    with engine.begin() as conn:
        rows = conn.execute(
            text(
                """
                SELECT schema_name, file_name, action, details
                FROM tech_etl.app_dev_meta_audit
                WHERE schema_name IN ('dm', 'dm_view')
                ORDER BY created_at
                """
            )
        ).mappings().all()

    result: dict[tuple[str, str], dict[str, str]] = {}
    task_norm = str(task_id or "").strip().upper()
    for row in rows:
        try:
            details = json.loads(row.get("details") or "{}")
        except Exception:
            details = {}
        if str(details.get("task_id") or "").strip().upper() != task_norm:
            continue
        schema_name = str(row.get("schema_name") or "").strip()
        file_name = str(row.get("file_name") or "").strip()
        action = str(row.get("action") or "").strip().lower()
        if not schema_name or not file_name:
            continue
        result[(schema_name, file_name)] = {
            "schema_name": schema_name,
            "file_name": file_name,
            "action": action,
        }
    return sorted(result.values(), key=lambda item: (item["schema_name"], item["file_name"]))


def _sync_click_task_files_to_worktree(
    *,
    dev_root: Path,
    worktree_click_root: Path,
    files: list[dict[str, str]],
) -> dict[str, list[str]]:
    updated_paths: list[str] = []
    removed_paths: list[str] = []
    for item in files:
        schema_name = item["schema_name"]
        file_name = item["file_name"]
        dev_path = dev_root / schema_name / file_name
        repo_path = worktree_click_root / schema_name / file_name
        if dev_path.exists():
            repo_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dev_path, repo_path)
            updated_paths.append(str(repo_path))
        elif repo_path.exists():
            repo_path.unlink()
            removed_paths.append(str(repo_path))
            parent = repo_path.parent
            while parent != worktree_click_root and parent.exists():
                try:
                    parent.rmdir()
                except OSError:
                    break
                parent = parent.parent
    return {"updated_paths": updated_paths, "removed_paths": removed_paths}


def create_meta_workspace_mr(
    *,
    engine,
    base_dir: Path,
    entity_dev_root_value: str,
    click_dev_root_value: str,
    git_repo_value: str,
    entity_git_root_value: str,
    click_git_root_value: str,
    gitlab_token: str,
    gitlab_project: str,
    gitlab_api_url: str,
    gitlab_ssl_verify: str,
    task_id: str,
    release_branch: str,
    author: str,
) -> dict[str, Any]:
    task_id_norm = str(task_id or "").strip().upper()
    if not task_id_norm or not task_id_norm.startswith("DWH-"):
        raise ValueError("Номер задачи должен быть в формате DWH-12345")
    release_branch_norm = str(release_branch or "").strip()
    if not release_branch_norm:
        raise ValueError("Укажите release-ветку")
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    if not gitlab_token:
        raise ValueError("Не настроен GITLAB_TOKEN")

    entity_dev_root = _resolve_root(base_dir, entity_dev_root_value)
    click_dev_root = _resolve_root(base_dir, click_dev_root_value)
    git_repo_root = Path(git_repo_value).resolve()
    entity_git_root_rel = Path(entity_git_root_value)
    click_git_root_rel = Path(click_git_root_value)
    ssl_verify = str(gitlab_ssl_verify or "true").strip().lower() not in {"0", "false", "no", "off"}
    project_ref = _parse_gitlab_project(gitlab_project) or _parse_gitlab_project(
        _run_git(git_repo_root, ["remote", "get-url", "origin"])
    )
    if not project_ref:
        raise ValueError("Не удалось определить GitLab project")

    entity_object_keys = _list_task_entity_object_keys(engine=engine, task_id=task_id_norm)
    click_files = _list_task_click_meta_files(engine=engine, task_id=task_id_norm)
    if not entity_object_keys and not click_files:
        raise ValueError(f"Не найдено изменений для задачи {task_id_norm}")

    feature_branch = f"feature/{task_id_norm}"
    _run_git(git_repo_root, ["fetch", "origin"])
    release_exists = _run_git(git_repo_root, ["ls-remote", "--heads", "origin", release_branch_norm])
    if not release_exists:
        raise ValueError(f"Release-ветка `{release_branch_norm}` не найдена в origin")

    worktree_dir = Path(tempfile.mkdtemp(prefix=f"meta-workspace-{task_id_norm.lower()}-"))
    try:
        remote_feature_exists = bool(_run_git(git_repo_root, ["ls-remote", "--heads", "origin", feature_branch]))
        if remote_feature_exists:
            _run_git(git_repo_root, ["worktree", "add", "-B", feature_branch, str(worktree_dir), f"origin/{feature_branch}"])
        else:
            _run_git(git_repo_root, ["worktree", "add", "-B", feature_branch, str(worktree_dir), f"origin/{release_branch_norm}"])
        _ensure_git_identity(repo_root=git_repo_root, cwd=worktree_dir, author=author)

        entity_sync = {"updated_paths": [], "removed_paths": []}
        if entity_object_keys:
            entity_sync = _sync_task_objects_to_worktree(
                dev_root=entity_dev_root,
                worktree_meta_root=worktree_dir / entity_git_root_rel,
                object_keys=entity_object_keys,
            )

        click_sync = {"updated_paths": [], "removed_paths": []}
        if click_files:
            click_sync = _sync_click_task_files_to_worktree(
                dev_root=click_dev_root,
                worktree_click_root=worktree_dir / click_git_root_rel,
                files=click_files,
            )

        status_output = _run_git(git_repo_root, ["status", "--porcelain"], cwd=worktree_dir)
        if status_output:
            _run_git(git_repo_root, ["add", "."], cwd=worktree_dir)
            _run_git(git_repo_root, ["commit", "-m", f"{task_id_norm}: update meta workspace objects"], cwd=worktree_dir)

        _run_git(git_repo_root, ["push", "origin", f"HEAD:{feature_branch}"], cwd=worktree_dir)

        description_lines = [
            f"Task: {task_id_norm}",
            f"Author: {author}",
            "",
            "GP objects:",
            *([f"- {item}" for item in sorted(entity_object_keys)] or ["- none"]),
            "",
            "Click files:",
            *([f"- {item['schema_name']}/{item['file_name']}" for item in click_files] or ["- none"]),
        ]
        existing = _gitlab_json_request(
            api_url=gitlab_api_url,
            project=project_ref,
            token=gitlab_token,
            ssl_verify=ssl_verify,
            path="merge_requests",
            method="GET",
            query={"state": "opened", "source_branch": feature_branch, "target_branch": release_branch_norm},
        )
        if existing:
            mr_data = existing[0]
        else:
            mr_data = _gitlab_json_request(
                api_url=gitlab_api_url,
                project=project_ref,
                token=gitlab_token,
                ssl_verify=ssl_verify,
                path="merge_requests",
                method="POST",
                payload={
                    "source_branch": feature_branch,
                    "target_branch": release_branch_norm,
                    "title": f"{task_id_norm}: Meta workspace changes",
                    "description": "\n".join(description_lines),
                    "remove_source_branch": False,
                },
            )

        _audit_dev_meta(
            engine,
            ENTITY_LOCK_SCHEMA,
            task_id_norm,
            author,
            "create_meta_workspace_mr",
            "",
            {
                "task_id": task_id_norm,
                "feature_branch": feature_branch,
                "release_branch": release_branch_norm,
                "gp_object_keys": sorted(entity_object_keys),
                "click_files": click_files,
                "mr_url": mr_data.get("web_url"),
            },
        )
        return {
            "task_id": task_id_norm,
            "feature_branch": feature_branch,
            "release_branch": release_branch_norm,
            "gp_object_keys": sorted(entity_object_keys),
            "click_files": click_files,
            "updated_paths": [*entity_sync["updated_paths"], *click_sync["updated_paths"]],
            "removed_paths": [*entity_sync["removed_paths"], *click_sync["removed_paths"]],
            "mr_url": mr_data.get("web_url"),
            "mr_iid": mr_data.get("iid"),
        }
    finally:
        try:
            _run_git(git_repo_root, ["worktree", "remove", "--force", str(worktree_dir)])
        except Exception:
            pass
        shutil.rmtree(worktree_dir, ignore_errors=True)
