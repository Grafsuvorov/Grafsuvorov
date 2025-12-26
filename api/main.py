@app.get("/api/incidents/history")
def get_incident_history():
    query = f"""
        SELECT
            t.table_schema || '.' || l.object_name AS table_fqn,
            COUNT(*) AS incidents_count,
            MAX(l.loading_finish_dttm) AS last_incident
     FROM public.log_objects_loading_history l
      left join tables_meta t on t.table_id=l.object_id
        WHERE l.loading_state = 'FAILED'
          AND l.object_type = 'table'
          AND l.loading_finish_dttm >= now() - interval '300 days'
        GROUP BY t.table_schema, l.object_name
        ORDER BY incidents_count DESC
        LIMIT 10
    """
    with engine.connect() as conn:
        rows = conn.execute(text(query)).mappings().all()

    return [
        {
            "table": r["table_fqn"],
            "count": r["incidents_count"],
            "last_incident": r["last_incident"].strftime("%Y-%m-%d %H:%M:%S")
            if r["last_incident"] else None
        }
        for r in rows
    ]
