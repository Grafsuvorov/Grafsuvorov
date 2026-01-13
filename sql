WITH RECURSIVE
params AS (
    SELECT
        DATE '2024-01-01'        AS start_date,
        current_date             AS calc_date,
        current_date + 365       AS end_date
),

calendar AS (
    SELECT
        generate_series(
            (SELECT start_date FROM params),
            (SELECT end_date   FROM params),
            interval '1 day'
        )::date AS dt
),

base_actual AS (
    SELECT
        dt_report::date AS dt,
        entity_code,
        actual
    FROM ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
    WHERE account_code = 'KPI_ALUM_TEC_08a'
),

-- база до текущей даты
seed AS (
    SELECT
        c.dt,
        a.entity_code,
        a.actual,
        a.actual AS plan_day
    FROM calendar c
    JOIN base_actual a
      ON a.dt = c.dt
    WHERE c.dt <= (SELECT calc_date FROM params)
),

-- рекурсивное продолжение
plan_recursive AS (
    -- якорь
    SELECT
        dt,
        entity_code,
        actual,
        plan_day
    FROM seed

    UNION ALL

    -- шаг +1 день
    SELECT
        c.dt,
        pr.entity_code,
        NULL::numeric AS actual,
        avg_window.avg_val AS plan_day
    FROM plan_recursive pr
    JOIN calendar c
      ON c.dt = pr.dt + 1
    JOIN LATERAL (
        SELECT AVG(val) AS avg_val
        FROM (
            -- факт
            SELECT b.actual AS val
            FROM base_actual b
            WHERE b.entity_code = pr.entity_code
              AND b.dt < c.dt
              AND b.dt >= c.dt - 365

            UNION ALL

            -- ранее рассчитанный план
            SELECT p.plan_day AS val
            FROM plan_recursive p
            WHERE p.entity_code = pr.entity_code
              AND p.dt < c.dt
              AND p.dt >= c.dt - 365
        ) x
    ) avg_window ON TRUE
    WHERE c.dt <= (SELECT end_date FROM params)
)

SELECT
    dt,
    entity_code,
    actual,
    plan_day
FROM plan_recursive;
