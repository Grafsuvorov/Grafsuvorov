WITH
/* ============================================================
   1. ПАРАМЕТРЫ РАСЧЁТА
   ============================================================ */
params AS (
    SELECT
        DATE '2024-01-01'        AS start_date,
        current_date             AS calc_date,
        current_date + 365       AS end_date
),

/* ============================================================
   2. КАЛЕНДАРЬ
   ============================================================ */
calendar AS (
    SELECT
        generate_series(
            (SELECT start_date FROM params),
            (SELECT end_date   FROM params),
            interval '1 day'
        )::date AS dt
),

/* ============================================================
   3. ФАКТ
   ============================================================ */
base_actual AS (
    SELECT
        dt_report::date AS dt,
        entity_code,
        actual
    FROM ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
    WHERE account_code = 'KPI_ALUM_TEC_08a'
),

/* ============================================================
   4. СРЕДНЕЕ ЗА 365 ДНЕЙ (ОДИН РАЗ)
   ============================================================ */
avg_365 AS (
    SELECT
        entity_code,
        AVG(actual) AS avg_365_val
    FROM base_actual
    WHERE dt < (SELECT calc_date FROM params)
      AND dt >= (SELECT calc_date FROM params) - INTERVAL '365 days'
    GROUP BY entity_code
),

/* ============================================================
   5. PLAN_DAY
   ============================================================ */
plan_day AS (
    SELECT
        c.dt,
        a.entity_code,
        a.actual,
        CASE
            WHEN c.dt < (SELECT calc_date FROM params)
                THEN a.actual
            ELSE avg.avg_365_val
        END AS plan_day
    FROM calendar c
    LEFT JOIN base_actual a
        ON a.dt = c.dt
    JOIN avg_365 avg
        ON avg.entity_code = a.entity_code
)

/* ============================================================
   6. PLAN_YTD
   ============================================================ */
SELECT
    dt,
    entity_code,
    plan_day,
    SUM(plan_day) OVER (
        PARTITION BY entity_code,
                     date_trunc('year', dt)
        ORDER BY dt
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS plan_ytd
FROM plan_day
ORDER BY entity_code, dt;
