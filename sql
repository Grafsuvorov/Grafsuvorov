WITH
/* ============================================================
   1. ПАРАМЕТРЫ
   ============================================================ */
params AS (
    SELECT
        DATE '2024-01-01'  AS start_date,
        current_date + 365 AS end_date
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
   4. PLAN_DAY = скользящее среднее от ДАТЫ
   ============================================================ */
plan_day AS (
    SELECT
        c.dt,
        a.entity_code,
        AVG(b.actual) AS plan_day
    FROM calendar c
    JOIN base_actual a
        ON a.dt = c.dt
    JOIN base_actual b
        ON b.entity_code = a.entity_code
       AND b.dt <  c.dt
       AND b.dt >= c.dt - INTERVAL '365 days'
    GROUP BY
        c.dt,
        a.entity_code
)

/* ============================================================
   5. PLAN_YTD
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
