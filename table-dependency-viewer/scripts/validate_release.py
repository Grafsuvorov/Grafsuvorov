#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

try:
    from ytrek_release_slots_by_date import (
        extract_linked_issue_ids as yt_extract_linked_issue_ids,
        fetch_candidate_release_slots as yt_fetch_candidate_release_slots,
        is_release_slot as yt_is_release_slot,
        issue_release_date as yt_issue_release_date,
    )
except Exception:  # pragma: no cover - optional helper import
    yt_extract_linked_issue_ids = None
    yt_fetch_candidate_release_slots = None
    yt_is_release_slot = None
    yt_issue_release_date = None

try:
    import yaml
except ModuleNotFoundError:  # pragma: no cover - fallback for bare system Python
    yaml = None


SQL_PATH_FIELDS = {
    "sql_query_recreate_init": "sql_query_recreate_init.sql",
    "sql_query_insert_init": "sql_query_insert_init.sql",
    "sql_query_truncate": "sql_query_truncate.sql",
}
DEPENDENCY_IGNORE_SCHEMAS = {"information_schema", "pg_catalog"}
DEPENDENCY_EXTRA_SCHEMAS = {"raw_ext", "dict_raw_ext", "dq"}
REQUIRED_SYSTEM_FIELDS = ("dttm_inserted", "dttm_updated", "deleted_flag")

BLOCKER = "BLOCKER"
WARNING = "WARNING"
INFO = "INFO"


@dataclass
class Finding:
    severity: str
    path: str
    rule: str
    message: str
    task_ids: list[str] = field(default_factory=list)


@dataclass
class ReleaseContext:
    release_name: str
    merge_commit: str
    base_ref: str
    head_ref: str
    diff_mode: str
    resolution: str
    merge_pick: str


@dataclass
class ReleaseSlotMatch:
    issue_id: str
    summary: str
    tasks: list[str]


def run_git(args: list[str], cwd: Path) -> str:
    proc = subprocess.run(
        ["git", *args],
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or f"git {' '.join(args)} failed")
    return proc.stdout


def git_show_text(ref: str, path: str, cwd: Path) -> str:
    return run_git(["show", f"{ref}:{path}"], cwd)


def git_file_exists(ref: str, path: str, cwd: Path) -> bool:
    proc = subprocess.run(
        ["git", "cat-file", "-e", f"{ref}:{path}"],
        cwd=cwd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return proc.returncode == 0


def detect_git_root(start: Path) -> Path | None:
    probe = start if start.is_dir() else start.parent
    proc = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=probe,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0:
        return None
    value = proc.stdout.strip()
    return Path(value).resolve() if value else None


def changed_files(base: str, head: str, diff_mode: str, cwd: Path) -> list[tuple[str, str]]:
    range_expr = f"{base}...{head}" if diff_mode == "three-dot" else f"{base}..{head}"
    raw = run_git(["diff", "--name-status", "--diff-filter=ACMRT", range_expr], cwd)
    out: list[tuple[str, str]] = []
    for line in raw.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        status = parts[0]
        path = parts[-1]
        out.append((status, path))
    return out


def commit_range(base: str, head: str, diff_mode: str) -> str:
    return f"{base}...{head}" if diff_mode == "three-dot" else f"{base}..{head}"


def find_release_merge_context(release_name: str, main_ref: str, merge_pick: str, cwd: Path) -> ReleaseContext:
    target = release_name.strip().lower()
    try:
        raw = run_git(["log", "--merges", "--pretty=%H\t%s", main_ref], cwd)
    except RuntimeError as exc:
        raise RuntimeError(
            f"Не удалось прочитать merge history из `{main_ref}`: {exc}. "
            f"Проверь `git fetch origin` или передай правильный ref через `--main-ref`."
        ) from exc
    release_merges: list[tuple[str, str, str]] = []

    matching_merges: list[tuple[str, str]] = []

    for line in raw.splitlines():
        if "\t" not in line:
            continue
        commit_hash, subject = line.split("\t", 1)
        match = re.search(r"Merge branch '([^']+)' into 'main'", subject, flags=re.IGNORECASE)
        if not match:
            continue
        branch_name = match.group(1).strip()
        release_merges.append((commit_hash, branch_name, subject))
        if branch_name.lower() == target:
            matching_merges.append((commit_hash, branch_name))

    if matching_merges:
        selected_commit, selected_branch = matching_merges[-1] if merge_pick == "first" else matching_merges[0]
        return ReleaseContext(
            release_name=selected_branch,
            merge_commit=selected_commit,
            base_ref=f"{selected_commit}^1",
            head_ref=selected_commit,
            diff_mode="two-dot",
            resolution="merged",
            merge_pick=merge_pick,
        )

    available = sorted({branch for _, branch, _ in release_merges if branch.lower().startswith("release/")}, reverse=True)
    hint = ""
    if available:
        preview = ", ".join(f"`{item}`" for item in available[:10])
        hint = f" Доступные release merge в `{main_ref}`: {preview}."
    raise RuntimeError(f"Не найден merge commit для release-ветки `{release_name}` в `{main_ref}`.{hint}")


def git_ref_exists(ref: str, cwd: Path) -> bool:
    proc = subprocess.run(
        ["git", "rev-parse", "--verify", ref],
        cwd=cwd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return proc.returncode == 0


def find_release_branch_context(release_name: str, main_ref: str, cwd: Path) -> ReleaseContext:
    target = release_name.strip()
    remote_ref = f"origin/{target}"
    if git_ref_exists(remote_ref, cwd):
        return ReleaseContext(
            release_name=target,
            merge_commit="",
            base_ref=main_ref,
            head_ref=remote_ref,
            diff_mode="three-dot",
            resolution="branch",
            merge_pick="",
        )

    raw = run_git(["for-each-ref", "--format=%(refname:short)", "refs/remotes/origin"], cwd)
    matches = [ref.strip() for ref in raw.splitlines() if ref.strip().lower() == remote_ref.lower()]
    if matches:
        return ReleaseContext(
            release_name=matches[0].removeprefix("origin/"),
            merge_commit="",
            base_ref=main_ref,
            head_ref=matches[0],
            diff_mode="three-dot",
            resolution="branch",
            merge_pick="",
        )

    available = sorted(
        {
            ref.removeprefix("origin/")
            for ref in raw.splitlines()
            if ref.strip().lower().startswith("origin/release/")
        },
        reverse=True,
    )
    hint = ""
    if available:
        preview = ", ".join(f"`{item}`" for item in available[:10])
        hint = f" Доступные remote release-ветки: {preview}."
    raise RuntimeError(
        f"Не найдена release-ветка `{release_name}` ни как merge в `{main_ref}`, ни как remote ref `origin/{release_name}`.{hint}"
    )


def resolve_release_context(release_name: str, main_ref: str, merge_pick: str, cwd: Path) -> ReleaseContext:
    try:
        return find_release_merge_context(release_name, main_ref, merge_pick, cwd)
    except RuntimeError as merge_exc:
        try:
            return find_release_branch_context(release_name, main_ref, cwd)
        except RuntimeError:
            raise merge_exc


def merged_branches(base: str, head: str, diff_mode: str, cwd: Path) -> list[str]:
    raw = run_git(["log", "--merges", "--pretty=%s", commit_range(base, head, diff_mode)], cwd)
    branches: list[str] = []
    seen: set[str] = set()

    for subject in raw.splitlines():
        match = re.search(r"Merge branch '([^']+)' into '([^']+)'", subject)
        if not match:
            match = re.search(r"Merge branch '([^']+)'", subject)
        if not match:
            match = re.search(r"Merge remote-tracking branch '([^']+)'", subject)
        if not match:
            continue

        source = match.group(1).strip()
        source_key = source.lower()
        if source_key in {"main", "master"}:
            continue
        if source_key not in seen:
            seen.add(source_key)
            branches.append(source)

    return branches


def merged_branches_for_release(context: ReleaseContext, cwd: Path) -> list[str]:
    if context.resolution != "merged" or not context.merge_commit:
        return merged_branches(context.base_ref, context.head_ref, context.diff_mode, cwd)
    raw = run_git(["log", "--merges", "--pretty=%s", f"{context.merge_commit}^1..{context.merge_commit}^2"], cwd)
    branches: list[str] = []
    seen: set[str] = set()
    release_name = context.release_name.lower()

    for subject in raw.splitlines():
        match = re.search(r"Merge branch '([^']+)' into '([^']+)'", subject, flags=re.IGNORECASE)
        if not match:
            match = re.search(r"Merge branch '([^']+)'", subject, flags=re.IGNORECASE)
            target_branch = ""
        else:
            target_branch = match.group(2).strip().lower()
        if not match:
            match = re.search(r"Merge remote-tracking branch '([^']+)'", subject, flags=re.IGNORECASE)
            target_branch = ""
        if not match:
            continue

        source = match.group(1).strip()
        source_key = source.lower()
        if source_key in {"main", "master", release_name}:
            continue
        if target_branch and target_branch != release_name:
            continue
        if source_key not in seen:
            seen.add(source_key)
            branches.append(source)

    return branches


def normalize_branch_to_task_id(branch: str) -> str | None:
    match = re.search(r"(DWH-\d+)", branch, flags=re.IGNORECASE)
    return match.group(1).upper() if match else None


def merged_task_ids(branches: list[str]) -> list[str]:
    seen: set[str] = set()
    tasks: list[str] = []
    for branch in branches:
        task_id = normalize_branch_to_task_id(branch)
        if task_id and task_id not in seen:
            seen.add(task_id)
            tasks.append(task_id)
    return tasks


def changed_file_task_ids(base: str, head: str, diff_mode: str, cwd: Path, paths: Iterable[str]) -> dict[str, list[str]]:
    range_expr = commit_range(base, head, diff_mode)
    result: dict[str, list[str]] = {}
    for path in sorted(set(paths)):
        try:
            raw = run_git(["log", "--pretty=%s", range_expr, "--", path], cwd)
        except RuntimeError:
            result[path] = []
            continue
        seen: set[str] = set()
        task_ids: list[str] = []
        for line in raw.splitlines():
            for match in re.finditer(r"(DWH-\d+)", line, flags=re.IGNORECASE):
                task_id = match.group(1).upper()
                if task_id not in seen:
                    seen.add(task_id)
                    task_ids.append(task_id)
        result[path] = task_ids
    return result


def enrich_findings_with_task_ids(findings: list[Finding], path_task_map: dict[str, list[str]]) -> None:
    for item in findings:
        item.task_ids = path_task_map.get(item.path, [])


def release_date_from_name(release_name: str) -> str | None:
    match = re.search(r"(\d{4}-\d{2}-\d{2})", release_name)
    return match.group(1) if match else None


def fetch_release_slot_matches(release_name: str) -> tuple[str | None, list[ReleaseSlotMatch]]:
    if not all((yt_fetch_candidate_release_slots, yt_is_release_slot, yt_issue_release_date, yt_extract_linked_issue_ids)):
        return None, []
    release_date = release_date_from_name(release_name)
    if not release_date:
        return None, []

    issues, _used_queries = yt_fetch_candidate_release_slots("", 500)
    matched: list[ReleaseSlotMatch] = []
    for issue in issues:
        if not yt_is_release_slot(issue):
            continue
        if yt_issue_release_date(issue) != release_date:
            continue
        issue_id = str(issue.get("idReadable") or "").strip()
        summary = str(issue.get("summary") or "").strip()
        tasks = sorted(
            {
                task_id.upper()
                for task_id in yt_extract_linked_issue_ids(issue)
                if normalize_branch_to_task_id(task_id)
            }
        )
        matched.append(ReleaseSlotMatch(issue_id=issue_id, summary=summary, tasks=tasks))
    return release_date, matched


def add_release_slot_comparison(findings: list[Finding], release_name: str, merged_tasks: list[str]) -> None:
    release_date, matches = fetch_release_slot_matches(release_name)
    if not release_date or not matches:
        return

    merged_set = set(merged_tasks)
    planned_set = {task for match in matches for task in match.tasks}

    for match in matches:
        missing = [task for task in match.tasks if task not in merged_set]
        if missing:
            findings.append(
                Finding(
                    WARNING,
                    match.issue_id or release_name,
                    "release-slot-missing",
                    f"В Release Slot `{match.issue_id}` ({match.summary}) есть задачи, которых нет в merged tasks: {', '.join(missing)}.",
                )
            )

    extra = sorted(merged_set - planned_set)
    if extra:
        findings.append(
            Finding(
                WARNING,
                release_name,
                "release-slot-extra",
                f"В merged tasks есть задачи, которых нет ни в одном Release Slot за {release_date}: {', '.join(extra)}.",
            )
        )


def is_yaml(path: str) -> bool:
    return path.endswith((".yaml", ".yml"))


def is_sql(path: str) -> bool:
    return path.endswith(".sql")


def is_click_meta_yaml(path: str) -> bool:
    return path.startswith("config_files/meta/") and is_yaml(path)


def is_click_view_sql(path: str) -> bool:
    return path.startswith("config_files/meta/") and is_sql(path)


def is_entity_meta_yaml(path: str) -> bool:
    if not (path.endswith("meta_data_file.yaml") and "etl_loads_entity/" in path):
        return False
    parts = Path(path).parts
    try:
        idx = parts.index("etl_loads_entity")
    except ValueError:
        return False
    return len(parts) - idx >= 5


def normalize_sql(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    sql = re.sub(r"--.*?$", " ", sql, flags=re.MULTILINE)
    return re.sub(r"\s+", " ", sql).strip().lower()


def strip_quotes(value: str) -> str:
    return value.strip().strip('"').strip("'").strip("`")


def extract_created_object(sql: str) -> tuple[str, str] | None:
    normalized = normalize_sql(sql)
    match = re.search(
        r"\bcreate\s+(?:or\s+replace\s+)?(?:materialized\s+)?(view|table)\s+(?:if\s+not\s+exists\s+)?([a-z0-9_\"/.]+)",
        normalized,
    )
    if not match:
        return None
    return match.group(1), strip_quotes(match.group(2))


def expected_object_fqn(meta: dict[str, Any]) -> str | None:
    schema = str(meta.get("table_schema") or "").strip().lower()
    table = str(meta.get("table_name") or "").strip().lower()
    if not schema or not table:
        return None
    return f"{schema}.{table}"


def normalize_object_fqn(value: str) -> str:
    return strip_quotes(value).replace('"."', ".").replace("`", "").replace('"', "").lower()


def extract_sources(sql: str) -> set[str]:
    normalized = normalize_sql(sql)
    sources = set()
    for match in re.finditer(r"\b(?:from|join)\s+([a-z0-9_\"/.]+)", normalized):
        token = strip_quotes(match.group(1))
        if token and not token.startswith("("):
            sources.add(token)
    return sources


def extract_schema_table_refs(sql: str, known_schemas: set[str] | None = None) -> set[tuple[str, str]]:
    refs: set[tuple[str, str]] = set()
    pattern = re.compile(
        r"\b(?:from|join)\s+(\"?[A-Za-z_][\w]*\"?)\s*\.\s*(\"[^\"]+\"|[A-Za-z_][\w]*)",
        re.IGNORECASE,
    )
    for match in pattern.finditer(strip_sql_comments(sql)):
        schema = normalize_object_fqn(match.group(1))
        table = normalize_object_fqn(match.group(2))
        if not schema or not table or schema in DEPENDENCY_IGNORE_SCHEMAS:
            continue
        if known_schemas is not None and schema not in known_schemas:
            continue
        refs.add((schema, table))
    return refs


def strip_sql_comments(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    sql = re.sub(r"(?m)--.*?$", " ", sql)
    return sql


def flatten_depends_on(depends_on: Any) -> set[tuple[str, str]]:
    flat: set[tuple[str, str]] = set()
    if not isinstance(depends_on, dict):
        return flat
    for schema, tables in depends_on.items():
        schema_norm = normalize_object_fqn(str(schema))
        if not schema_norm or not isinstance(tables, list):
            continue
        for table in tables:
            table_norm = normalize_object_fqn(str(table))
            if table_norm:
                flat.add((schema_norm, table_norm))
    return flat


def collect_known_schemas_from_repo(cwd: Path) -> set[str]:
    root = cwd / "meta_info" / "database" / "greenplum" / "schema_name" / "tech_etl" / "etl_loads_entity"
    schemas: set[str] = set(DEPENDENCY_EXTRA_SCHEMAS)
    if not root.exists():
        return schemas
    for meta_path in root.rglob("meta_data_file.yaml"):
        try:
            data = load_yaml(meta_path.read_text(encoding="utf-8", errors="ignore"), str(meta_path), [])
        except Exception:
            continue
        schema = normalize_object_fqn(str(data.get("table_schema") or ""))
        if schema:
            schemas.add(schema)
    return schemas


def iter_sql_repo_candidates(meta_path: str, field_value: str) -> Iterable[str]:
    value = str(field_value or "").strip().replace("\\", "/")
    if not value:
        return

    seen: set[str] = set()

    def push(candidate: str) -> Iterable[str]:
        normalized = candidate.strip().replace("\\", "/")
        if normalized and normalized not in seen:
            seen.add(normalized)
            yield normalized

    yield from push(value)

    meta_parent = str(Path(meta_path).parent).replace("\\", "/")
    if not (value.startswith("meta_info/") or value.startswith("config_files/")):
        yield from push(f"{meta_parent}/{Path(value).name}")

    marker = "etl_loads_entity/"
    if marker in value:
        yield from push(value.split(marker, 1)[1])


def has_select_star(sql: str) -> bool:
    normalized = normalize_sql(sql)
    return bool(re.search(r"\bselect\s+\*", normalized) or re.search(r",\s*\*", normalized))


def has_dm_view_select_star_from_dm_view(sql: str) -> bool:
    normalized = normalize_sql(sql)
    return bool(
        re.search(
            r"\bcreate\s+(?:or\s+replace\s+)?view\b.*?\bas\s+select\s+\*.*?\bfrom\s+(?:\"?dm_view\"?\.)",
            normalized,
        )
    )


def has_dm_view_source_from_dm(sql: str) -> bool:
    normalized = normalize_sql(sql)
    return bool(re.search(r"\b(?:from|join)\s+(?:\"?dm\"?\.)", normalized))


def has_drop_view_cascade(sql: str) -> bool:
    normalized = normalize_sql(sql)
    return bool(re.search(r"\bdrop\s+view\b[^;]*\bcascade\b", normalized))


def has_create_view_if_not_exists(sql: str) -> bool:
    return bool(re.search(r"\bcreate\s+view\s+if\s+not\s+exists\b", normalize_sql(sql)))


def has_drop_view_if_exists(sql: str) -> bool:
    return bool(re.search(r"\bdrop\s+view\s+if\s+exists\b", normalize_sql(sql)))


def find_missing_system_fields_in_sql(sql: str) -> list[str]:
    normalized = normalize_sql(sql)
    missing: list[str] = []
    for field in REQUIRED_SYSTEM_FIELDS:
        if not re.search(rf"\b{re.escape(field)}\b", normalized):
            missing.append(field)
    return missing


def find_missing_system_fields_in_click_attributes(meta: dict[str, Any]) -> list[str]:
    attributes = meta.get("attributes")
    if not isinstance(attributes, list):
        return list(REQUIRED_SYSTEM_FIELDS)

    present: set[str] = set()
    for item in attributes:
        if not isinstance(item, dict):
            continue
        for key in ("column_name_click", "column_name_gp"):
            value = normalize_object_fqn(str(item.get(key) or ""))
            if value:
                present.add(value)

    return [field for field in REQUIRED_SYSTEM_FIELDS if field not in present]


def validate_recreate_sql_matches_yaml(path: str, sql: str, meta: dict[str, Any], findings: list[Finding]) -> None:
    lowered_path = path.lower()
    if any(marker in lowered_path for marker in ("/stg/", "/dict_stg/", "/landing/")):
        return
    expected = expected_object_fqn(meta)
    if not expected:
        return
    created = extract_created_object(sql)
    if not created:
        findings.append(
            Finding(
                WARNING,
                path,
                "ddl-object",
                "В recreate SQL не найден `CREATE TABLE` или `CREATE VIEW`; проверь, что файл действительно создает объект из YAML.",
            )
        )
        return
    actual = normalize_object_fqn(created[1])
    if actual != expected:
        findings.append(
            Finding(
                BLOCKER,
                path,
                "ddl-object",
                f"DDL создает `{actual}`, а YAML описывает `{expected}`. Это часто означает ошибку имени файла, схемы или копипаст.",
            )
        )


def load_yaml(text: str, path: str, findings: list[Finding]) -> dict[str, Any]:
    if yaml is None:
        findings.append(
            Finding(
                WARNING,
                path,
                "yaml-parser",
                "PyYAML не установлен, используется упрощенный парсер top-level полей.",
            )
        )
        return parse_simple_yaml(text)
    try:
        value = yaml.safe_load(text) or {}
        if not isinstance(value, dict):
            findings.append(Finding(BLOCKER, path, "yaml-structure", "YAML должен быть объектом/dict."))
            return {}
        return value
    except Exception as exc:
        findings.append(Finding(BLOCKER, path, "yaml-parse", f"YAML не парсится: {exc}"))
        return {}


def collect_entity_table_ids(ref: str, cwd: Path) -> dict[int, list[str]]:
    raw = run_git(["ls-tree", "-r", "--name-only", ref], cwd)
    result: dict[int, list[str]] = {}
    for path in (line.strip() for line in raw.splitlines() if line.strip()):
        if not is_entity_meta_yaml(path):
            continue
        try:
            text = git_show_text(ref, path, cwd)
        except Exception:
            continue
        meta = load_yaml(text, path, [])
        try:
            table_id = int(meta.get("table_id"))
        except Exception:
            continue
        if table_id <= 0:
            continue
        result.setdefault(table_id, []).append(path)
    return result


def add_duplicate_table_id_findings(
    findings: list[Finding],
    *,
    head: str,
    cwd: Path,
    relevant_paths: Iterable[str],
) -> None:
    relevant_set = {str(path).strip() for path in relevant_paths if str(path).strip()}
    if not relevant_set:
        return
    all_table_ids = collect_entity_table_ids(head, cwd)
    for table_id, paths in sorted(all_table_ids.items()):
        if len(paths) < 2:
            continue
        if not any(path in relevant_set for path in paths):
            continue
        object_parts = [Path(path).parts for path in paths]
        if all(len(parts) >= 4 for parts in object_parts):
            schema_table_pairs = {(parts[1], parts[2]) for parts in object_parts}
            if len(schema_table_pairs) == 1:
                continue
        message = f"`table_id` {table_id} дублируется в ветке: " + ", ".join(f"`{path}`" for path in sorted(paths))
        for path in sorted(paths):
            if path in relevant_set:
                findings.append(Finding(BLOCKER, path, "duplicate-table-id", message))


def parse_simple_yaml(text: str) -> dict[str, Any]:
    result: dict[str, Any] = {}
    current_key: str | None = None
    current_list: list[Any] | None = None
    current_map: dict[str, Any] | None = None
    for raw_line in text.splitlines():
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        indent = len(raw_line) - len(raw_line.lstrip(" "))
        line = raw_line.strip()
        if indent == 0 and ":" in line:
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip()
            current_key = key
            current_list = None
            current_map = None
            if value == "":
                result[key] = {}
                current_map = result[key]
            elif value == "[]":
                result[key] = []
            elif value in {"null", "None", "~"}:
                result[key] = None
            else:
                result[key] = value.strip("'\"")
            continue
        if current_key and indent > 0 and line.startswith("- "):
            if not isinstance(result.get(current_key), list):
                result[current_key] = []
            current_list = result[current_key]
            current_list.append(line[2:].strip().strip("'\""))
            continue
        if current_key and indent > 0 and ":" in line and isinstance(result.get(current_key), dict):
            key, value = line.split(":", 1)
            current_map = result[current_key]
            current_map[key.strip()] = value.strip().strip("'\"") if value.strip() else []
    return result


def expected_entity_sql_path(meta_path: str, meta: dict[str, Any], file_name: str) -> str | None:
    entity = str(meta.get("entity_name") or "").strip()
    schema = str(meta.get("table_schema") or "").strip().lower()
    table = str(meta.get("table_name") or "").strip().lower()
    if not entity or not schema or not table:
        return None
    return f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/{entity}/{schema}/{table}/{file_name}"


def git_find_case_insensitive_path(ref: str, path: str, cwd: Path) -> str | None:
    if git_file_exists(ref, path, cwd):
        return path

    parent = str(Path(path).parent).replace("\\", "/")
    file_name = Path(path).name.lower()
    try:
        raw = run_git(["ls-tree", "-r", "--name-only", ref, "--", parent], cwd)
    except RuntimeError:
        return None

    exact_casefold: list[str] = []
    basename_casefold: list[str] = []
    target_casefold = path.lower()

    for candidate in (line.strip() for line in raw.splitlines() if line.strip()):
        candidate_casefold = candidate.lower()
        if candidate_casefold == target_casefold:
            exact_casefold.append(candidate)
        elif Path(candidate).name.lower() == file_name:
            basename_casefold.append(candidate)

    if exact_casefold:
        return exact_casefold[0]
    if len(basename_casefold) == 1:
        return basename_casefold[0]
    return None


def resolve_repo_sql_path(ref: str, meta_path: str, field_value: str, cwd: Path) -> str | None:
    for candidate in iter_sql_repo_candidates(meta_path, field_value):
        resolved = git_find_case_insensitive_path(ref, candidate, cwd)
        if resolved:
            return resolved
    return None


def validate_entity_meta(
    path: str,
    meta: dict[str, Any],
    head: str,
    cwd: Path,
    findings: list[Finding],
    known_schemas: set[str],
) -> None:
    for key in ("table_name", "table_schema", "entity_name", "object_type", "table_load_mode"):
        if not meta.get(key):
            findings.append(Finding(BLOCKER, path, "required-yaml-field", f"Не заполнено обязательное поле `{key}`."))

    if not isinstance(meta.get("depends_on"), dict) or not meta.get("depends_on"):
        findings.append(Finding(WARNING, path, "depends-on", "`depends_on` пустой или не dict."))

    key_attributes = meta.get("key_attributes")
    if key_attributes is not None and not isinstance(key_attributes, list):
        findings.append(Finding(BLOCKER, path, "key-attributes", "`key_attributes` должен быть списком."))

    object_type = str(meta.get("object_type") or "").strip().lower()
    schema = str(meta.get("table_schema") or "").strip().lower()
    is_view_meta = object_type == "view" or schema.endswith("_view") or "/dm_view/" in path.lower()

    recreate_value = str(meta.get("sql_query_recreate_init") or "").strip()

    for field, file_name in SQL_PATH_FIELDS.items():
        value = str(meta.get(field) or "").strip()
        if not value:
            severity = WARNING if is_view_meta and field in {"sql_query_insert_init", "sql_query_truncate"} else BLOCKER
            findings.append(
                Finding(
                    severity,
                    path,
                    "sql-path",
                    f"Не указан `{field}`. Для view insert/truncate могут отсутствовать, для table обычно обязательны.",
                )
            )
            continue
        expected = expected_entity_sql_path(path, meta, file_name)
        repo_candidates = list(iter_sql_repo_candidates(path, value))
        repo_path = repo_candidates[0] if repo_candidates else None
        resolved_repo_path = resolve_repo_sql_path(head, path, value, cwd) if repo_path else None
        if expected and value != expected:
            if is_view_meta and "/dm_view/" not in path.lower() and field == "sql_query_insert_init" and value == recreate_value:
                findings.append(
                    Finding(
                        INFO,
                        path,
                        "view-insert-reuses-recreate",
                        "`sql_query_insert_init` ссылается на тот же файл, что и `sql_query_recreate_init`. Для view это допустимо, если отдельного insert-файла нет.",
                    )
                )
            else:
                severity = INFO if resolved_repo_path else (WARNING if is_view_meta and field in {"sql_query_insert_init", "sql_query_truncate"} else BLOCKER)
                findings.append(
                    Finding(
                        severity,
                        path,
                        "sql-path",
                        f"`{field}` не соответствует стандартному пути. Ожидалось `{expected}`, указано `{value}`. "
                        "Если файл по указанному пути существует, это допустимо; сообщение нужно только для контроля структуры.",
                    )
                )
        if repo_path and not resolved_repo_path:
            if is_view_meta and field in {"sql_query_insert_init", "sql_query_truncate"}:
                findings.append(
                    Finding(
                        WARNING,
                        path,
                        "sql-path-exists",
                        f"Файл из `{field}` отсутствует. Проверены варианты: {', '.join(f'`{item}`' for item in repo_candidates) or '`<empty>`'}. Для view это может быть допустимо, если отдельного insert/truncate нет; иначе проверь опечатку в имени/пути, регистр букв в каталоге или добавление файла в MR.",
                    )
                )
            else:
                findings.append(
                    Finding(
                        BLOCKER,
                        path,
                        "sql-path-exists",
                        f"Файл из `{field}` отсутствует в ветке. Проверены варианты: {', '.join(f'`{item}`' for item in repo_candidates) or '`<empty>`'}. Скорее всего файл не добавлен в MR, в YAML опечатка в имени/пути или не совпадает регистр каталога/файла.",
                    )
                )
                continue

        if field == "sql_query_recreate_init" and resolved_repo_path:
            try:
                recreate_sql = git_show_text(head, resolved_repo_path, cwd)
            except Exception as exc:
                findings.append(Finding(BLOCKER, path, "sql-read", f"Не удалось прочитать recreate SQL `{resolved_repo_path}`: {exc}"))
                continue
            validate_recreate_sql_matches_yaml(path, recreate_sql, meta, findings)
            if not any(marker in path.lower() for marker in ("/stg/", "/dict_stg/", "/landing/")):
                missing_system_fields = find_missing_system_fields_in_sql(recreate_sql)
                if missing_system_fields:
                    findings.append(
                        Finding(
                            BLOCKER,
                            path,
                            "system-fields",
                            "В recreate SQL отсутствуют обязательные системные поля: "
                            + ", ".join(f"`{field}`" for field in missing_system_fields),
                        )
                    )

        if field == "sql_query_insert_init" and resolved_repo_path:
            try:
                insert_sql = git_show_text(head, resolved_repo_path, cwd)
            except Exception as exc:
                findings.append(Finding(BLOCKER, path, "sql-read", f"Не удалось прочитать insert SQL `{resolved_repo_path}`: {exc}"))
                continue
            target_schema = normalize_object_fqn(str(meta.get("table_schema") or ""))
            target_table = normalize_object_fqn(str(meta.get("table_name") or ""))
            is_stg_path = any(marker in path.lower() for marker in ("/stg/", "/dict_stg/", "/landing/"))
            if is_stg_path:
                continue
            refs = extract_schema_table_refs(insert_sql, known_schemas=known_schemas)
            if target_schema and target_table:
                refs = {
                    (schema_name, table_name)
                    for schema_name, table_name in refs
                    if not (schema_name == target_schema and table_name == target_table)
                }
            depends_on = flatten_depends_on(meta.get("depends_on"))
            refs_with_extra = refs | {
                pair
                for pair in depends_on
                if pair[0] not in known_schemas and pair[0] in DEPENDENCY_EXTRA_SCHEMAS
            }
            missing = sorted(refs_with_extra - depends_on)
            extra = sorted(depends_on - refs_with_extra)
            if missing:
                findings.append(
                    Finding(
                        BLOCKER,
                        path,
                        "depends-on-missing",
                        "В `depends_on` не хватает зависимостей из SQL: " + ", ".join(f"{schema_name}.{table_name}" for schema_name, table_name in missing),
                    )
                )
            if extra:
                findings.append(
                    Finding(
                        INFO,
                        path,
                        "depends-on-extra",
                        "В `depends_on` есть лишние записи, которых нет в SQL: " + ", ".join(f"{schema_name}.{table_name}" for schema_name, table_name in extra),
                    )
                )


def validate_click_meta(path: str, meta: dict[str, Any], findings: list[Finding]) -> None:
    if not meta.get("dag_tags") or not isinstance(meta.get("dag_tags"), list):
        findings.append(Finding(BLOCKER, path, "click-dag-tags", "`dag_tags` должен быть непустым списком."))
    if not meta.get("task_pool"):
        findings.append(Finding(BLOCKER, path, "click-task-pool", "`task_pool` должен быть указан."))
    for key in ("schema_name_gp", "schema_name_click", "object_name", "object_type", "load_type"):
        if not meta.get(key):
            findings.append(Finding(WARNING, path, "click-required-field", f"Не заполнено поле `{key}`."))
    if meta.get("object_type") == "table" and not meta.get("order_by"):
        findings.append(Finding(WARNING, path, "click-order-by", "Для ClickHouse table желательно явно указать `order_by`."))

    schema_name_click = normalize_object_fqn(str(meta.get("schema_name_click") or ""))
    if schema_name_click == "dm":
        missing_system_fields = find_missing_system_fields_in_click_attributes(meta)
        if missing_system_fields:
            findings.append(
                Finding(
                    BLOCKER,
                    path,
                    "system-fields",
                    "В ClickHouse-конфиге отсутствуют обязательные системные поля в `attributes`: "
                    + ", ".join(f"`{field}`" for field in missing_system_fields),
                )
            )


def validate_sql(path: str, sql: str, findings: list[Finding]) -> None:
    normalized = normalize_sql(sql)
    if not normalized:
        findings.append(Finding(BLOCKER, path, "empty-sql", "SQL-файл пустой или содержит только комментарии."))
        return
    if has_drop_view_cascade(sql):
        findings.append(Finding(BLOCKER, path, "drop-view-cascade", "`DROP VIEW ... CASCADE` запрещен: может удалить downstream view."))
    if has_select_star(sql):
        findings.append(Finding(WARNING, path, "select-star", "`SELECT *` нежелателен: downstream может сломаться при изменении колонок."))
    if path.startswith("config_files/meta/dm_view/") and has_dm_view_source_from_dm(sql):
        findings.append(
            Finding(
                BLOCKER,
                path,
                "dm-view-source",
                "В `config_files/meta/dm_view` запрещено использовать источники из `dm.`; здесь должны использоваться только `dm_view.`.",
            )
        )
    if path.startswith("config_files/meta/dm_view/"):
        missing_system_fields = find_missing_system_fields_in_sql(sql)
        if missing_system_fields:
            findings.append(
                Finding(
                    BLOCKER,
                    path,
                    "system-fields",
                    "В SQL для `config_files/meta/dm_view` отсутствуют обязательные системные поля: "
                    + ", ".join(f"`{field}`" for field in missing_system_fields),
                )
            )
    if re.search(r"\bcreate\s+(?:or\s+replace\s+)?view\b", normalized):
        if not re.search(r"\bdrop\s+view\s+if\s+exists\b", normalized):
            findings.append(Finding(WARNING, path, "view-drop", "Для view не найден явный `DROP VIEW IF EXISTS`."))
        if has_drop_view_if_exists(sql) and has_create_view_if_not_exists(sql):
            findings.append(
                Finding(
                    WARNING,
                    path,
                    "view-create-if-not-exists",
                    "`DROP VIEW IF EXISTS` + `CREATE VIEW IF NOT EXISTS` выглядит избыточно: после drop лучше обычный `CREATE VIEW`, чтобы ошибка создания не скрылась.",
                )
            )
        if " on cluster " in normalized and " sync" not in normalized:
            findings.append(Finding(WARNING, path, "click-view-sync", "Для ClickHouse view с `ON CLUSTER` желательно использовать `SYNC` при drop."))
    if re.search(r"\bcreate\s+table\b", normalized):
        if "comment on table" not in normalized:
            findings.append(Finding(WARNING, path, "table-comment", "Не найден `COMMENT ON TABLE`."))
        if "comment on column" not in normalized:
            findings.append(Finding(WARNING, path, "column-comments", "Не найдены `COMMENT ON COLUMN`."))


def build_view_index(paths: list[str], head: str, cwd: Path) -> dict[str, str]:
    index: dict[str, str] = {}
    for path in paths:
        if not is_sql(path):
            continue
        try:
            sql = git_show_text(head, path, cwd)
        except Exception:
            continue
        created = extract_created_object(sql)
        if created and created[0] == "view":
            index[created[1].lower()] = path
    return index


def validate_view_on_view(path: str, sql: str, view_index: dict[str, str], findings: list[Finding]) -> None:
    created = extract_created_object(sql)
    if not created or created[0] != "view":
        return
    for source in sorted(extract_sources(sql)):
        source_key = source.lower()
        if source_key in view_index:
            findings.append(
                Finding(
                    WARNING,
                    path,
                    "view-on-view",
                    f"View читает из другой view `{source}` ({view_index[source_key]}). Проверь порядок пересоздания и отсутствие CASCADE.",
                )
            )


def format_report(
    findings: list[Finding],
    files: list[tuple[str, str]],
    merged_tasks_list: list[str],
    context: ReleaseContext | None,
) -> str:
    lines = [
        "# Release Validation Report",
        "",
    ]
    if context:
        lines.extend(
            [
                f"Release branch: `{context.release_name}`",
                f"Release source: `merge into main`" if context.resolution == "merged" else f"Release source: `remote branch`",
                f"Release merge pick: `{context.merge_pick}`" if context.resolution == "merged" and context.merge_pick else None,
                f"Release merge commit: `{context.merge_commit}`" if context.merge_commit else f"Release head ref: `{context.head_ref}`",
                "",
            ]
        )
        lines = [line for line in lines if line is not None]
    lines.extend(
        [
        f"Changed files checked: {len(files)}",
        f"Findings: {len(findings)}",
        "",
        ]
    )
    if merged_tasks_list:
        lines.append(f"Merged tasks found: {len(merged_tasks_list)}")
        lines.append("")
        lines.append("## Merged Tasks")
        lines.append("")
        for task_id in merged_tasks_list:
            lines.append(f"- `{task_id}`")
        lines.append("")

    if not findings:
        lines.append("No findings.")
        return "\n".join(lines)

    for severity in (BLOCKER, WARNING, INFO):
        group = [item for item in findings if item.severity == severity]
        if not group:
            continue
        lines.append(f"## {severity} ({len(group)})")
        lines.append("")
        for item in group:
            task_suffix = f" [tasks: {', '.join(f'`{task_id}`' for task_id in item.task_ids)}]" if item.task_ids else ""
            lines.append(f"- `{item.path}` [{item.rule}]{task_suffix}: {item.message}")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate release SQL/YAML changes before merge/deploy.")
    parser.add_argument("--release", default="", help="Release branch name, e.g. release/2026-04-15. Case-insensitive; auto-resolves merge into main ref.")
    parser.add_argument("--main-ref", default="origin/main", help="Mainline ref used to search release merge commits, default origin/main.")
    parser.add_argument("--release-merge-pick", choices=["first", "last"], default="last", help="Which merge into main to use if the same release branch was merged multiple times.")
    parser.add_argument("--base", default="origin/main", help="Base ref, e.g. origin/main or previous release tag.")
    parser.add_argument("--head", default="HEAD", help="Head ref, e.g. HEAD or origin/release/2026-04-15.")
    parser.add_argument("--diff-mode", choices=["three-dot", "two-dot"], default="three-dot")
    parser.add_argument("--report", default="", help="Optional path to write markdown report.")
    parser.add_argument("--repo-root", default="", help="Path to the repository being validated. By default tries current git root, then script repo root.")
    args = parser.parse_args()

    script_repo_root = Path(__file__).resolve().parents[1]
    cwd = (
        Path(args.repo_root).resolve()
        if args.repo_root
        else detect_git_root(Path.cwd()) or detect_git_root(script_repo_root) or script_repo_root
    )
    release_context: ReleaseContext | None = None
    if args.release:
        release_context = resolve_release_context(args.release, args.main_ref, args.release_merge_pick, cwd)
        args.base = release_context.base_ref
        args.head = release_context.head_ref
        args.diff_mode = release_context.diff_mode

    files = changed_files(args.base, args.head, args.diff_mode, cwd)
    branches = (
        merged_branches_for_release(release_context, cwd)
        if release_context
        else merged_branches(args.base, args.head, args.diff_mode, cwd)
    )
    merged_tasks_list = merged_task_ids(branches)
    known_schemas = collect_known_schemas_from_repo(cwd)
    relevant = [
        item for item in files
        if is_yaml(item[1]) or is_sql(item[1])
    ]
    all_sql_paths = [path for _, path in relevant if is_sql(path)]
    view_index = build_view_index(all_sql_paths, args.head, cwd)
    findings: list[Finding] = []

    for _, path in relevant:
        try:
            text = git_show_text(args.head, path, cwd)
        except Exception as exc:
            findings.append(Finding(BLOCKER, path, "git-show", f"Не удалось прочитать файл из `{args.head}`: {exc}"))
            continue

        if is_yaml(path):
            meta = load_yaml(text, path, findings)
            if is_entity_meta_yaml(path):
                validate_entity_meta(path, meta, args.head, cwd, findings, known_schemas)
            if is_click_meta_yaml(path):
                validate_click_meta(path, meta, findings)
        elif is_sql(path):
            validate_sql(path, text, findings)
            if (is_click_view_sql(path) and not path.startswith("config_files/meta/dm_view/")) or "etl_loads_entity/" in path.lower() and "/dm_view/" in path.lower():
                validate_view_on_view(path, text, view_index, findings)

    add_duplicate_table_id_findings(
        findings,
        head=args.head,
        cwd=cwd,
        relevant_paths=[path for _, path in relevant if is_entity_meta_yaml(path)],
    )

    if release_context:
        add_release_slot_comparison(findings, release_context.release_name, merged_tasks_list)

    path_task_map = changed_file_task_ids(args.base, args.head, args.diff_mode, cwd, [path for _, path in relevant])
    enrich_findings_with_task_ids(findings, path_task_map)
    report = format_report(findings, relevant, merged_tasks_list, release_context)
    print(report)
    if args.report:
        Path(args.report).write_text(report, encoding="utf-8")

    return 1 if any(item.severity == BLOCKER for item in findings) else 0


if __name__ == "__main__":
    sys.exit(main())
