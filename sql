WITH base AS (
    SELECT
        date_trunc('day', dl.dttm_inserted) AS report_date,
        tm.entity_name,
        tm.table_schema,
        dl.object_id,
        dl.log_message,
        dl.dttm_inserted
    FROM tech_etl.detailed_log dl
    JOIN tech_etl.tables_meta tm
      ON tm.table_id = dl.object_id
    WHERE dl.log_status = 'ok'
      AND dl.dttm_inserted IS NOT NULL
      AND tm.table_schema <> 'dm_view'
      AND tm.entity_id = 42
      AND dl.dttm_inserted::date BETWEEN DATE '2026-01-01' AND DATE '2026-01-31'
),
per_table AS (
    SELECT
        report_date,
        entity_name,
        table_schema,
        object_id,
        MIN(CASE WHEN log_message = 'Loading process started'
                 THEN dttm_inserted END) AS started_at,
        MAX(CASE WHEN log_message = 'Loading process finished'
                 THEN dttm_inserted END) AS finished_at
    FROM base
    GROUP BY report_date, entity_name, table_schema, object_id
),
valid AS (
    SELECT *
    FROM per_table
    WHERE started_at IS NOT NULL
      AND finished_at IS NOT NULL
      AND finished_at >= started_at
)
SELECT
    report_date,
    entity_name,
    EXTRACT(EPOCH FROM (MAX(finished_at) - MIN(started_at))) AS duration_seconds
FROM valid
GROUP BY report_date, entity_name
ORDER BY report_date;
