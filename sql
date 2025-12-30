Кеш-переменные
# ============================
# ORDER BREACHES CACHE
# ============================

_order_breaches_cache = None
_order_breaches_ts = 0
_ORDER_BREACHES_TTL = 300  # 5 минут

🔹 2. ЧИСТАЯ функция с ТВОЕЙ логикой (почти 1 в 1)
def compute_order_breaches():
    """
    ТЯЖЁЛАЯ логика расчёта order breaches.
    НИЧЕГО НЕ ЗНАЕТ ПРО HTTP.
    """
    resp = get_dependency_violations()
    rows = json.loads(resp.body)

    grouped = {}

    for r in rows:
        target = f"{r['dependent_schema']}.{r['dependent_table']}"
        source = f"{r['source_schema']}.{r['source_table']}"

        src_time = datetime.fromisoformat(r["source_last_load"])
        tgt_time = datetime.fromisoformat(r["dependent_last_load"])
        gap_sec = (src_time - tgt_time).total_seconds()

        g = grouped.setdefault(target, {
            "target_fqn": target,
            "target_last_load": r["dependent_last_load"],
            "worst_upstream": None,
            "worst_upstream_time": None,
            "worst_gap_sec": 0,
            "violations": []
        })

        g["violations"].append({
            "source_fqn": source,
            "gap_sec": gap_sec,
            "source_last_load": r["source_last_load"],
            "dependent_last_load": r["dependent_last_load"],
        })

        if gap_sec > g["worst_gap_sec"]:
            g["worst_gap_sec"] = gap_sec
            g["worst_upstream"] = source
            g["worst_upstream_time"] = r["source_last_load"]

    result = []
    for g in grouped.values():
        gap_min = g["worst_gap_sec"] / 60
        if gap_min > 30:
            sev = "CRITICAL"
        elif gap_min > 5:
            sev = "MAJOR"
        else:
            sev = "WARNING"

        g["severity"] = sev
        g["gap_minutes"] = round(gap_min, 1)
        g["violations_count"] = len(g["violations"])
        result.append(g)

    result.sort(key=lambda x: x["worst_gap_sec"], reverse=True)
    return result

🔹 3. Функция получения из кеша
def get_cached_order_breaches():
    global _order_breaches_cache, _order_breaches_ts

    now = time.time()
    if _order_breaches_cache and now - _order_breaches_ts < _ORDER_BREACHES_TTL:
        return _order_breaches_cache

    print("⚠️ rebuilding orderbreaches cache")
    result = compute_order_breaches()

    _order_breaches_cache = result
    _order_breaches_ts = now
    return result


@router.get("/api/orderbreaches")
def get_order_breaches():
    return get_cached_order_breaches()


@app.on_event("startup")
def warm_up_cache():
    try:
        get_cached_meta_and_index()
        get_cached_order_breaches()  # 🔥 прогрев orderbreaches
    except Exception as e:
        print("Ошибка при старте приложения:", e)
