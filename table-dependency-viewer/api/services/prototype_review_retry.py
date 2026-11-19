"""Source snapshots for selective Prototype Review reruns."""
import hashlib
import json


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
