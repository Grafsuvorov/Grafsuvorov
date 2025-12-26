def norm(s: str | None) -> str | None:
    return s.lower() if isinstance(s, str) else s


def normalize_fqn(table_fqn: str) -> tuple[str, str]:
    """
    Всегда возвращает (schema, table) в lowercase
    """
    s = table_fqn.strip().lower()

    if "/" in s and "." in s:
        schema, rest = s.split(".", 1)
        rest = rest.replace("/", "").replace("-", "").replace(" ", "")
        s = f"{schema}.{rest}"

    if "." not in s:
        raise ValueError("Expected schema.table")

    return tuple(s.split(".", 1))
🔹 Чтение YAML (КРИТИЧНО)
python
Копировать код
def find_all_meta_files(top_dirs: list[str]) -> list[dict]:
    all_meta = []

    for top_dir in top_dirs:
        for root, _, files in os.walk(BASE_DIR / top_dir):
            if "meta_data_file.yaml" not in files:
                continue

            path = Path(root) / "meta_data_file.yaml"
            try:
                meta = yaml.safe_load(path.read_text(encoding="utf-8")) or {}

                all_meta.append({
                    "table_schema": norm(meta.get("table_schema")),
                    "table_name": norm(meta.get("table_name")),
                    "entity_id": meta.get("entity_id"),
                    "entity_name": meta.get("entity_name"),
                    "table_id": meta.get("table_id"),
                    "depends_on": {
                        norm(k): [norm(t) for t in v]
                        for k, v in (meta.get("depends_on") or {}).items()
                    },
                })
            except Exception as e:
                print(f"[META ERROR] {path}: {e}")

    return all_meta
🔹 Построение reverse index (downstream)
python
Копировать код
def build_reverse_index(all_meta: list[dict]) -> dict[tuple[str, str], list[dict]]:
    reverse = {}

    for m in all_meta:
        consumer = (m["table_schema"], m["table_name"])

        for src_schema, tables in (m.get("depends_on") or {}).items():
            for src_table in tables:
                key = (src_schema, src_table)

                reverse.setdefault(key, []).append({
                    "schema": consumer[0],
                    "table_name": consumer[1],
                    "entity_id": m.get("entity_id"),
                    "entity_name": m.get("entity_name"),
                    "table_id": m.get("table_id"),
                })

    return reverse
🔹 Рекурсивный downstream (рабочий)
python
Копировать код
def recursive_reverse_search(
    schema: str,
    table: str,
    reverse_index: dict,
    visited: set | None = None
):
    if visited is None:
        visited = set()

    key = (schema, table)
    if key in visited:
        return []

    visited.add(key)

    result = []
    for dep in reverse_index.get(key, []):
        result.append(dep)
        result.extend(
            recursive_reverse_search(
                dep["schema"],
                dep["table_name"],
                reverse_index,
                visited
            )
        )

    return result
🔹 Финальный API /api/dependencies (СТАБИЛЬНЫЙ)
python
Копировать код
@app.get("/api/dependencies", response_model=list[DependencyItem])
def get_dependencies(table: str = Query(...)):
    try:
        schema, table = normalize_fqn(table)
    except ValueError:
        return []

    all_meta, reverse_index = get_cached_meta_and_index()
    raw = recursive_reverse_search(schema, table, reverse_index)

    seen = set()
    uniq = []
    for r in raw:
        k = (r["schema"], r["table_name"])
        if k not in seen:
            seen.add(k)
            uniq.append(r)

    with engine.connect() as conn:
        out = []
        for i, r in enumerate(uniq, 1):
            avg = None
            if r.get("table_id"):
                avg = conn.execute(
                    text(f"""
                        SELECT round(avg(extract(epoch from (loading_finish_dttm-loading_start_dttm))/60),2)
                        FROM {TABLE_LOADING_HISTORY}
                        WHERE object_id=:id AND loading_state='SUCCESS'
                    """),
                    {"id": r["table_id"]}
                ).scalar()

            out.append(DependencyItem(
                step=i,
                schema=r["schema"],
                table_name=r["table_name"],
                entity_id=r["entity_id"],
                entity_name=r.get("entity_name"),
                avg_duration_minutes=avg,
            ))

    return out
