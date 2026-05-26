from __future__ import annotations

import json
import re
import shutil
import tempfile
from pathlib import Path
from typing import Any

from sqlalchemy import text

from .dev_meta import _audit_dev_meta, _resolve_root, ensure_dev_meta_tables, validate_dev_meta_content
from .entity_dev_meta import (
    ENTITY_LOCK_SCHEMA,
    _ensure_git_identity,
    _load_yaml_text,
    _gitlab_json_request,
    _list_task_entity_object_keys,
    _object_dir_from_key,
    _parse_gitlab_project,
    _run_git,
    _sync_task_objects_to_worktree,
    validate_entity_dev_meta_bundle,
)


def _branch_exists(repo_root: Path, ref_name: str) -> bool:
    try:
        _run_git(repo_root, ["rev-parse", "--verify", ref_name])
        return True
    except Exception:
        return False


def _resolve_branch_ref(repo_root: Path, branch_name: str) -> str:
    branch_norm = str(branch_name or "").strip()
    if not branch_norm:
        raise ValueError("Укажите имя ветки")
    candidates = [branch_norm]
    if not branch_norm.startswith("origin/"):
        candidates.append(f"origin/{branch_norm}")
    for candidate in candidates:
        if _branch_exists(repo_root, candidate):
            return candidate
    raise ValueError(f"Ветка `{branch_norm}` не найдена")


def list_meta_workspace_branches(*, git_repo_value: str) -> dict[str, Any]:
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    git_repo_root = Path(git_repo_value).resolve()
    _run_git(git_repo_root, ["fetch", "--prune", "origin"])
    output = _run_git(
        git_repo_root,
        ["for-each-ref", "--format=%(refname:strip=3)", "refs/remotes/origin"],
    )
    branches = []
    for line in output.splitlines():
        item = str(line or "").strip()
        if not item or item == "HEAD":
            continue
        branches.append(item)
    return {"items": sorted(set(branches), key=str.lower)}


def _parse_name_status(raw_output: str) -> list[tuple[str, str]]:
    result: list[tuple[str, str]] = []
    for line in str(raw_output or "").splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        result.append((parts[0].strip().upper(), parts[-1].strip()))
    return result


def _git_show_text(repo_root: Path, ref_name: str, rel_path: str) -> str:
    try:
        return _run_git(repo_root, ["show", f"{ref_name}:{rel_path}"])
    except Exception:
        return ""


def _entity_root_parts(entity_git_root_value: str) -> tuple[str, ...]:
    return tuple(part for part in Path(entity_git_root_value).as_posix().split("/") if part)


def _click_root_parts(click_git_root_value: str) -> tuple[str, ...]:
    return tuple(part for part in Path(click_git_root_value).as_posix().split("/") if part)


def _build_branch_catalog(
    *,
    git_repo_root: Path,
    entity_git_root_value: str,
    click_git_root_value: str,
    branch_name: str,
    base_branch: str,
) -> dict[str, Any]:
    branch_ref = _resolve_branch_ref(git_repo_root, branch_name)
    base_ref = _resolve_branch_ref(git_repo_root, base_branch)
    diff_output = _run_git(
        git_repo_root,
        ["diff", "--name-status", f"{base_ref}...{branch_ref}"],
    )
    entity_root_parts = _entity_root_parts(entity_git_root_value)
    click_root_parts = _click_root_parts(click_git_root_value)
    gp_map: dict[str, dict[str, Any]] = {}
    click_map: dict[str, dict[str, Any]] = {}
    for status, raw_path in _parse_name_status(diff_output):
        path_parts = tuple(part for part in Path(raw_path).as_posix().split("/") if part)
        if entity_root_parts and path_parts[: len(entity_root_parts)] == entity_root_parts:
            rel = path_parts[len(entity_root_parts):]
            if len(rel) >= 4:
                entity_name, schema_name, table_name = rel[0], rel[1], rel[2]
                object_key = f"{entity_name}/{schema_name}/{table_name}"
                item = gp_map.setdefault(
                    object_key,
                    {
                        "object_key": object_key,
                        "entity_name": entity_name,
                        "schema_name": schema_name,
                        "table_name": table_name,
                        "changed_files": [],
                        "statuses": set(),
                    },
                )
                item["changed_files"].append("/".join(rel[3:]))
                item["statuses"].add(status[:1])
            continue
        if click_root_parts and path_parts[: len(click_root_parts)] == click_root_parts:
            rel = path_parts[len(click_root_parts):]
            if len(rel) >= 2:
                schema_name, file_name = rel[0], rel[-1]
                object_key = f"{schema_name}/{file_name}"
                item = click_map.setdefault(
                    object_key,
                    {
                        "object_key": object_key,
                        "schema_name": schema_name,
                        "file_name": file_name,
                        "object_kind": "view" if schema_name == "dm_view" else "table",
                        "statuses": set(),
                    },
                )
                item["statuses"].add(status[:1])
    gp_items = []
    for item in gp_map.values():
        status_marks = item.pop("statuses", set())
        item["changed_files"] = sorted(set(item["changed_files"]))
        item["change_type"] = "new" if "A" in status_marks else "deleted" if status_marks == {"D"} else "modified"
        gp_items.append(item)
    click_items = []
    for item in click_map.values():
        status_marks = item.pop("statuses", set())
        item["change_type"] = "new" if "A" in status_marks else "deleted" if status_marks == {"D"} else "modified"
        click_items.append(item)
    return {
        "branch_name": re.sub(r"^origin/", "", branch_ref),
        "base_branch": re.sub(r"^origin/", "", base_ref),
        "gp_objects": sorted(gp_items, key=lambda row: (row["entity_name"], row["schema_name"], row["table_name"])),
        "click_objects": sorted(click_items, key=lambda row: (row["schema_name"], row["file_name"])),
    }


def validate_meta_workspace_branch(
    *,
    engine,
    base_dir: Path,
    git_repo_value: str,
    entity_git_root_value: str,
    click_git_root_value: str,
    prod_root_value: str,
    dev_root_value: str,
    branch_name: str,
    base_branch: str,
    dev_database_url: str,
) -> dict[str, Any]:
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    git_repo_root = Path(git_repo_value).resolve()
    _run_git(git_repo_root, ["fetch", "--prune", "origin"])
    catalog = _build_branch_catalog(
        git_repo_root=git_repo_root,
        entity_git_root_value=entity_git_root_value,
        click_git_root_value=click_git_root_value,
        branch_name=branch_name,
        base_branch=base_branch,
    )
    branch_ref = _resolve_branch_ref(git_repo_root, branch_name)
    gp_results: list[dict[str, Any]] = []
    click_results: list[dict[str, Any]] = []

    for item in catalog.get("gp_objects", []):
        if item.get("change_type") == "deleted":
            gp_results.append(
                {
                    **item,
                    "valid": True,
                    "skipped": True,
                    "errors": [],
                    "warnings": ["Объект удалён в ветке, проверка содержимого пропущена"],
                    "checks": [],
                }
            )
            continue
        object_rel = Path(entity_git_root_value) / item["entity_name"] / item["schema_name"] / item["table_name"]
        yaml_content = _git_show_text(git_repo_root, branch_ref, (object_rel / "meta_data_file.yaml").as_posix())
        recreate_sql = _git_show_text(git_repo_root, branch_ref, (object_rel / "sql_query_recreate_init.sql").as_posix())
        insert_sql = _git_show_text(git_repo_root, branch_ref, (object_rel / "sql_query_insert_init.sql").as_posix())
        truncate_sql = _git_show_text(git_repo_root, branch_ref, (object_rel / "sql_query_truncate.sql").as_posix())
        yaml_payload = _load_yaml_text(yaml_content)
        validation = validate_entity_dev_meta_bundle(
            engine=engine,
            base_dir=base_dir,
            prod_root_value=prod_root_value,
            dev_root_value=dev_root_value,
            entity_name=item["entity_name"],
            schema_name=item["schema_name"],
            table_name=item["table_name"],
            key_attributes=yaml_payload.get("key_attributes") if isinstance(yaml_payload.get("key_attributes"), list) else [],
            source_object_key=None,
            yaml_content=yaml_content,
            recreate_sql=recreate_sql,
            insert_sql=insert_sql,
            truncate_sql=truncate_sql,
            dev_database_url=dev_database_url,
        )
        gp_results.append({**item, **validation, "skipped": False})

    for item in catalog.get("click_objects", []):
        if item.get("change_type") == "deleted":
            click_results.append(
                {
                    **item,
                    "valid": True,
                    "skipped": True,
                    "errors": [],
                    "warnings": ["Файл удалён в ветке, проверка содержимого пропущена"],
                }
            )
            continue
        content = _git_show_text(
            git_repo_root,
            branch_ref,
            (Path(click_git_root_value) / item["schema_name"] / item["file_name"]).as_posix(),
        )
        validation = validate_dev_meta_content(
            content=content,
            schema_name=item["schema_name"],
            dev_database_url=dev_database_url,
        )
        click_results.append({**item, **validation, "skipped": False})

    all_results = [*gp_results, *click_results]
    return {
        **catalog,
        "gp_results": gp_results,
        "click_results": click_results,
        "summary": {
            "total": len(all_results),
            "valid": sum(1 for item in all_results if item.get("valid")),
            "invalid": sum(1 for item in all_results if not item.get("valid")),
            "warnings": sum(len(item.get("warnings") or []) for item in all_results),
        },
    }


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


def _sync_meta_workspace_branch(
    *,
    engine,
    base_dir: Path,
    entity_dev_root_value: str,
    click_dev_root_value: str,
    git_repo_value: str,
    entity_git_root_value: str,
    click_git_root_value: str,
    task_id: str,
    branch_name: str,
    base_branch: str,
    author: str,
) -> dict[str, Any]:
    task_id_norm = str(task_id or "").strip().upper()
    if not task_id_norm or not task_id_norm.startswith("DWH-"):
        raise ValueError("Номер задачи должен быть в формате DWH-12345")
    branch_name_norm = str(branch_name or "").strip()
    if not branch_name_norm:
        raise ValueError("Укажите ветку для сохранения")
    base_branch_norm = str(base_branch or "").strip()
    if not base_branch_norm:
        raise ValueError("Укажите base-ветку")
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")

    entity_dev_root = _resolve_root(base_dir, entity_dev_root_value)
    click_dev_root = _resolve_root(base_dir, click_dev_root_value)
    git_repo_root = Path(git_repo_value).resolve()
    entity_git_root_rel = Path(entity_git_root_value)
    click_git_root_rel = Path(click_git_root_value)

    entity_object_keys = _list_task_entity_object_keys(engine=engine, task_id=task_id_norm)
    click_files = _list_task_click_meta_files(engine=engine, task_id=task_id_norm)
    if not entity_object_keys and not click_files:
        raise ValueError(f"Не найдено изменений для задачи {task_id_norm}")

    _run_git(git_repo_root, ["fetch", "--prune", "origin"])
    remote_branch_exists = bool(_run_git(git_repo_root, ["ls-remote", "--heads", "origin", branch_name_norm]))
    if not remote_branch_exists and not bool(_run_git(git_repo_root, ["ls-remote", "--heads", "origin", base_branch_norm])):
        raise ValueError(f"Base-ветка `{base_branch_norm}` не найдена в origin")

    worktree_dir = Path(tempfile.mkdtemp(prefix=f"meta-workspace-sync-{task_id_norm.lower()}-"))
    try:
        if remote_branch_exists:
            _run_git(git_repo_root, ["worktree", "add", "-B", branch_name_norm, str(worktree_dir), f"origin/{branch_name_norm}"])
        else:
            _run_git(git_repo_root, ["worktree", "add", "-B", branch_name_norm, str(worktree_dir), f"origin/{base_branch_norm}"])
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
        committed = False
        if status_output:
            _run_git(git_repo_root, ["add", "."], cwd=worktree_dir)
            _run_git(git_repo_root, ["commit", "-m", f"{task_id_norm}: sync meta workspace changes"], cwd=worktree_dir)
            committed = True

        _run_git(git_repo_root, ["push", "origin", f"HEAD:{branch_name_norm}"], cwd=worktree_dir)

        _audit_dev_meta(
            engine,
            ENTITY_LOCK_SCHEMA,
            task_id_norm,
            author,
            "sync_meta_workspace_branch",
            "",
            {
                "task_id": task_id_norm,
                "feature_branch": branch_name_norm,
                "base_branch": base_branch_norm,
                "gp_object_keys": sorted(entity_object_keys),
                "click_files": click_files,
                "committed": committed,
            },
        )
        return {
            "task_id": task_id_norm,
            "branch_name": branch_name_norm,
            "base_branch": base_branch_norm,
            "gp_object_keys": sorted(entity_object_keys),
            "click_files": click_files,
            "updated_paths": [*entity_sync["updated_paths"], *click_sync["updated_paths"]],
            "removed_paths": [*entity_sync["removed_paths"], *click_sync["removed_paths"]],
            "committed": committed,
        }
    finally:
        try:
            _run_git(git_repo_root, ["worktree", "remove", "--force", str(worktree_dir)])
        except Exception:
            pass
        shutil.rmtree(worktree_dir, ignore_errors=True)


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


def sync_meta_workspace_branch(
    *,
    engine,
    base_dir: Path,
    entity_dev_root_value: str,
    click_dev_root_value: str,
    git_repo_value: str,
    entity_git_root_value: str,
    click_git_root_value: str,
    task_id: str,
    branch_name: str,
    base_branch: str,
    author: str,
) -> dict[str, Any]:
    return _sync_meta_workspace_branch(
        engine=engine,
        base_dir=base_dir,
        entity_dev_root_value=entity_dev_root_value,
        click_dev_root_value=click_dev_root_value,
        git_repo_value=git_repo_value,
        entity_git_root_value=entity_git_root_value,
        click_git_root_value=click_git_root_value,
        task_id=task_id,
        branch_name=branch_name,
        base_branch=base_branch,
        author=author,
    )
