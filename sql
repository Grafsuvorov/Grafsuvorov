WITH params AS (
    SELECT
        DATE '2024-01-01' AS start_date,
        current_date     AS calc_date,
        current_date + 365 AS end_date
),

calendar AS (
    SELECT generate_series(
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

seed AS (
    -- база: все даты до calc_date
    SELECT
        c.dt,
        a.entity_code,
        a.actual,
        a.actual AS plan_value
    FROM calendar c
    JOIN base_actual a ON a.dt = c.dt
    WHERE c.dt <= (SELECT calc_date FROM params)
),

recursive_plan AS (
    -- первая будущая дата
    SELECT
        s.dt,
        s.entity_code,
        s.actual,
        s.plan_value
    FROM seed s

    UNION ALL

    SELECT
        c.dt,
        rp.entity_code,
        NULL::numeric AS actual,
        (
            SELECT avg(val)
            FROM (
                SELECT actual AS val
                FROM base_actual b
                WHERE b.entity_code = rp.entity_code
                  AND b.dt < c.dt
                  AND b.dt >= c.dt - 365
                UNION ALL
                SELECT plan_value
                FROM recursive_plan p
                WHERE p.entity_code = rp.entity_code
                  AND p.dt < c.dt
                  AND p.dt >= c.dt - 365
            ) x
        ) AS plan_value
    FROM recursive_plan rp
    JOIN calendar c
      ON c.dt = rp.dt + 1
    WHERE c.dt <= (SELECT end_date FROM params)
)

SELECT *
FROM recursive_plan;
