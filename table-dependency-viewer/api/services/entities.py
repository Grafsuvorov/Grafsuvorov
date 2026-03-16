from __future__ import annotations

from sqlalchemy import text


def build_entities_query(table_loading_history: str, table_tables_meta: str, table_entities_meta: str) -> str:
    return f"""
        WITH latest_table_runs AS (
            SELECT
                l.object_id,
                l.loading_start_dttm,
                l.loading_finish_dttm,
                COALESCE(l.loading_finish_dttm, l.loading_start_dttm) AS run_dttm,
                ROW_NUMBER() OVER (
                    PARTITION BY l.object_id
                    ORDER BY COALESCE(l.loading_finish_dttm, l.loading_start_dttm) DESC NULLS LAST
                ) AS rn
            FROM {table_loading_history} l
        ),
        entity_latest_day AS (
            SELECT
                t.entity_id,
                MAX(DATE(r.run_dttm)) AS latest_run_day
            FROM {table_tables_meta} t
            JOIN latest_table_runs r
              ON r.object_id = t.table_id
             AND r.rn = 1
            WHERE t.entity_id IS NOT NULL
            GROUP BY t.entity_id
        )
        SELECT
            e.entity_id,
            e.entity_name,
            e.entity_last_load AS entity_last_load,
            e.entity_load_interval::varchar AS entity_load_interval,
            e.entity_load_status,
            MIN(r.loading_start_dttm) AS entity_schedule_start,
            MAX(COALESCE(r.loading_finish_dttm, r.loading_start_dttm)) AS entity_schedule_end
        FROM {table_entities_meta} e
        LEFT JOIN entity_latest_day d
          ON d.entity_id = e.entity_id
        LEFT JOIN {table_tables_meta} t
          ON t.entity_id = e.entity_id
        LEFT JOIN latest_table_runs r
          ON r.object_id = t.table_id
         AND r.rn = 1
         AND DATE(r.run_dttm) = d.latest_run_day
        WHERE e.flag_active
        GROUP BY
            e.entity_id,
            e.entity_name,
            e.entity_last_load,
            e.entity_load_interval,
            e.entity_load_status
        ORDER BY entity_schedule_start NULLS LAST, e.entity_name
    """


def fetch_entities(engine, *, table_loading_history: str, table_tables_meta: str, table_entities_meta: str):
    query = build_entities_query(table_loading_history, table_tables_meta, table_entities_meta)
    with engine.connect() as conn:
        rows = conn.execute(text(query)).mappings().all()

    cleaned = []
    for row in rows:
        payload = dict(row)
        payload["entity_schedule_start"] = (
            payload["entity_schedule_start"].strftime("%Y-%m-%d %H:%M:%S")
            if payload.get("entity_schedule_start")
            else None
        )
        payload["entity_last_load"] = (
            payload["entity_last_load"].strftime("%Y-%m-%d %H:%M:%S")
            if payload.get("entity_last_load")
            else None
        )
        payload["entity_schedule_end"] = (
            payload["entity_schedule_end"].strftime("%Y-%m-%d %H:%M:%S")
            if payload.get("entity_schedule_end")
            else None
        )
        cleaned.append(payload)

    return cleaned

