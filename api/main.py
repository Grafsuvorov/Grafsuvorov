@app.get("/api/incident")
def get_incident(table_fqn: str = Query(..., description="Format: schema.table")):
    """
    Агрегатор инцидента:
    - summary
    - timeline
    - dependencies (downstream)
    - impact
    """

    try:
        # normalize_fqn ВОЗВРАЩАЕТ (schema, table)
        schema, table = normalize_fqn(table_fqn)
    except Exception:
        return JSONResponse(
            status_code=400,
            content={"error": "table_fqn must be schema.table"},
        )

    with engine.connect() as conn:
        table_id = get_table_id_by_fqn(conn, schema, table)

        if not table_id:
            return JSONResponse(
                status_code=404,
                content={
                    "error": "table not found in tables_meta",
                    "table_fqn": f"{schema}.{table}",
                },
            )

        # ---------- TIMELINE ----------
        tl_q = text(f"""
            SELECT
                loading_start_dttm,
                loading_finish_dttm,
                loading_state,
                message,
                EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) AS duration_seconds
            FROM {TABLE_LOADING_HISTORY}
            WHERE object_id = :object_id
            ORDER BY loading_finish_dttm DESC
            LIMIT 15
        """)
        rows = conn.execute(tl_q, {"object_id": table_id}).mappings().all()

        timeline = []
        for r in rows:
            msg = (r.get("message") or "").strip()
            msg = re.sub(r"\s+", " ", msg)
            timeline.append({
                "start": r["loading_start_dttm"].strftime("%Y-%m-%d %H:%M:%S") if r["loading_start_dttm"] else None,
                "finish": r["loading_finish_dttm"].strftime("%Y-%m-%d %H:%M:%S") if r["loading_finish_dttm"] else None,
                "state": r["loading_state"],
                "duration_sec": float(r["duration_seconds"]) if r["duration_seconds"] is not None else None,
                "message": msg[:180] if msg else None,
            })

        # ---------- COUNTS ----------
        failures_24h = conn.execute(text(f"""
            SELECT COUNT(*) FROM {TABLE_LOADING_HISTORY}
            WHERE object_id = :id
              AND loading_state = 'FAILED'
              AND loading_finish_dttm >= NOW() - INTERVAL '24 hours'
        """), {"id": table_id}).scalar() or 0

        failures_7d = conn.execute(text(f"""
            SELECT COUNT(*) FROM {TABLE_LOADING_HISTORY}
            WHERE object_id = :id
              AND loading_state = 'FAILED'
              AND loading_finish_dttm >= NOW() - INTERVAL '7 days'
        """), {"id": table_id}).scalar() or 0

        last_failure = conn.execute(text(f"""
            SELECT MAX(loading_finish_dttm)
            FROM {TABLE_LOADING_HISTORY}
            WHERE object_id = :id AND loading_state = 'FAILED'
        """), {"id": table_id}).scalar()

        last_success = conn.execute(text(f"""
            SELECT MAX(loading_finish_dttm)
            FROM {TABLE_LOADING_HISTORY}
            WHERE object_id = :id AND loading_state = 'SUCCESS'
        """), {"id": table_id}).scalar()

        consecutive_failures = 0
        for ev in timeline:
            if ev["state"] == "FAILED":
                consecutive_failures += 1
            else:
                break

        state = "FAILING" if timeline and timeline[0]["state"] == "FAILED" else "RECOVERED"

        # ---------- DEPENDENCIES ----------
        deps = []
        try:
            deps_items = get_dependencies(table=f"{schema}.{table}")
            deps = [d.dict() for d in deps_items]
        except Exception:
            deps = []

        # ---------- IMPACT ----------
        sla_rows = get_sla_monitoring()
        impact = build_impact(f"{schema}.{table}", deps, sla_rows)

        severity = (
            "CRITICAL"
            if state == "FAILING" or impact.get("sla_violations", 0) > 0
            else "HIGH" if failures_24h >= 2
            else "MEDIUM"
        )

        summary = {
            "table_fqn": f"{schema}.{table}",
            "table_id": table_id,
            "severity": severity,
            "state": state,
            "failures_24h": int(failures_24h),
            "failures_7d": int(failures_7d),
            "consecutive_failures": consecutive_failures,
            "last_failure_time": last_failure.strftime("%Y-%m-%d %H:%M:%S") if last_failure else None,
            "last_success_time": last_success.strftime("%Y-%m-%d %H:%M:%S") if last_success else None,
        }

        return JSONResponse(
            content={
                "summary": summary,
                "timeline": timeline,
                "dependencies": deps,
                "impact": impact,
            },
            media_type="application/json; charset=utf-8",
        )
