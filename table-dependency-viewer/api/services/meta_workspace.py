from __future__ import annotations

import fcntl
import json
import re
import shutil
import tempfile
import time
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


class BranchRevisionConflictError(PermissionError):
    pass


_FETCH_REF_ERROR_RE = re.compile(r"cannot lock ref '([^']+)'")
_INDEX_LOCK_ERROR_RE = re.compile(r"index\.lock")
_INDEX_CORRUPT_ERROR_RE = re.compile(r"index file smaller than expected", re.IGNORECASE)
_INDEX_WRITE_ERROR_RE = re.compile(r"could not write new index file", re.IGNORECASE)
_WORKSPACE_FS_ERROR_RE = re.compile(
    r"(unable to unlink old|unable to create file|cannot create directory at).*(No such file or directory)?",
    re.IGNORECASE,
)


def _workspace_slug(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", str(value or "").strip().lower()).strip("-")
    return slug or "default"


def _workspace_path(workspace_root_value: str, workspace_owner: str) -> Path:
    return Path(workspace_root_value).resolve() / _workspace_slug(workspace_owner) / "repo"


def _git_origin_url(git_repo_root: Path) -> str:
    return _run_git(git_repo_root, ["remote", "get-url", "origin"])


def _with_repo_lock(git_repo_root: Path, callback):
    lock_path = git_repo_root / ".meta-workspace-fetch.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+", encoding="utf-8") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            return callback()
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def _with_workspace_lock(workspace_dir: Path, callback):
    lock_path = workspace_dir.parent / ".workspace.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+", encoding="utf-8") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            return callback()
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def _clear_stale_index_lock(workspace_dir: Path) -> None:
    index_lock = workspace_dir / ".git" / "index.lock"
    if index_lock.exists():
        try:
            index_lock.unlink()
        except Exception:
            pass


def _clear_corrupt_index(workspace_dir: Path) -> None:
    index_path = workspace_dir / ".git" / "index"
    if index_path.exists():
        try:
            index_path.unlink()
        except Exception:
            pass


def _run_workspace_git(git_repo_root: Path, args: list[str], *, cwd: Path) -> str:
    last_error = None
    for attempt in range(2):
        try:
            return _run_git(git_repo_root, args, cwd=cwd)
        except ValueError as exc:
            last_error = exc
            error_text = str(exc)
            if attempt > 0:
                raise
            recovered = False
            if _INDEX_LOCK_ERROR_RE.search(error_text):
                _clear_stale_index_lock(cwd)
                recovered = True
            if _INDEX_CORRUPT_ERROR_RE.search(error_text):
                _clear_corrupt_index(cwd)
                recovered = True
            if _INDEX_WRITE_ERROR_RE.search(error_text):
                _clear_stale_index_lock(cwd)
                _clear_corrupt_index(cwd)
                recovered = True
            if not recovered:
                raise
            time.sleep(0.1)
    if last_error:
        raise last_error
    return ""


def _fetch_prune_origin(git_repo_root: Path, *, cwd: Path | None = None) -> None:
    def _run_fetch():
        last_error = None
        for attempt in range(2):
            try:
                _run_git(git_repo_root, ["fetch", "--prune", "origin"], cwd=cwd)
                return
            except ValueError as exc:
                last_error = exc
                match = _FETCH_REF_ERROR_RE.search(str(exc))
                if not match or attempt > 0:
                    raise
                ref_name = str(match.group(1) or "").strip()
                if ref_name:
                    try:
                        _run_git(git_repo_root, ["update-ref", "-d", ref_name], cwd=cwd)
                    except Exception:
                        pass
                time.sleep(0.2)
        if last_error:
            raise last_error

    if cwd is None:
        _with_repo_lock(git_repo_root, _run_fetch)
    else:
        _run_fetch()


def _cleanup_legacy_owner_workspaces(*, git_repo_root: Path, owner_root: Path, keep_path: Path) -> None:
    if not owner_root.exists():
        return
    keep_resolved = keep_path.resolve()
    for child in owner_root.iterdir():
        child_resolved = child.resolve()
        if child_resolved == keep_resolved:
            continue
        if child.is_dir():
            try:
                _run_git(git_repo_root, ["worktree", "remove", "--force", str(child)])
            except Exception:
                pass
            shutil.rmtree(child, ignore_errors=True)
        else:
            try:
                child.unlink()
            except Exception:
                pass


def _ensure_workspace_repo(*, git_repo_root: Path, workspace_dir: Path, target_ref: str) -> None:
    if workspace_dir.exists():
        if workspace_dir.is_dir():
            try:
                _run_git(git_repo_root, ["worktree", "remove", "--force", str(workspace_dir)])
            except Exception:
                pass
            shutil.rmtree(workspace_dir, ignore_errors=True)
        else:
            workspace_dir.unlink(missing_ok=True)
    workspace_dir.parent.mkdir(parents=True, exist_ok=True)
    try:
        _run_git(git_repo_root, ["worktree", "prune"])
    except Exception:
        pass
    try:
        _run_git(
            git_repo_root,
            ["worktree", "add", "--force", "--detach", str(workspace_dir), target_ref],
        )
    except Exception:
        try:
            _run_git(git_repo_root, ["worktree", "remove", "--force", str(workspace_dir)])
        except Exception:
            pass
        shutil.rmtree(workspace_dir, ignore_errors=True)
        raise
    if not (workspace_dir / ".git").exists():
        raise ValueError(f"Не удалось создать workspace `{workspace_dir}`")


def _recreate_workspace_repo(
    *,
    git_repo_root: Path,
    workspace_dir: Path,
    target_ref: str,
    author: str | None = None,
) -> None:
    if workspace_dir.exists():
        shutil.rmtree(workspace_dir, ignore_errors=True)
    _ensure_workspace_repo(git_repo_root=git_repo_root, workspace_dir=workspace_dir, target_ref=target_ref)
    if author:
        _ensure_git_identity(repo_root=git_repo_root, cwd=workspace_dir, author=author)


def _ensure_branch_workspace(
    *,
    git_repo_root: Path,
    workspace_root_value: str,
    workspace_owner: str,
    branch_name: str,
    base_branch: str,
    author: str | None = None,
) -> tuple[str, Path]:
    branch_name_norm = str(branch_name or "").strip()
    if not branch_name_norm:
        raise ValueError("Укажите имя ветки")
    base_branch_norm = str(base_branch or "").strip() or "main"
    workspace_root = Path(workspace_root_value or "/var/lib/table-dependency-viewer/meta-workspaces").resolve()
    worktree_dir = _workspace_path(str(workspace_root), workspace_owner)

    _fetch_prune_origin(git_repo_root)
    try:
        _run_git(git_repo_root, ["worktree", "prune"])
    except Exception:
        pass
    remote_branch_exists = bool(_run_git(git_repo_root, ["ls-remote", "--heads", "origin", branch_name_norm]))
    if not remote_branch_exists and not bool(_run_git(git_repo_root, ["ls-remote", "--heads", "origin", base_branch_norm])):
        raise ValueError(f"Base-ветка `{base_branch_norm}` не найдена в origin")

    owner_root = worktree_dir.parent
    owner_root.mkdir(parents=True, exist_ok=True)

    target_ref = f"origin/{branch_name_norm}" if remote_branch_exists else f"origin/{base_branch_norm}"

    def _sync_workspace_checkout():
        _clear_stale_index_lock(worktree_dir)

        if author:
            _ensure_git_identity(repo_root=git_repo_root, cwd=worktree_dir, author=author)
        try:
            _run_workspace_git(git_repo_root, ["reset", "--hard"], cwd=worktree_dir)
            _run_workspace_git(git_repo_root, ["clean", "-fdx"], cwd=worktree_dir)
        except Exception:
            pass

        _run_workspace_git(git_repo_root, ["reset", "--hard", target_ref], cwd=worktree_dir)
        _run_workspace_git(git_repo_root, ["clean", "-fdx"], cwd=worktree_dir)

    def _prepare_workspace():
        _cleanup_legacy_owner_workspaces(git_repo_root=git_repo_root, owner_root=owner_root, keep_path=worktree_dir)
        _recreate_workspace_repo(
            git_repo_root=git_repo_root,
            workspace_dir=worktree_dir,
            target_ref=target_ref,
            author=author,
        )
        _sync_workspace_checkout()

    _with_workspace_lock(worktree_dir, _prepare_workspace)
    return branch_name_norm, worktree_dir


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
    _fetch_prune_origin(git_repo_root)
    output = _run_git(
        git_repo_root,
        ["for-each-ref", "--sort=-committerdate", "--format=%(refname:strip=3)", "refs/remotes/origin"],
    )
    branches: list[str] = []
    seen: set[str] = set()
    for line in output.splitlines():
        item = str(line or "").strip()
        if not item or item == "HEAD":
            continue
        key = item.lower()
        if key in seen:
            continue
        seen.add(key)
        branches.append(item)
    return {"items": branches}


def create_meta_workspace_branch(*, git_repo_value: str, branch_name: str, base_branch: str) -> dict[str, Any]:
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    git_repo_root = Path(git_repo_value).resolve()
    branch_name_norm = str(branch_name or "").strip()
    if not branch_name_norm:
        raise ValueError("Укажите имя новой ветки")
    base_branch_norm = str(base_branch or "").strip() or "main"

    _fetch_prune_origin(git_repo_root)
    if bool(_run_git(git_repo_root, ["ls-remote", "--heads", "origin", branch_name_norm])):
        return {
            "branch_name": branch_name_norm,
            "base_branch": base_branch_norm,
            "created": False,
            "already_exists": True,
        }
    if not bool(_run_git(git_repo_root, ["ls-remote", "--heads", "origin", base_branch_norm])):
        raise ValueError(f"Base-ветка `{base_branch_norm}` не найдена в origin")

    worktree_dir = Path(tempfile.mkdtemp(prefix=f"meta-workspace-branch-{branch_name_norm.replace('/', '-')}-"))
    try:
        _run_git(git_repo_root, ["worktree", "add", "-b", branch_name_norm, str(worktree_dir), f"origin/{base_branch_norm}"])
        _run_git(git_repo_root, ["push", "-u", "origin", branch_name_norm], cwd=worktree_dir)
    finally:
        try:
            _run_git(git_repo_root, ["worktree", "remove", "--force", str(worktree_dir)])
        except Exception:
            pass
        shutil.rmtree(worktree_dir, ignore_errors=True)

    return {
        "branch_name": branch_name_norm,
        "base_branch": base_branch_norm,
        "created": True,
        "already_exists": False,
    }


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


def _git_object_oid(repo_root: Path, ref_name: str, rel_path: str, *, cwd: Path | None = None) -> str:
    rel_norm = str(rel_path or "").strip().strip("/")
    if not rel_norm:
        return ""
    try:
        return str(_run_git(repo_root, ["rev-parse", f"{ref_name}:{rel_norm}"], cwd=cwd)).strip()
    except Exception:
        return ""


def _build_branch_file_revision(repo_root: Path, ref_name: str, rel_path: str, *, cwd: Path | None = None) -> dict[str, str]:
    path_norm = str(rel_path or "").strip().strip("/")
    return {
        "type": "file",
        "path": path_norm,
        "oid": _git_object_oid(repo_root, ref_name, path_norm, cwd=cwd),
    }


def _build_branch_gp_revision(repo_root: Path, ref_name: str, object_rel: Path, *, cwd: Path | None = None) -> dict[str, Any]:
    files = [
        "meta_data_file.yaml",
        "sql_query_recreate_init.sql",
        "sql_query_insert_init.sql",
        "sql_query_truncate.sql",
    ]
    mapping = {
        file_name: _git_object_oid(repo_root, ref_name, (object_rel / file_name).as_posix(), cwd=cwd)
        for file_name in files
    }
    return {
        "type": "gp_bundle",
        "path": object_rel.as_posix(),
        "files": mapping,
    }


def _assert_branch_file_revision_matches(
    repo_root: Path,
    ref_name: str,
    rel_path: str,
    expected_revision: dict[str, Any] | None,
) -> None:
    if not expected_revision:
        return
    actual_revision = _build_branch_file_revision(repo_root, ref_name, rel_path)
    if (
        str(expected_revision.get("path") or "").strip().strip("/") != actual_revision["path"]
        or str(expected_revision.get("oid") or "") != actual_revision["oid"]
    ):
        raise BranchRevisionConflictError(
            f"Файл `{actual_revision['path']}` изменился в ветке после открытия. Обновите его и повторите сохранение."
        )


def _assert_branch_gp_revision_matches(
    repo_root: Path,
    ref_name: str,
    object_rel: Path,
    expected_revision: dict[str, Any] | None,
) -> None:
    if not expected_revision:
        return
    actual_revision = _build_branch_gp_revision(repo_root, ref_name, object_rel)
    expected_path = str(expected_revision.get("path") or "").strip().strip("/")
    actual_path = actual_revision["path"]
    expected_files = expected_revision.get("files") or {}
    actual_files = actual_revision["files"]
    if expected_path != actual_path or {
        str(key): str(value or "")
        for key, value in expected_files.items()
    } != actual_files:
        raise BranchRevisionConflictError(
            f"Объект `{actual_path}` изменился в ветке после открытия. Обновите его и повторите сохранение."
        )


def _git_list_tree_files(repo_root: Path, ref_name: str, rel_root: str) -> list[str]:
    args = ["ls-tree", "-r", "--name-only", ref_name]
    rel_root_norm = str(rel_root or "").strip().strip("/")
    if rel_root_norm:
        args.extend(["--", rel_root_norm])
    output = _run_git(repo_root, args)
    return [line.strip() for line in output.splitlines() if line.strip()]


def _git_path_exists(repo_root: Path, ref_name: str, rel_path: str) -> bool:
    return str(rel_path or "").strip() in set(_git_list_tree_files(repo_root, ref_name, rel_path))


def _entity_root_parts(entity_git_root_value: str) -> tuple[str, ...]:
    return tuple(part for part in Path(entity_git_root_value).as_posix().split("/") if part)


def _click_root_parts(click_git_root_value: str) -> tuple[str, ...]:
    return tuple(part for part in Path(click_git_root_value).as_posix().split("/") if part)


def _build_branch_catalog(
    *,
    git_repo_root: Path,
    entity_git_root_value: str,
    click_git_root_value: str,
    workspace_root_value: str,
    workspace_owner: str,
    branch_name: str,
    base_branch: str,
) -> dict[str, Any]:
    branch_ref, worktree_dir = _ensure_branch_workspace(
        git_repo_root=git_repo_root,
        workspace_root_value=workspace_root_value,
        workspace_owner=workspace_owner,
        branch_name=branch_name,
        base_branch=base_branch,
    )
    base_ref = _resolve_branch_ref(git_repo_root, base_branch)
    diff_output = _run_git(
        git_repo_root,
        ["diff", "--name-status", f"{base_ref}...HEAD"],
        cwd=worktree_dir,
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
        "workspace_path": str(worktree_dir),
    }


def build_meta_workspace_branch_tree(
    *,
    git_repo_value: str,
    entity_git_root_value: str,
    click_git_root_value: str,
    workspace_root_value: str,
    workspace_owner: str,
    branch_name: str,
    base_branch: str,
) -> dict[str, Any]:
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    git_repo_root = Path(git_repo_value).resolve()
    branch_ref, worktree_dir = _ensure_branch_workspace(
        git_repo_root=git_repo_root,
        workspace_root_value=workspace_root_value,
        workspace_owner=workspace_owner,
        branch_name=branch_name,
        base_branch=base_branch,
    )
    catalog = _build_branch_catalog(
        git_repo_root=git_repo_root,
        entity_git_root_value=entity_git_root_value,
        click_git_root_value=click_git_root_value,
        workspace_root_value=workspace_root_value,
        workspace_owner=workspace_owner,
        branch_name=branch_name,
        base_branch=base_branch,
    )
    changed_paths = {
        item
        for _status, item in _parse_name_status(
            _run_git(git_repo_root, ["diff", "--name-status", f"{_resolve_branch_ref(git_repo_root, base_branch)}...HEAD"], cwd=worktree_dir)
        )
    }

    gp_tree_map: dict[str, dict[str, dict[str, list[dict[str, Any]]]]] = {}
    gp_root = (worktree_dir / entity_git_root_value).resolve()
    if gp_root.exists():
        for file_path in gp_root.rglob("*"):
            if not file_path.is_file():
                continue
            raw_path = file_path.relative_to(worktree_dir).as_posix()
            path_parts = tuple(part for part in Path(raw_path).as_posix().split("/") if part)
            root_parts = _entity_root_parts(entity_git_root_value)
            if path_parts[: len(root_parts)] != root_parts:
                continue
            rel = path_parts[len(root_parts):]
            if len(rel) < 4:
                continue
            entity_name, schema_name, table_name = rel[0], rel[1], rel[2]
            file_name = "/".join(rel[3:])
            gp_tree_map.setdefault(entity_name, {}).setdefault(schema_name, {}).setdefault(table_name, []).append(
                {
                    "file_name": file_name,
                    "file_path": raw_path,
                    "changed": raw_path in changed_paths,
                }
            )

    gp_entities = []
    for entity_name, schema_map in sorted(gp_tree_map.items(), key=lambda item: item[0].lower()):
        schemas = []
        for schema_name, table_map in sorted(schema_map.items(), key=lambda item: item[0].lower()):
            tables = []
            for table_name, files in sorted(table_map.items(), key=lambda item: item[0].lower()):
                files_sorted = sorted(files, key=lambda item: item["file_name"].lower())
                tables.append(
                    {
                        "table_name": table_name,
                        "changed": any(item["changed"] for item in files_sorted),
                        "files": files_sorted,
                    }
                )
            schemas.append({"schema_name": schema_name, "tables": tables})
        gp_entities.append({"entity_name": entity_name, "schemas": schemas})

    click_tree_map: dict[str, list[dict[str, Any]]] = {}
    click_root = (worktree_dir / click_git_root_value).resolve()
    if click_root.exists():
        for file_path in click_root.rglob("*"):
            if not file_path.is_file():
                continue
            raw_path = file_path.relative_to(worktree_dir).as_posix()
            path_parts = tuple(part for part in Path(raw_path).as_posix().split("/") if part)
            root_parts = _click_root_parts(click_git_root_value)
            if path_parts[: len(root_parts)] != root_parts:
                continue
            rel = path_parts[len(root_parts):]
            if len(rel) < 2:
                continue
            schema_name = rel[0]
            file_name = "/".join(rel[1:])
            click_tree_map.setdefault(schema_name, []).append(
                {
                    "file_name": file_name,
                    "file_path": raw_path,
                    "changed": raw_path in changed_paths,
                }
            )

    click_schemas = [
        {
            "schema_name": schema_name,
            "files": sorted(files, key=lambda item: item["file_name"].lower()),
        }
        for schema_name, files in sorted(click_tree_map.items(), key=lambda item: item[0].lower())
    ]

    return {
        "branch_name": re.sub(r"^origin/", "", branch_ref),
        "base_branch": catalog["base_branch"],
        "gp_entities": gp_entities,
        "click_schemas": click_schemas,
        "workspace_path": str(worktree_dir),
    }


def read_meta_workspace_branch_file(
    *,
    git_repo_value: str,
    workspace_root_value: str,
    workspace_owner: str,
    branch_name: str,
    base_branch: str,
    file_path: str,
) -> dict[str, Any]:
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    path_norm = str(file_path or "").strip().strip("/")
    if not path_norm:
        raise ValueError("Не указан путь к файлу")
    git_repo_root = Path(git_repo_value).resolve()
    branch_ref, worktree_dir = _ensure_branch_workspace(
        git_repo_root=git_repo_root,
        workspace_root_value=workspace_root_value,
        workspace_owner=workspace_owner,
        branch_name=branch_name,
        base_branch=base_branch,
    )
    target_path = (worktree_dir / path_norm).resolve()
    if not str(target_path).startswith(str(worktree_dir.resolve())):
        raise ValueError("Некорректный путь файла")
    if not target_path.exists():
        raise ValueError(f"Файл `{path_norm}` не найден в ветке `{branch_name}`")
    content = target_path.read_text(encoding="utf-8")
    return {
        "branch_name": re.sub(r"^origin/", "", branch_ref),
        "file_path": path_norm,
        "content": content,
        "revision": _build_branch_file_revision(git_repo_root, "HEAD", path_norm, cwd=worktree_dir),
        "workspace_path": str(worktree_dir),
    }


def read_meta_workspace_branch_gp_bundle(
    *,
    git_repo_value: str,
    entity_git_root_value: str,
    workspace_root_value: str,
    workspace_owner: str,
    branch_name: str,
    base_branch: str,
    entity_name: str,
    schema_name: str,
    table_name: str,
) -> dict[str, Any]:
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    git_repo_root = Path(git_repo_value).resolve()
    branch_ref, worktree_dir = _ensure_branch_workspace(
        git_repo_root=git_repo_root,
        workspace_root_value=workspace_root_value,
        workspace_owner=workspace_owner,
        branch_name=branch_name,
        base_branch=base_branch,
    )
    object_rel = Path(entity_git_root_value) / entity_name / schema_name / table_name
    object_dir = (worktree_dir / object_rel).resolve()
    if not str(object_dir).startswith(str(worktree_dir.resolve())):
        raise ValueError("Некорректный путь объекта")
    yaml_path = object_dir / "meta_data_file.yaml"
    if not yaml_path.exists():
        raise ValueError(f"Объект `{entity_name}/{schema_name}/{table_name}` не найден в ветке `{branch_name}`")
    yaml_content = yaml_path.read_text(encoding="utf-8")
    payload = _load_yaml_text(yaml_content)
    return {
        "branch_name": re.sub(r"^origin/", "", branch_ref),
        "entity_name": entity_name,
        "schema_name": schema_name,
        "table_name": table_name,
        "object_key": f"{entity_name}/{schema_name}/{table_name}",
        "yaml_content": yaml_content,
        "key_attributes": payload.get("key_attributes") if isinstance(payload.get("key_attributes"), list) else [],
        "recreate_sql": (object_dir / "sql_query_recreate_init.sql").read_text(encoding="utf-8") if (object_dir / "sql_query_recreate_init.sql").exists() else "",
        "insert_sql": (object_dir / "sql_query_insert_init.sql").read_text(encoding="utf-8") if (object_dir / "sql_query_insert_init.sql").exists() else "",
        "truncate_sql": (object_dir / "sql_query_truncate.sql").read_text(encoding="utf-8") if (object_dir / "sql_query_truncate.sql").exists() else "",
        "revision": _build_branch_gp_revision(git_repo_root, "HEAD", object_rel, cwd=worktree_dir),
        "source": "branch",
        "exists": True,
        "path": object_rel.as_posix(),
        "workspace_path": str(worktree_dir),
    }


def save_meta_workspace_branch_file(
    *,
    git_repo_value: str,
    workspace_root_value: str,
    workspace_owner: str,
    branch_name: str,
    base_branch: str,
    file_path: str,
    content: str,
    task_id: str,
    author: str,
    expected_revision: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    branch_name_norm = str(branch_name or "").strip()
    if not branch_name_norm:
        raise ValueError("Укажите ветку")
    base_branch_norm = str(base_branch or "").strip() or "main"
    file_path_norm = str(file_path or "").strip().strip("/")
    if not file_path_norm:
        raise ValueError("Не указан путь к файлу")

    git_repo_root = Path(git_repo_value).resolve()
    branch_ref, worktree_dir = _ensure_branch_workspace(
        git_repo_root=git_repo_root,
        workspace_root_value=workspace_root_value,
        workspace_owner=workspace_owner,
        branch_name=branch_name_norm,
        base_branch=base_branch_norm,
        author=author,
    )
    committed = False

    def _save_file():
        nonlocal committed
        _assert_branch_file_revision_matches(git_repo_root, "HEAD", file_path_norm, expected_revision)

        target_path = (worktree_dir / file_path_norm).resolve()
        if not str(target_path).startswith(str(worktree_dir.resolve())):
            raise ValueError("Некорректный путь файла")
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_text(str(content or ""), encoding="utf-8")

        status_output = _run_workspace_git(git_repo_root, ["status", "--porcelain", "--", file_path_norm], cwd=worktree_dir)
        if status_output:
            _run_workspace_git(git_repo_root, ["add", "--", file_path_norm], cwd=worktree_dir)
            task_id_norm = str(task_id or "").strip().upper()
            commit_prefix = task_id_norm if task_id_norm else branch_name_norm
            _run_workspace_git(git_repo_root, ["commit", "-m", f"{commit_prefix}: update {Path(file_path_norm).name}"], cwd=worktree_dir)
            committed = True

        _run_workspace_git(git_repo_root, ["push", "origin", f"HEAD:{branch_ref}"], cwd=worktree_dir)

    _with_workspace_lock(worktree_dir, _save_file)
    return {
        "branch_name": branch_name_norm,
        "base_branch": base_branch_norm,
        "file_path": file_path_norm,
        "committed": committed,
        "revision": _build_branch_file_revision(git_repo_root, "HEAD", file_path_norm, cwd=worktree_dir),
        "workspace_path": str(worktree_dir),
    }


def save_meta_workspace_branch_gp_bundle(
    *,
    git_repo_value: str,
    entity_git_root_value: str,
    workspace_root_value: str,
    workspace_owner: str,
    branch_name: str,
    base_branch: str,
    entity_name: str,
    schema_name: str,
    table_name: str,
    yaml_content: str,
    recreate_sql: str,
    insert_sql: str,
    truncate_sql: str,
    task_id: str,
    author: str,
    expected_revision: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    branch_name_norm = str(branch_name or "").strip()
    if not branch_name_norm:
        raise ValueError("Укажите ветку")
    base_branch_norm = str(base_branch or "").strip() or "main"
    entity_name_norm = str(entity_name or "").strip()
    schema_name_norm = str(schema_name or "").strip()
    table_name_norm = str(table_name or "").strip()
    if not entity_name_norm or not schema_name_norm or not table_name_norm:
        raise ValueError("Укажите сущность, схему и таблицу")

    git_repo_root = Path(git_repo_value).resolve()
    object_rel = Path(entity_git_root_value) / entity_name_norm / schema_name_norm / table_name_norm
    branch_ref, worktree_dir = _ensure_branch_workspace(
        git_repo_root=git_repo_root,
        workspace_root_value=workspace_root_value,
        workspace_owner=workspace_owner,
        branch_name=branch_name_norm,
        base_branch=base_branch_norm,
        author=author,
    )
    committed = False

    def _save_bundle():
        nonlocal committed
        _assert_branch_gp_revision_matches(git_repo_root, "HEAD", object_rel, expected_revision)

        object_dir = (worktree_dir / object_rel).resolve()
        if not str(object_dir).startswith(str(worktree_dir.resolve())):
            raise ValueError("Некорректный путь объекта")
        object_dir.mkdir(parents=True, exist_ok=True)

        files_to_write = {
            "meta_data_file.yaml": str(yaml_content or ""),
            "sql_query_recreate_init.sql": str(recreate_sql or ""),
            "sql_query_insert_init.sql": str(insert_sql or ""),
            "sql_query_truncate.sql": str(truncate_sql or ""),
        }
        for file_name, content in files_to_write.items():
            target_path = object_dir / file_name
            target_path.write_text(content, encoding="utf-8")

        status_output = _run_workspace_git(git_repo_root, ["status", "--porcelain", "--", object_rel.as_posix()], cwd=worktree_dir)
        if status_output:
            _run_workspace_git(git_repo_root, ["add", "--", object_rel.as_posix()], cwd=worktree_dir)
            task_id_norm = str(task_id or "").strip().upper()
            commit_prefix = task_id_norm if task_id_norm else branch_name_norm
            _run_workspace_git(
                git_repo_root,
                ["commit", "-m", f"{commit_prefix}: update {entity_name_norm}/{schema_name_norm}/{table_name_norm}"],
                cwd=worktree_dir,
            )
            committed = True

        _run_workspace_git(git_repo_root, ["push", "origin", f"HEAD:{branch_ref}"], cwd=worktree_dir)

    _with_workspace_lock(worktree_dir, _save_bundle)
    return {
        "branch_name": branch_name_norm,
        "base_branch": base_branch_norm,
        "object_key": f"{entity_name_norm}/{schema_name_norm}/{table_name_norm}",
        "path": object_rel.as_posix(),
        "changed_files": rel_paths,
        "committed": committed,
        "revision": _build_branch_gp_revision(git_repo_root, "HEAD", object_rel, cwd=worktree_dir),
        "workspace_path": str(worktree_dir),
    }


def validate_meta_workspace_branch(
    *,
    engine,
    base_dir: Path,
    git_repo_value: str,
    entity_git_root_value: str,
    click_git_root_value: str,
    workspace_root_value: str,
    workspace_owner: str,
    prod_root_value: str,
    dev_root_value: str,
    branch_name: str,
    base_branch: str,
    dev_database_url: str,
) -> dict[str, Any]:
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    git_repo_root = Path(git_repo_value).resolve()
    _fetch_prune_origin(git_repo_root)
    catalog = _build_branch_catalog(
        git_repo_root=git_repo_root,
        entity_git_root_value=entity_git_root_value,
        click_git_root_value=click_git_root_value,
        workspace_root_value=workspace_root_value,
        workspace_owner=workspace_owner,
        branch_name=branch_name,
        base_branch=base_branch,
    )
    branch_ref, worktree_dir = _ensure_branch_workspace(
        git_repo_root=git_repo_root,
        workspace_root_value=workspace_root_value,
        workspace_owner=workspace_owner,
        branch_name=branch_name,
        base_branch=base_branch,
    )
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
        object_dir = worktree_dir / object_rel
        yaml_content = (object_dir / "meta_data_file.yaml").read_text(encoding="utf-8") if (object_dir / "meta_data_file.yaml").exists() else ""
        recreate_sql = (object_dir / "sql_query_recreate_init.sql").read_text(encoding="utf-8") if (object_dir / "sql_query_recreate_init.sql").exists() else ""
        insert_sql = (object_dir / "sql_query_insert_init.sql").read_text(encoding="utf-8") if (object_dir / "sql_query_insert_init.sql").exists() else ""
        truncate_sql = (object_dir / "sql_query_truncate.sql").read_text(encoding="utf-8") if (object_dir / "sql_query_truncate.sql").exists() else ""
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
        click_path = worktree_dir / click_git_root_value / item["schema_name"] / item["file_name"]
        content = click_path.read_text(encoding="utf-8") if click_path.exists() else ""
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
