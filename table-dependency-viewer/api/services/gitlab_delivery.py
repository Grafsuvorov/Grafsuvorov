"""Reusable GitLab repository delivery operations."""

import base64
import os
from typing import Any, Optional
from urllib import parse as urlparse

from .entity_dev_meta import _gitlab_json_request, _parse_gitlab_project


def _ssl_verify() -> bool:
    return os.getenv("GITLAB_SSL_VERIFY", "true").strip().lower() not in {"0", "false", "no", "off"}


def _api_url() -> str:
    return os.getenv("GITLAB_API_URL", "")


def resource_exists(*, project: str, token: str, path: str, query: Optional[dict[str, Any]] = None) -> bool:
    try:
        _gitlab_json_request(api_url=_api_url(), project=project, token=token, ssl_verify=_ssl_verify(), path=path, method="GET", query=query)
        return True
    except ValueError as exc:
        if "GitLab вернул 404" in str(exc):
            return False
        raise


def file_content(*, project: str, token: str, file_path: str, ref: str) -> Optional[str]:
    try:
        payload = _gitlab_json_request(
            api_url=_api_url(), project=project, token=token, ssl_verify=_ssl_verify(),
            path=f"repository/files/{urlparse.quote(file_path, safe='')}", method="GET", query={"ref": ref},
        )
    except ValueError as exc:
        if "GitLab вернул 404" in str(exc):
            return None
        raise
    raw_content = str((payload or {}).get("content") or "")
    if str((payload or {}).get("encoding") or "").lower() == "base64":
        try:
            return base64.b64decode(raw_content).decode("utf-8")
        except (ValueError, UnicodeDecodeError) as exc:
            raise ValueError(f"GitLab вернул некорректное содержимое файла {file_path}") from exc
    return raw_content


def publish_files(*, project: str, token: str, task_id: str, target_branch: str, title: str, description: str, files: list[dict[str, str]], commit_message: Optional[str] = None) -> dict[str, Any]:
    if not token:
        raise ValueError("Не настроен GitLab token")
    project_ref = _parse_gitlab_project(project)
    if not project_ref:
        raise ValueError("Не настроен GitLab project")
    branch = f"feature/{task_id}"
    exists = resource_exists(project=project_ref, token=token, path=f"repository/branches/{urlparse.quote(branch, safe='')}")
    ref = branch if exists else target_branch
    actions = []
    for item in files:
        old = file_content(project=project_ref, token=token, file_path=item["path"], ref=ref)
        if old != item["content"]:
            actions.append({"action": "update" if old is not None else "create", "file_path": item["path"], "content": item["content"], "encoding": "text"})
    if not actions:
        return {"status": "skipped", "branch_name": branch, "target_branch": target_branch, "files": [item["path"] for item in files]}
    payload: dict[str, Any] = {"branch": branch, "commit_message": commit_message or f"{task_id}: update files", "actions": actions}
    if not exists:
        payload["start_branch"] = target_branch
    request_args = {"api_url": _api_url(), "project": project_ref, "token": token, "ssl_verify": _ssl_verify()}
    _gitlab_json_request(**request_args, path="repository/commits", method="POST", payload=payload)
    opened = _gitlab_json_request(**request_args, path="merge_requests", query={"state": "opened", "source_branch": branch, "target_branch": target_branch})
    mr = opened[0] if opened else _gitlab_json_request(**request_args, path="merge_requests", method="POST", payload={"source_branch": branch, "target_branch": target_branch, "title": title, "description": description, "remove_source_branch": False})
    return {"status": "ok", "branch_name": branch, "target_branch": target_branch, "files": [item["path"] for item in files], "mr_url": mr.get("web_url")}


_prototype_gitlab_resource_exists = resource_exists
_prototype_gitlab_file_content = file_content


def _business_dq_publish(**kwargs):
    return publish_files(commit_message=f"{kwargs['task_id']}: add business DQ", **kwargs)
