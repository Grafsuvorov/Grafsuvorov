"""Source snapshots for selective Prototype Review reruns."""
import hashlib
import json


def resolve_retry_item_ids(selected, targets, previous_items):
    """Rebind a corrected SQL object's old ID without guessing between variants."""
    known = {t["item_id"] for t in targets}
    previous = {item.get("item_id"): item for item in previous_items or []}
    aliases = {}
    if not selected:
        raise ValueError("Состав объектов MR изменился: не выбраны объекты для повторной проверки")
    for item_id in selected:
        if item_id in known:
            continue
        old = previous.get(item_id) or {}
        def names(value):
            return {n.strip().lower() for n in str(value or "").split(",") if n.strip()}
        candidates = [t for t in targets
            if str(t.get("object_type") or "TABLE").upper() == str(old.get("object_type") or "TABLE").upper()
            and (t.get("sql_variant_mode") or "") == (old.get("sql_variant_mode") or "")
            and (t.get("sql_variant_mode") != "separate"
                 or names(t.get("mapped_entity_name")) == names(old.get("entity_name")))]
        same_target = [t for t in candidates if str(t.get("target_fqn") or "").lower() == str(old.get("target_fqn") or "").lower()]
        old_paths = set(old.get("paths") or [])
        same_files = [t for t in candidates if old_paths and set(t.get("paths") or []) == old_paths]
        matches = same_target or same_files
        if len(matches) != 1:
            label = old.get("target_fqn") or item_id
            raise ValueError(f"Состав объектов MR изменился: не удалось однозначно сопоставить `{label}` "
                             "с исправленным SQL. Проверьте имена объектов и сопоставление файлов.")
        aliases[item_id] = matches[0]["item_id"]
    resolved = [aliases.get(item_id, item_id) for item_id in selected]
    if len(resolved) != len(set(resolved)):
        raise ValueError("Состав объектов MR изменился: несколько старых объектов соответствуют одному новому")
    return set(resolved), aliases


def sql_fingerprint(item, files):
    paths = set(item.get("paths") or [item.get("path")])
    source = sorted((f["path"], f.get("sql") or "\n".join(f.get("statements") or []))
                    for f in files if f.get("path") in paths)
    return hashlib.sha256(json.dumps(source, ensure_ascii=False).encode()).hexdigest()


def validate_review_sources(items, files):
    for item in items:
        expected = item.get("sql_fingerprint")
        if expected and expected != sql_fingerprint(item, files):
            raise ValueError(f"SQL объекта {item.get('target_fqn')} изменился после проверки. Перезапустите этот объект.")
