"""Explicit SQL-to-entity mapping for multiple algorithms of one relation."""
from __future__ import annotations

from collections import defaultdict
from hashlib import sha256
import re

from .prototype_review import _normalize_fqn, _strip_sql_comments, infer_review_targets

WRITE = re.compile(r"\b(?:insert\s+into|insert\s+overwrite(?:\s+table)?|update|merge\s+into|create\s+(?:or\s+replace\s+)?(?:materialized\s+)?view)\s+([^\s;(]+)", re.I)


def entity_names(value):
    result = []
    seen = set()
    for name in str(value or "").split(","):
        name = name.strip()
        if name and name.lower() not in seen:
            seen.add(name.lower())
            result.append(name)
    return result


def validate_common_variant_settings(review_items):
    """One physical relation has one dbt DQ registry across all algorithms."""
    settings_by_target = {}
    for item in review_items:
        if item.get("sql_variant_mode") != "separate":
            continue
        fqn = str(item.get("target_fqn") or "").lower()
        settings = {key: item.get(key) or [] for key in ("key_attributes", "version_key", "null_conditions")}
        settings.update({key: item.get(key) or "" for key in ("scd_type", "filter")})
        if fqn in settings_by_target and settings_by_target[fqn] != settings:
            raise ValueError(f"Разные DQ/SCD-настройки алгоритмов {fqn}; согласуйте настройки общей таблицы")
        settings_by_target[fqn] = settings


def variant_groups(files, targets, metadata=()):
    groups = []
    by_path = {f["path"]: f for f in files}
    for target in targets:
        if target.get("is_clickhouse_view"):
            continue
        fqn = str(target.get("target_fqn") or "").lower()
        writers = []
        for path in target.get("execution_paths") or []:
            file = by_path.get(path) or {}
            sql = file.get("sql") or "\n".join(file.get("statements") or [])
            if any(_normalize_fqn(m.group(1)) == fqn for m in WRITE.finditer(_strip_sql_comments(sql))):
                writers.append(path)
        if len(writers) < 2:
            continue
        options = list(dict.fromkeys(str(m.get("entity_name") or "").strip() for m in metadata
            if f'{m.get("table_schema", "")}.{m.get("table_name", "")}'.lower() == fqn and m.get("entity_name")))
        groups.append({"target_fqn": target["target_fqn"], "writer_paths": writers,
                       "common_paths": [p for p in target.get("paths") or [] if p not in writers],
                       "entity_options": options})
    return groups


def apply_variant_mappings(files, targets, groups, mappings):
    choices = {}
    for choice in mappings or []:
        fqn = str(choice.get("target_fqn") or "").strip().lower()
        if fqn in choices:
            raise ValueError(f"Повторное сопоставление алгоритмов для {fqn}")
        choices[fqn] = choice
    unknown = set(choices) - {g["target_fqn"].lower() for g in groups}
    if unknown:
        raise ValueError("Сопоставление не относится к текущему diff: " + ", ".join(sorted(unknown)))
    result = []
    for target in targets:
        fqn = str(target.get("target_fqn") or "").lower()
        group = next((g for g in groups if g["target_fqn"].lower() == fqn), None)
        if group is None:
            result.append(target)
            continue
        choice = choices.get(fqn)
        if not choice or choice.get("mode") not in {"shared", "separate"}:
            raise ValueError(f"Выберите общий SQL или отдельные алгоритмы для {fqn}")
        if choice["mode"] == "shared":
            names = entity_names(choice.get("entity_name"))
            if not names:
                raise ValueError(f"Укажите сущности общего SQL для {fqn}")
            result.append({**target, "mapped_entity_name": ", ".join(names), "sql_variant_mode": "shared"})
            continue
        variants = choice.get("variants") or []
        if len(variants) < 2:
            raise ValueError(f"Для {fqn} нужны минимум два отдельных алгоритма")
        used_writers, used_entities = set(), set()
        for variant in variants:
            names = entity_names(variant.get("entity_name"))
            if not names:
                raise ValueError(f"Укажите сущность каждого алгоритма {fqn}")
            overlapping = used_entities & {n.lower() for n in names}
            if overlapping:
                raise ValueError("Одна сущность назначена разным алгоритмам: " + ", ".join(sorted(overlapping)))
            used_entities.update(n.lower() for n in names)
            writers = set(variant.get("paths") or [])
            if not writers or not writers <= set(group["writer_paths"]) or writers & used_writers:
                raise ValueError(f"Некорректное или повторное сопоставление SQL-файлов для {fqn}")
            used_writers.update(writers)
            paths = [p for p in target["paths"] if p in writers or p in group["common_paths"]]
            scoped = [f for f in files if f.get("path") in paths]
            scoped_target = next((t for t in infer_review_targets(scoped)
                if str(t.get("target_fqn") or "").lower() == fqn and t.get("object_type") == target.get("object_type")), None)
            if scoped_target is None:
                raise ValueError(f"В выбранном SQL не найден объект {fqn}")
            key = sha256((fqn + "|" + ",".join(names) + "|" + "|".join(sorted(writers))).encode()).hexdigest()[:12]
            result.append({**scoped_target, "item_id": f"{fqn}::{target['object_type']}::{key}",
                           "variant_key": key, "sql_variant_mode": "separate", "mapped_entity_name": ", ".join(names), "mapped_key_attributes": variant.get("key_attributes")})
        if used_writers != set(group["writer_paths"]):
            raise ValueError(f"Не все SQL-файлы {fqn} сопоставлены сущностям")
    return result


def validate_issue_variants(review_items, files):
    """Reject stale/tampered mappings before creating any external issue."""
    validate_common_variant_settings(review_items)
    by_target = defaultdict(list)
    paths = {f["path"] for f in files}
    for item in review_items:
        by_target[str(item.get("target_fqn") or "").lower()].append(item)
        if not set(item.get("paths") or []) <= paths:
            raise ValueError("SQL-файлы изменились после review; повторите проверку")
    groups = variant_groups(files, infer_review_targets(files))
    for group in groups:
        fqn = group["target_fqn"].lower()
        items = by_target.get(fqn) or []
        if len(items) == 1 and items[0].get("sql_variant_mode") == "shared":
            if not set(group["writer_paths"]) <= set(items[0].get("paths") or []):
                raise ValueError(f"Не все SQL-файлы общего алгоритма {fqn} включены")
            continue
        seen = set()
        for item in items:
            if item.get("sql_variant_mode") != "separate":
                raise ValueError(f"Сопоставьте SQL-алгоритмы {fqn} перед созданием задачи")
            writers = set(item.get("paths") or []) & set(group["writer_paths"])
            if not writers or seen & writers:
                raise ValueError(f"SQL-файлы алгоритмов {fqn} пересекаются")
            seen.update(writers)
        if seen != set(group["writer_paths"]):
            raise ValueError(f"Не все алгоритмы {fqn} прошли review")
    for fqn, items in by_target.items():
        if len(items) < 2:
            continue
        names, variants = set(), set()
        for item in items:
            if item.get("sql_variant_mode") != "separate" or not item.get("variant_key"):
                raise ValueError(f"Для {fqn} необходимо явно сопоставить отдельные алгоритмы")
            if item["variant_key"] in variants:
                raise ValueError(f"Повторный вариант SQL для {fqn}")
            variants.add(item["variant_key"])
            own = {n.lower() for n in entity_names(item.get("entity_name"))}
            if not own or names & own:
                raise ValueError(f"Сущности разных алгоритмов {fqn} пересекаются")
            names.update(own)
