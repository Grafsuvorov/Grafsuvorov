@app.on_event("startup")
def warm_up_cache():
    try:
        get_cached_meta_and_index()
    except Exception as e:
        print("Ошибка при старте приложения:", e)


@router.get("/api/orderbreaches")
def get_order_breaches():
    return {"ok": True}
