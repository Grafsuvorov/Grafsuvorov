WITH base AS (
    SELECT
        date_trunc('day', dl.dttm_inserted) AS report_date,
        tm.entity_name,
        tm.table_schema,
        lm.layer_weight,
        dl.object_id,
        dl.log_message,
        dl.dttm_inserted
    FROM tech_etl.detailed_log dl
    JOIN tech_etl.tables_meta tm
      ON tm.table_id = dl.object_id
    JOIN tech_etl.layers_meta lm
      ON lm.layer_name = tm.table_schema
    WHERE dl.log_status = 'ok'
      AND dl.dttm_inserted IS NOT NULL
      AND tm.table_schema <> 'dm_view'
      AND tm.entity_id = 42
      AND dl.dttm_inserted::date BETWEEN DATE '2026-01-01' AND DATE '2026-01-31'
),

-- старт/финиш по каждой таблице
per_table AS (
    SELECT
        report_date,
        entity_name,
        table_schema,
        layer_weight,
        object_id,
        MIN(CASE WHEN log_message = 'Loading process started'
                 THEN dttm_inserted END) AS started_at,
        MAX(CASE WHEN log_message = 'Loading process finished'
                 THEN dttm_inserted END) AS finished_at
    FROM base
    GROUP BY report_date, entity_name, table_schema, layer_weight, object_id
),

-- валидные интервалы
valid AS (
    SELECT *
    FROM per_table
    WHERE started_at IS NOT NULL
      AND finished_at IS NOT NULL
      AND finished_at >= started_at
),

-- окно по слоям
per_layer AS (
    SELECT
        report_date,
        entity_name,
        table_schema,
        layer_weight,
        MIN(started_at)  AS layer_started,
        MAX(finished_at) AS layer_finished
    FROM valid
    GROUP BY report_date, entity_name, table_schema, layer_weight

    UNION ALL

    -- общий слой "all"
    SELECT
        report_date,
        entity_name,
        'all'::text AS table_schema,
        1000 AS layer_weight,
        MIN(started_at)  AS layer_started,
        MAX(finished_at) AS layer_finished
    FROM valid
    GROUP BY report_date, entity_name
)

SELECT
    report_date,
    entity_name,
    table_schema,
    layer_weight,
    EXTRACT(EPOCH FROM (layer_finished - layer_started)) AS duration_seconds
FROM per_layer
ORDER BY report_date, layer_weight;
