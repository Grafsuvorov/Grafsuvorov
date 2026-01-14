INSERT INTO dm_calc.expected_downtime_365
(
    dt,
    entity_code,
    expected_day,
    expected_ytd,
    calc_dttm
)
WITH
/* ============================================================
   1. ПАРАМЕТРЫ РАСЧЁТА
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
   3. ИСТОЧНИК ПРОГНОЗНЫХ ДАННЫХ
   (ВАЖНО: не факт, а прогнозная серия)
   ============================================================ */
base_forecast AS (
    SELECT
        dt_report::date AS dt,
        entity_code,
        downtime_duration_in_minutes_forecast_quantity AS forecast_value
    FROM ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
    WHERE account_code = 'KPI_ALUM_TEC_08a'
),

/* ============================================================
   4. EXPECTED_DAY = среднее от даты
   ============================================================ */
expected_day AS (
    SELECT
        c.dt,
        f.entity_code,
        AVG(b.forecast_value) AS expected_day
    FROM calendar c
    JOIN base_forecast f
        ON f.dt = c.dt
    JOIN base_forecast b
        ON b.entity_code = f.entity_code
       AND b.dt <  c.dt
       AND b.dt >= c.dt - INTERVAL '365 days'
    GROUP BY
        c.dt,
        f.entity_code
),

/* ============================================================
   5. EXPECTED_YTD
   ============================================================ */
expected_ytd AS (
    SELECT
        dt,
        entity_code,
        expected_day,
        SUM(expected_day) OVER (
            PARTITION BY entity_code,
                         date_trunc('year', dt)
            ORDER BY dt
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS expected_ytd
    FROM expected_day
)

SELECT
    dt,
    entity_code,
    expected_day,
    expected_ytd,
    now() AS calc_dttm
FROM expected_ytd;
